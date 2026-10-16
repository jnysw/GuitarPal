import 'package:uuid/uuid.dart';

import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_session/practice_session.dart';
import '../../../domain/practice_session/practice_session_repository.dart';

/// Accumulates real active playback time and completed A-B loops.
///
/// The recorder deliberately uses wall-clock time while playback is active,
/// rather than changes in video position. Seeking, changing speed, and looping
/// therefore do not inflate or reduce the amount of time the user practiced.
class PracticePlaybackSessionRecorder {
  PracticePlaybackSessionRecorder(
    this._repository, {
    required this.sourceId,
    this.planId,
    this.segmentId,
    this._uuid = const Uuid(),
    DateTime Function()? clock,
    this.minimumActiveDuration = const Duration(seconds: 1),
  }) : _clock = clock ?? DateTime.now;

  final PracticeSessionRepository _repository;
  final String? planId;
  final String sourceId;
  final String? segmentId;
  final Duration minimumActiveDuration;
  final Uuid _uuid;
  final DateTime Function() _clock;

  DateTime? _startedAt;
  DateTime? _lastObservation;
  Duration _activeDuration = Duration.zero;
  int _completedLoops = 0;
  int _lastControllerLoops = 0;
  bool _wasPlaying = false;
  bool _suspended = false;
  late final String _sessionId = _uuid.v4();
  Future<void> _writeTail = Future<void>.value();
  Future<PracticeSession?>? _finishFuture;

  Duration get activeDuration => _activeDuration;
  int get completedLoops => _completedLoops;
  bool get hasStarted => _startedAt != null;

  void observe({required bool isPlaying, required int completedLoops}) {
    if (_finishFuture != null) return;
    final now = _clock();
    _accrueUntil(now);
    _captureLoops(completedLoops, now);
    final effectivePlaying = isPlaying && !_suspended;
    if (effectivePlaying) _startedAt ??= now;
    _wasPlaying = effectivePlaying;
    _lastObservation = now;
  }

  /// Stops counting immediately when the app is backgrounded.
  void suspend() {
    if (_finishFuture != null || _suspended) return;
    final now = _clock();
    _accrueUntil(now);
    _suspended = true;
    _wasPlaying = false;
    _lastObservation = now;
  }

  void resume() {
    if (_finishFuture != null || !_suspended) return;
    _suspended = false;
    _wasPlaying = false;
    _lastObservation = _clock();
  }

  /// Persists a recoverable snapshot of the current practice session.
  ///
  /// Checkpoints use one stable session ID and are upserted through the
  /// repository. They are marked `completed: false` because the player did
  /// not finish normally, but their accumulated activity is still valid for
  /// practice progress if the process is later reclaimed. Call [suspend]
  /// before this method when handling an app-background lifecycle event so
  /// background wall-clock time cannot be accrued.
  ///
  /// Saves are serialized with other checkpoints and [finish]. If [finish]
  /// has already been requested, this returns its finalized session instead
  /// of writing an older incomplete snapshot over it.
  Future<PracticeSession?> checkpoint() {
    final finishFuture = _finishFuture;
    if (finishFuture != null) return finishFuture;

    final checkpointedAt = _clock();
    _accrueUntil(checkpointedAt);
    _lastObservation = checkpointedAt;
    final session = _snapshot(endedAt: null, completed: false);
    if (session == null) return Future<PracticeSession?>.value();
    return _enqueueSave(session);
  }

  Future<PracticeSession?> finish() {
    return _finishFuture ??= _finish();
  }

  Future<PracticeSession?> _finish() async {
    final endedAt = _clock();
    _accrueUntil(endedAt);
    _wasPlaying = false;
    _lastObservation = endedAt;
    final session = _snapshot(endedAt: endedAt, completed: true);
    if (session == null) return null;
    return _enqueueSave(session);
  }

  PracticeSession? _snapshot({
    required DateTime? endedAt,
    required bool completed,
  }) {
    final startedAt = _startedAt;
    if (startedAt == null ||
        (_activeDuration < minimumActiveDuration && _completedLoops == 0)) {
      return null;
    }

    return PracticeSession(
      id: _sessionId,
      planId: planId,
      sourceId: sourceId,
      segmentId: segmentId,
      practiceDate: CalendarDate.fromDateTime(startedAt),
      startedAt: startedAt.toUtc(),
      endedAt: endedAt?.toUtc(),
      activeDuration: _activeDuration,
      loopCount: _completedLoops,
      completed: completed,
    );
  }

  Future<PracticeSession> _enqueueSave(PracticeSession session) {
    final operation = _writeTail.then((_) => _repository.save(session));
    _writeTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation.then((_) => session);
  }

  void _accrueUntil(DateTime now) {
    final previous = _lastObservation;
    if (!_wasPlaying || previous == null) return;
    final elapsed = now.difference(previous);
    if (!elapsed.isNegative) _activeDuration += elapsed;
  }

  void _captureLoops(int value, DateTime now) {
    final normalized = value < 0 ? 0 : value;
    if (normalized < _lastControllerLoops) {
      // The loop counter resets when a new range is selected.
      _lastControllerLoops = normalized;
      return;
    }
    final delta = normalized - _lastControllerLoops;
    if (delta > 0) {
      _startedAt ??= now;
      _completedLoops += delta;
    }
    _lastControllerLoops = normalized;
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../audio_tools/data/algorithm_mix_platform.dart';
import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../plans/application/practice_playback_session_recorder.dart';
import '../domain/backing_preset.dart';
import 'performance_preview.dart';

enum PerformanceStagePhase {
  preparing,
  ready,
  playing,
  paused,
  finished,
  error,
}

/// One stage, one recorder and the same native mix used for meters and transport.
class PerformanceStageController extends ChangeNotifier {
  PerformanceStageController({
    required this.platform,
    required AlgorithmStemStore store,
    required this.candidate,
    required this.preset,
    required this.recorder,
    required Future<void> Function(PerformanceCandidate) verify,
  }) {
    _settings = preset;
    _preview = PerformancePreview(platform, store, verify: verify)
      ..addListener(_sync);
    _meters = platform.levels.listen(
      _level,
      onError: (Object _) {
        if (!_closed) {
          meterUnavailable = true;
          _quiet();
          notifyListeners();
        }
      },
    );
    _checkpoint = Timer.periodic(const Duration(seconds: 5), (_) {
      if (playing) unawaited(_saveCheckpoint());
    });
  }
  final AlgorithmMixPlatform platform;
  final PerformanceCandidate candidate;
  final BackingPreset preset;
  late BackingPreset _settings;
  final PracticePlaybackSessionRecorder recorder;
  late final PerformancePreview _preview;
  late final StreamSubscription<Map<String, Object?>> _meters;
  late final Timer _checkpoint;
  PerformanceStagePhase phase = PerformanceStagePhase.preparing;
  int positionMs = 0;
  int get durationMs => candidate.binding.durationMs;
  bool get playing => phase == PerformanceStagePhase.playing;
  bool busy = false, meterUnavailable = false;
  String? error, statisticsError;
  double left = 0, right = 0, leftPeak = 0, rightPeak = 0;
  bool _closed = false,
      _foreground = true,
      _transition = false,
      _acceptLevels = false;
  int? _generation;
  int _epoch = 0;
  Future<void>? _leaving;
  void _quiet() {
    left = right = leftPeak = rightPeak = 0;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_closed || busy) return;
    await _loadAt(0);
  }

  Future<void> _identity() async {
    final s = await platform.snapshot();
    if (_closed || !_foreground) return;
    final generation = s['generation'], epoch = s['epoch'];
    if (generation is! num || epoch is! num) {
      meterUnavailable = true;
      _acceptLevels = false;
      return;
    }
    _generation = generation.toInt();
    _epoch = epoch.toInt();
    _acceptLevels = true;
    meterUnavailable = false;
  }

  Future<void> _loadAt(int position) async {
    busy = true;
    _transition = true;
    phase = PerformanceStagePhase.preparing;
    error = null;
    _acceptLevels = false;
    _quiet();
    _notify();
    try {
      await _preview.prepare(candidate, _settings, allowDownload: false);
      if (_closed || !_foreground) return;
      if (!_preview.ready) {
        throw FormatException(_preview.error ?? '伴奏未准备好，请返回准备页');
      }
      await _preview.seek(position.clamp(0, durationMs));
      await _identity();
      if (_closed || !_foreground) return;
      positionMs = position.clamp(0, durationMs);
      phase = positionMs == 0
          ? PerformanceStagePhase.ready
          : PerformanceStagePhase.paused;
    } on Object catch (e) {
      if (!_closed && _foreground) {
        error = e is FormatException ? e.message : '舞台伴奏载入失败，请返回准备页重试';
        phase = PerformanceStagePhase.error;
      }
    } finally {
      _transition = false;
      busy = false;
      _notify();
    }
  }

  void _sync() {
    if (_closed || _transition || !_foreground) return;
    if (_preview.error != null) {
      error = _preview.error;
      phase = PerformanceStagePhase.error;
      _quiet();
    } else if (_preview.ready) {
      final wasPlaying = playing;
      positionMs = _preview.positionMs;
      if (_preview.playing) {
        phase = PerformanceStagePhase.playing;
      } else if (wasPlaying && positionMs >= durationMs - 100) {
        phase = PerformanceStagePhase.finished;
        _quiet();
        unawaited(_saveCheckpoint());
      } else if (phase != PerformanceStagePhase.finished) {
        phase = positionMs == 0
            ? PerformanceStagePhase.ready
            : PerformanceStagePhase.paused;
        _quiet();
      }
    }
    recorder.observe(isPlaying: playing, completedLoops: 0);
    _notify();
  }

  void _level(Map<String, Object?> data) {
    if (_closed ||
        !_foreground ||
        !_acceptLevels ||
        !playing ||
        data['generation'] != _generation) {
      return;
    }
    final epoch = data['epoch'];
    if (epoch is! num || epoch.toInt() != _epoch) return;
    double value(String key) {
      final v = data[key];
      return v is num && v.isFinite ? v.toDouble().clamp(0, 1) : 0;
    }

    final volume = value('systemVolume');
    if (data['isPlaying'] != true || volume == 0 || master == 0) {
      _quiet();
      _notify();
      return;
    }
    double smooth(double current, double next) =>
        current + (next - current) * (next > current ? .7 : .3);
    left = smooth(left, value('leftRms') * volume);
    right = smooth(right, value('rightRms') * volume);
    leftPeak = value('leftPeak') * volume;
    rightPeak = value('rightPeak') * volume;
    _notify();
  }

  Future<void> toggle() async {
    if (_closed || busy || !_foreground || _leaving != null) return;
    if (playing) {
      await _preview.toggle();
      return;
    }
    if (!_preview.ready) {
      await _loadAt(positionMs);
      if (_closed || !_foreground || !_preview.ready) return;
    }
    if (phase == PerformanceStagePhase.finished ||
        positionMs >= durationMs - 20) {
      await seek(0);
    }
    await _preview.toggle();
  }

  Future<void> seek(int position) async {
    if (_closed || busy || !_preview.ready || !_foreground) return;
    _transition = true;
    _acceptLevels = false;
    _quiet();
    try {
      await _preview.seek(position.clamp(0, durationMs));
      await _identity();
      positionMs = position.clamp(0, durationMs);
    } finally {
      _transition = false;
      _sync();
    }
  }

  Future<void> setMaster(double value) async {
    if (_closed || busy || !_preview.ready) return;
    final current = _preview.applied;
    if (current == null) return;
    if (value == 0) {
      _quiet();
      _notify();
    }
    await _preview.configure(current.copyWith(master: value.clamp(0, 1)));
    _settings = _preview.applied ?? _settings;
  }

  double get master => _preview.applied?.master ?? _settings.master;
  Future<void> suspend() async {
    if (_closed) return;
    _foreground = false;
    _acceptLevels = false;
    _quiet();
    recorder.suspend();
    phase = PerformanceStagePhase.paused;
    _notify();
    await _preview.suspend();
    await _saveCheckpoint();
  }

  void resume() {
    if (_closed) return;
    _foreground = true;
    recorder.resume();
    _preview.resume();
    _notify();
  }

  Future<void> _saveCheckpoint() async {
    try {
      await recorder.checkpoint();
      if (!_closed && statisticsError != null) {
        statisticsError = null;
        _notify();
      }
    } on Object {
      if (!_closed) {
        statisticsError = '本次演奏记录暂未保存，请重试';
        _notify();
      }
    }
  }

  Future<void> retryStatistics() => _saveCheckpoint();
  Future<void> leave() {
    final pending = _leaving;
    if (pending != null) return pending;
    final work = _finish();
    _leaving = work;
    return work.catchError((Object e, StackTrace st) {
      _leaving = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  Future<void> _finish() async {
    _acceptLevels = false;
    _quiet();
    recorder.observe(isPlaying: false, completedLoops: 0);
    phase = PerformanceStagePhase.paused;
    _notify();
    await _preview.invalidate();
    await recorder.finish();
  }

  @override
  void dispose() {
    _closed = true;
    _acceptLevels = false;
    recorder.suspend();
    _checkpoint.cancel();
    unawaited(_meters.cancel());
    _preview.removeListener(_sync);
    _preview.dispose();
    unawaited(recorder.finish().catchError((Object _) => null));
    super.dispose();
  }

  double get leftMotion => math.sqrt(left.clamp(0, 1)).clamp(0, 1);
  double get rightMotion => math.sqrt(right.clamp(0, 1)).clamp(0, 1);
}

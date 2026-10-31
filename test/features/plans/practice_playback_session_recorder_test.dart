import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_session/practice_session_repository.dart';
import 'package:guitar_pal/features/plans/application/practice_playback_session_recorder.dart';

void main() {
  late _MemorySessionRepository repository;
  late _MutableClock clock;
  late PracticePlaybackSessionRecorder recorder;

  setUp(() {
    repository = _MemorySessionRepository();
    clock = _MutableClock(DateTime(2026, 10, 14, 10));
    recorder = PracticePlaybackSessionRecorder(
      repository,
      sourceId: 'source-1',
      planId: 'plan-1',
      segmentId: 'segment-1',
      clock: clock.call,
    );
  });

  test('accumulates only real time spent playing across pauses', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 3));
    recorder.observe(isPlaying: false, completedLoops: 0);

    clock.advance(const Duration(seconds: 10));
    recorder.observe(isPlaying: false, completedLoops: 0);
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));

    final session = await recorder.finish();

    expect(recorder.activeDuration, const Duration(seconds: 5));
    expect(session, isNotNull);
    expect(session!.activeDuration, const Duration(seconds: 5));
    expect(session.startedAt, DateTime(2026, 10, 14, 10).toUtc());
    expect(session.endedAt, DateTime(2026, 10, 14, 10, 0, 15).toUtc());
    expect(repository.sessions, [session]);
  });

  test(
    'a failed final save can be retried without creating a second session',
    () async {
      repository.failNext = true;
      recorder.observe(isPlaying: true, completedLoops: 0);
      clock.advance(const Duration(seconds: 3));
      await expectLater(recorder.finish(), throwsStateError);
      clock.advance(const Duration(seconds: 10));
      final saved = await recorder.finish();
      expect(saved!.activeDuration, const Duration(seconds: 3));
      expect(repository.sessions, hasLength(1));
      expect(repository.sessions.single.id, saved.id);
      expect(saved.completed, isTrue);
    expect(repository.attemptedIds, hasLength(2));
    expect(repository.attemptedIds.toSet(), hasLength(1));
    },
  );

  test(
    'continues accumulating loops after the controller counter resets',
    () async {
      recorder.observe(isPlaying: false, completedLoops: 0);
      clock.advance(const Duration(seconds: 1));
      recorder.observe(isPlaying: false, completedLoops: 2);

      recorder.observe(isPlaying: false, completedLoops: 0);
      recorder.observe(isPlaying: false, completedLoops: 3);

      final session = await recorder.finish();

      expect(recorder.completedLoops, 5);
      expect(session, isNotNull);
      expect(session!.loopCount, 5);
      expect(session.activeDuration, Duration.zero);
      expect(session.startedAt, DateTime(2026, 10, 14, 10, 0, 1).toUtc());
      expect(repository.sessions, [session]);
    },
  );

  test('does not count time while suspended in the background', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 4));
    recorder.suspend();

    clock.advance(const Duration(minutes: 2));
    recorder.observe(isPlaying: true, completedLoops: 0);
    recorder.resume();
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));

    final session = await recorder.finish();

    expect(session, isNotNull);
    expect(session!.activeDuration, const Duration(seconds: 6));
    expect(recorder.activeDuration, const Duration(seconds: 6));
    expect(
      session.endedAt!.difference(session.startedAt),
      const Duration(minutes: 2, seconds: 6),
    );
  });

  test(
    'does not persist a sub-second session without completed loops',
    () async {
      recorder.observe(isPlaying: true, completedLoops: 0);
      clock.advance(const Duration(milliseconds: 999));

      final session = await recorder.finish();

      expect(session, isNull);
      expect(recorder.activeDuration, const Duration(milliseconds: 999));
      expect(repository.sessions, isEmpty);
      expect(repository.saveCallCount, 0);
    },
  );

  test('checkpoint ignores activity below the persistence threshold', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(milliseconds: 999));

    final session = await recorder.checkpoint();

    expect(session, isNull);
    expect(repository.saveCallCount, 0);
    expect(repository.sessions, isEmpty);
  });

  test('checkpoints upsert one stable incomplete session', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));

    final first = await recorder.checkpoint();
    clock.advance(const Duration(seconds: 3));
    final second = await recorder.checkpoint();

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.id, first!.id);
    expect(first.completed, isFalse);
    expect(first.endedAt, isNull);
    expect(first.activeDuration, const Duration(seconds: 2));
    expect(second.completed, isFalse);
    expect(second.endedAt, isNull);
    expect(second.activeDuration, const Duration(seconds: 5));
    expect(repository.saveCallCount, 2);
    expect(repository.sessions, [second]);
  });

  test('a completed loop makes a zero-duration checkpoint valid', () async {
    recorder.observe(isPlaying: false, completedLoops: 1);

    final session = await recorder.checkpoint();

    expect(session, isNotNull);
    expect(session!.activeDuration, Duration.zero);
    expect(session.loopCount, 1);
    expect(session.completed, isFalse);
    expect(repository.sessions, [session]);
  });

  test('finish replaces its checkpoint using the same session ID', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));
    final checkpoint = await recorder.checkpoint();

    clock.advance(const Duration(seconds: 3));
    final finished = await recorder.finish();

    expect(finished, isNotNull);
    expect(finished!.id, checkpoint!.id);
    expect(finished.completed, isTrue);
    expect(finished.endedAt, DateTime(2026, 10, 14, 10, 0, 5).toUtc());
    expect(finished.activeDuration, const Duration(seconds: 5));
    expect(repository.saveCallCount, 2);
    expect(repository.sessions, [finished]);
  });

  test('serializes an in-flight checkpoint before the final save', () async {
    final blockingRepository = _BlockingSessionRepository();
    final concurrentRecorder = PracticePlaybackSessionRecorder(
      blockingRepository,
      sourceId: 'source-1',
      clock: clock.call,
    );
    concurrentRecorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));

    final checkpointFuture = concurrentRecorder.checkpoint();
    await Future<void>.delayed(Duration.zero);
    expect(blockingRepository.requests, hasLength(1));
    expect(blockingRepository.requests.single.completed, isFalse);

    clock.advance(const Duration(seconds: 3));
    final finishFuture = concurrentRecorder.finish();
    await Future<void>.delayed(Duration.zero);

    // The final upsert must wait, otherwise a slow checkpoint could overwrite
    // the completed session after the player has already shut down.
    expect(blockingRepository.requests, hasLength(1));
    blockingRepository.completeNext();
    final checkpoint = await checkpointFuture;
    await Future<void>.delayed(Duration.zero);

    expect(blockingRepository.requests, hasLength(2));
    final finalRequest = blockingRepository.requests.last;
    expect(finalRequest.id, checkpoint!.id);
    expect(finalRequest.completed, isTrue);
    expect(finalRequest.activeDuration, const Duration(seconds: 5));

    blockingRepository.completeNext();
    final finished = await finishFuture;
    expect(finished, same(finalRequest));
  });

  test(
    'checkpoint requested after finish never writes an incomplete snapshot',
    () async {
      recorder.observe(isPlaying: true, completedLoops: 0);
      clock.advance(const Duration(seconds: 2));

      final finishFuture = recorder.finish();
      final checkpointFuture = recorder.checkpoint();
      final results = await Future.wait([finishFuture, checkpointFuture]);

      expect(identical(finishFuture, checkpointFuture), isTrue);
      expect(results[0], same(results[1]));
      expect(repository.saveCallCount, 1);
      expect(repository.sessions.single.completed, isTrue);
    },
  );

  test('finish is idempotent and writes the session only once', () async {
    recorder.observe(isPlaying: true, completedLoops: 0);
    clock.advance(const Duration(seconds: 2));

    final firstFinish = recorder.finish();
    final secondFinish = recorder.finish();
    final results = await Future.wait([firstFinish, secondFinish]);

    expect(identical(firstFinish, secondFinish), isTrue);
    expect(results[0], same(results[1]));
    expect(repository.saveCallCount, 1);
    expect(repository.sessions, hasLength(1));

    clock.advance(const Duration(minutes: 1));
    recorder.observe(isPlaying: true, completedLoops: 4);
    expect(await recorder.finish(), same(results[0]));
    expect(repository.saveCallCount, 1);
    expect(
      repository.sessions.single.activeDuration,
      const Duration(seconds: 2),
    );
    expect(repository.sessions.single.loopCount, 0);
  });
}

final class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

final class _MemorySessionRepository implements PracticeSessionRepository {
  bool failNext = false;
  final List<String> attemptedIds = [];
  final List<PracticeSession> sessions = [];
  int saveCallCount = 0;

  @override
  Stream<List<PracticeSession>> watchAll() => Stream.value(List.of(sessions));

  @override
  Future<void> save(PracticeSession session) async {
    attemptedIds.add(session.id);
    if (failNext) {
      failNext = false;
      throw StateError('disk unavailable');
    }
    saveCallCount += 1;
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
  }

  @override
  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    return Stream.value(
      sessions
          .where(
            (session) =>
                session.practiceDate >= start && session.practiceDate <= end,
          )
          .toList(),
    );
  }

  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate date) {
    return Stream.value(
      sessions.where((session) => session.practiceDate == date).toList(),
    );
  }
}

final class _BlockingSessionRepository implements PracticeSessionRepository {
  final List<PracticeSession> requests = [];
  final List<Completer<void>> _pending = [];

  @override
  Stream<List<PracticeSession>> watchAll() => const Stream.empty();

  @override
  Future<void> save(PracticeSession session) {
    requests.add(session);
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext() {
    _pending.removeAt(0).complete();
  }

  @override
  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    return const Stream.empty();
  }

  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate date) {
    return const Stream.empty();
  }
}

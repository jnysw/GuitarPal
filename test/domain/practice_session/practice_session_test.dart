import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';

void main() {
  test('stores an in-progress session without an end time', () {
    final session = PracticeSession(
      id: 'session-1',
      planId: 'plan-1',
      sourceId: 'source-1',
      segmentId: 'segment-1',
      practiceDate: CalendarDate(2026, 10, 13),
      startedAt: DateTime.utc(2026, 10, 13, 8),
      activeDuration: const Duration(minutes: 2),
      loopCount: 3,
      completed: false,
    );

    expect(session.endedAt, isNull);
    expect(session.completed, isFalse);
    expect(session.hasPracticeActivity, isTrue);
    expect(session.practiceDate.dayKey, 20261013);
  });

  test('an empty recovery checkpoint is not valid practice activity', () {
    final session = _session(completed: false);

    expect(session.completed, isFalse);
    expect(session.hasPracticeActivity, isFalse);
  });

  test('rejects negative progress and an end before the start', () {
    final startedAt = DateTime.utc(2026, 10, 13, 8);

    expect(
      () => _session(activeDuration: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    expect(() => _session(loopCount: -1), throwsArgumentError);
    expect(
      () => _session(
        startedAt: startedAt,
        endedAt: startedAt.subtract(const Duration(seconds: 1)),
      ),
      throwsArgumentError,
    );
  });
}

PracticeSession _session({
  DateTime? startedAt,
  DateTime? endedAt,
  Duration activeDuration = Duration.zero,
  int loopCount = 0,
  bool completed = true,
}) {
  return PracticeSession(
    id: 'session-1',
    sourceId: 'source-1',
    practiceDate: CalendarDate(2026, 10, 13),
    startedAt: startedAt ?? DateTime.utc(2026, 10, 13, 8),
    endedAt: endedAt,
    activeDuration: activeDuration,
    loopCount: loopCount,
    completed: completed,
  );
}

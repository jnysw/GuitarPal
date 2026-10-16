import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_progress.dart';
import 'package:guitar_pal/domain/practice_plan/reminder_time.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';

void main() {
  group('CalendarDate', () {
    test('round-trips a timezone-free day key', () {
      final date = CalendarDate(2026, 10, 13);

      expect(date.dayKey, 20261013);
      expect(CalendarDate.fromDayKey(date.dayKey), date);
      expect(date.toString(), '2026-10-13');
      expect(date.toLocalDateTime(), DateTime(2026, 10, 13));
    });

    test('adds days across month and leap-year boundaries', () {
      expect(CalendarDate(2026, 1, 31).addDays(1), CalendarDate(2026, 2, 1));
      expect(CalendarDate(2028, 2, 28).addDays(1), CalendarDate(2028, 2, 29));
      expect(CalendarDate(2026, 1, 1).addDays(-1), CalendarDate(2025, 12, 31));
    });

    test('rejects invalid calendar values and day keys', () {
      expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
      expect(() => CalendarDate.fromDayKey(20261301), throwsArgumentError);
    });
  });

  group('PracticePlan', () {
    test(
      'schedules only selected weekdays inside the inclusive date range',
      () {
        final plan = _plan(
          startDate: CalendarDate(2026, 10, 12),
          endDate: CalendarDate(2026, 10, 18),
          repeatWeekdays: {
            DateTime.monday,
            DateTime.wednesday,
            DateTime.sunday,
          },
        );

        expect(plan.isScheduledOn(CalendarDate(2026, 10, 11)), isFalse);
        expect(plan.isScheduledOn(CalendarDate(2026, 10, 12)), isTrue);
        expect(plan.isScheduledOn(CalendarDate(2026, 10, 13)), isFalse);
        expect(plan.isScheduledOn(CalendarDate(2026, 10, 14)), isTrue);
        expect(plan.isScheduledOn(CalendarDate(2026, 10, 18)), isTrue);
        expect(plan.isScheduledOn(CalendarDate(2026, 10, 19)), isFalse);
      },
    );

    test('defensively copies repeat weekdays', () {
      final weekdays = <int>{DateTime.monday};
      final plan = _plan(repeatWeekdays: weekdays);

      weekdays.add(DateTime.tuesday);

      expect(plan.repeatWeekdays, {DateTime.monday});
      expect(
        () => plan.repeatWeekdays.add(DateTime.wednesday),
        throwsUnsupportedError,
      );
    });

    test('copyWith can explicitly clear an optional segment', () {
      final original = _plan(segmentId: 'segment-1');

      final unchanged = original.copyWith(name: '新名称');
      final cleared = original.copyWith(segmentId: null);

      expect(unchanged.segmentId, 'segment-1');
      expect(cleared.segmentId, isNull);
      expect(cleared.id, original.id);
      expect(cleared.createdAt, original.createdAt);
    });

    test('copyWith preserves, replaces, and explicitly clears a reminder', () {
      final original = _plan(reminderTime: ReminderTime(hour: 20, minute: 15));

      final unchanged = original.copyWith(name: '新名称');
      final replaced = original.copyWith(
        reminderTime: ReminderTime(hour: 7, minute: 30),
      );
      final cleared = original.copyWith(reminderTime: null);

      expect(unchanged.reminderTime?.hhmm, '20:15');
      expect(replaced.reminderTime?.hhmm, '07:30');
      expect(cleared.reminderTime, isNull);
      expect(cleared.id, original.id);
      expect(cleared.createdAt, original.createdAt);
    });

    test('rejects invalid dates, weekdays, and goal values', () {
      expect(
        () => _plan(
          startDate: CalendarDate(2026, 10, 14),
          endDate: CalendarDate(2026, 10, 13),
        ),
        throwsArgumentError,
      );
      expect(() => _plan(repeatWeekdays: {}), throwsArgumentError);
      expect(() => _plan(repeatWeekdays: {0}), throwsArgumentError);
      expect(
        () => _plan(goal: const PracticeGoal.loops(0)),
        throwsArgumentError,
      );
      expect(
        () => _plan(goal: const PracticeGoal.duration(Duration.zero)),
        throwsArgumentError,
      );
    });
  });

  group('PracticePlanProgress', () {
    test(
      'accumulates finalized and checkpointed loops for the matching plan',
      () {
        final plan = _plan(goal: const PracticeGoal.loops(5));
        final progress = PracticePlanProgress(
          plan: plan,
          sessions: [
            _session(id: 'first', planId: plan.id, loopCount: 2),
            _session(id: 'second', planId: plan.id, loopCount: 4),
            _session(
              id: 'checkpoint',
              planId: plan.id,
              loopCount: 1,
              completed: false,
            ),
            _session(
              id: 'empty-checkpoint',
              planId: plan.id,
              activeDuration: Duration.zero,
              completed: false,
            ),
            _session(id: 'another-plan', planId: 'plan-2', loopCount: 20),
          ],
        );

        expect(progress.sessions.map((session) => session.id), [
          'first',
          'second',
          'checkpoint',
        ]);
        expect(progress.completedLoops, 7);
        expect(progress.completedValue, 7);
        expect(progress.fraction, 1.0);
        expect(progress.isComplete, isTrue);
      },
    );

    test('accumulates active duration across multiple completed sessions', () {
      final plan = _plan(
        goal: const PracticeGoal.duration(Duration(minutes: 10)),
      );
      final progress = PracticePlanProgress(
        plan: plan,
        sessions: [
          _session(
            id: 'first',
            planId: plan.id,
            activeDuration: const Duration(minutes: 3),
          ),
          _session(
            id: 'second',
            planId: plan.id,
            activeDuration: const Duration(minutes: 4),
          ),
        ],
      );

      expect(progress.completedDuration, const Duration(minutes: 7));
      expect(
        progress.completedValue,
        const Duration(minutes: 7).inMilliseconds,
      );
      expect(progress.fraction, closeTo(0.7, 0.000001));
      expect(progress.isComplete, isFalse);
    });

    test('does not carry progress across an edited practice target', () {
      final plan = _plan(
        segmentId: 'segment-new',
        goal: const PracticeGoal.loops(5),
      );
      final progress = PracticePlanProgress(
        plan: plan,
        sessions: [
          _session(
            id: 'old-target',
            planId: plan.id,
            segmentId: 'segment-old',
            loopCount: 5,
          ),
          _session(
            id: 'new-target',
            planId: plan.id,
            segmentId: 'segment-new',
            loopCount: 2,
          ),
        ],
      );

      expect(progress.completedLoops, 2);
      expect(progress.fraction, 0.4);
    });
  });
}

PracticePlan _plan({
  String id = 'plan-1',
  String? segmentId,
  PracticeGoal goal = const PracticeGoal.loops(10),
  CalendarDate? startDate,
  CalendarDate? endDate,
  Set<int> repeatWeekdays = const {DateTime.monday},
  ReminderTime? reminderTime,
}) {
  final createdAt = DateTime.utc(2026, 10, 12, 8);
  return PracticePlan(
    id: id,
    name: '指弹计划',
    sourceId: 'source-1',
    segmentId: segmentId,
    goal: goal,
    startDate: startDate ?? CalendarDate(2026, 10, 12),
    endDate: endDate ?? CalendarDate(2026, 10, 31),
    repeatWeekdays: repeatWeekdays,
    reminderTime: reminderTime,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

PracticeSession _session({
  required String id,
  required String? planId,
  Duration activeDuration = const Duration(minutes: 1),
  int loopCount = 0,
  bool completed = true,
  String sourceId = 'source-1',
  String? segmentId,
}) {
  final startedAt = DateTime.utc(2026, 10, 12, 8);
  return PracticeSession(
    id: id,
    planId: planId,
    sourceId: sourceId,
    segmentId: segmentId,
    practiceDate: CalendarDate(2026, 10, 12),
    startedAt: startedAt,
    endedAt: startedAt.add(activeDuration),
    activeDuration: activeDuration,
    loopCount: loopCount,
    completed: completed,
  );
}

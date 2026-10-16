import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_week_summary.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';

void main() {
  group('PracticeWeekSummary', () {
    test('uses the Monday-to-Sunday week containing the selected day', () {
      final summary = PracticeWeekSummary.calculate(
        containingDate: CalendarDate(2027, 1, 1),
        plans: const [],
        sessions: const [],
      );

      expect(summary.weekStart, CalendarDate(2026, 12, 28));
      expect(summary.weekEnd, CalendarDate(2027, 1, 3));
      expect(summary.days.map((day) => day.date), [
        CalendarDate(2026, 12, 28),
        CalendarDate(2026, 12, 29),
        CalendarDate(2026, 12, 30),
        CalendarDate(2026, 12, 31),
        CalendarDate(2027, 1, 1),
        CalendarDate(2027, 1, 2),
        CalendarDate(2027, 1, 3),
      ]);
      expect(
        PracticeWeekSummary.weekStartFor(CalendarDate(2026, 10, 18)),
        CalendarDate(2026, 10, 12),
      );
      expect(
        PracticeWeekSummary.weekEndFor(CalendarDate(2026, 10, 12)),
        CalendarDate(2026, 10, 18),
      );
    });

    test('aggregates finalized activity and recovery checkpoints', () {
      final loopPlan = _plan(
        id: 'loop-plan',
        sourceId: 'source-loop',
        goal: const PracticeGoal.loops(3),
        repeatWeekdays: const {DateTime.monday, DateTime.tuesday},
      );
      final durationPlan = _plan(
        id: 'duration-plan',
        sourceId: 'source-duration',
        goal: const PracticeGoal.duration(Duration(minutes: 10)),
        repeatWeekdays: const {DateTime.monday},
      );
      final summary = PracticeWeekSummary.calculate(
        containingDate: CalendarDate(2026, 10, 14),
        plans: [loopPlan, durationPlan],
        sessions: [
          _session(
            id: 'monday-loop',
            date: CalendarDate(2026, 10, 12),
            planId: loopPlan.id,
            sourceId: loopPlan.sourceId,
            duration: const Duration(minutes: 5),
            loops: 3,
          ),
          _session(
            id: 'monday-duration',
            date: CalendarDate(2026, 10, 12),
            planId: durationPlan.id,
            sourceId: durationPlan.sourceId,
            duration: const Duration(minutes: 8),
          ),
          _session(
            id: 'monday-free-practice',
            date: CalendarDate(2026, 10, 12),
            duration: const Duration(minutes: 2),
            loops: 4,
          ),
          _session(
            id: 'tuesday-loop',
            date: CalendarDate(2026, 10, 13),
            planId: loopPlan.id,
            sourceId: loopPlan.sourceId,
            duration: const Duration(minutes: 4),
            loops: 3,
          ),
          _session(
            id: 'recovery-checkpoint',
            date: CalendarDate(2026, 10, 14),
            duration: const Duration(hours: 2),
            loops: 99,
            completed: false,
          ),
          _session(
            id: 'outside-week',
            date: CalendarDate(2026, 10, 19),
            duration: const Duration(hours: 3),
            loops: 100,
          ),
        ],
      );

      expect(summary.weekStart, CalendarDate(2026, 10, 12));
      expect(summary.weekEnd, CalendarDate(2026, 10, 18));
      expect(summary.scheduledDayCount, 2);
      expect(summary.completedDayCount, 1);
      expect(summary.scheduledPlanCount, 3);
      expect(summary.completedPlanCount, 2);
      expect(summary.uniqueScheduledPlanCount, 2);
      expect(summary.activeDuration, const Duration(hours: 2, minutes: 19));
      expect(summary.sessionCount, 5);
      expect(summary.loopCount, 109);
      expect(summary.planCompletionFraction, closeTo(2 / 3, 0.000001));
      expect(summary.dayCompletionFraction, 0.5);

      final monday = summary.days.first;
      expect(monday.scheduledPlanCount, 2);
      expect(monday.completedPlanCount, 1);
      expect(monday.isComplete, isFalse);
      expect(monday.sessionCount, 3);

      final tuesday = summary.days[1];
      expect(tuesday.scheduledPlanCount, 1);
      expect(tuesday.completedPlanCount, 1);
      expect(tuesday.isComplete, isTrue);

      final wednesday = summary.days[2];
      expect(wednesday.sessionCount, 1);
      expect(wednesday.sessions.single.completed, isFalse);
    });

    test('does not carry plan progress from one day into another', () {
      final plan = _plan(
        id: 'daily-plan',
        sourceId: 'source-1',
        goal: const PracticeGoal.loops(5),
        repeatWeekdays: const {DateTime.monday, DateTime.tuesday},
      );

      final summary = PracticeWeekSummary.calculate(
        containingDate: CalendarDate(2026, 10, 12),
        plans: [plan],
        sessions: [
          _session(
            id: 'monday',
            date: CalendarDate(2026, 10, 12),
            planId: plan.id,
            sourceId: plan.sourceId,
            loops: 3,
          ),
          _session(
            id: 'tuesday',
            date: CalendarDate(2026, 10, 13),
            planId: plan.id,
            sourceId: plan.sourceId,
            loops: 2,
          ),
        ],
      );

      expect(summary.completedPlanCount, 0);
      expect(summary.completedDayCount, 0);
      expect(summary.days[0].planProgress.single.completedLoops, 3);
      expect(summary.days[1].planProgress.single.completedLoops, 2);
    });

    test('keeps free-practice stats when the week has no scheduled plans', () {
      final summary = PracticeWeekSummary.calculate(
        containingDate: CalendarDate(2026, 10, 15),
        plans: const [],
        sessions: [
          _session(
            id: 'free-practice',
            date: CalendarDate(2026, 10, 15),
            duration: const Duration(seconds: 45),
            loops: 2,
          ),
        ],
      );

      expect(summary.scheduledDayCount, 0);
      expect(summary.completedDayCount, 0);
      expect(summary.scheduledPlanCount, 0);
      expect(summary.uniqueScheduledPlanCount, 0);
      expect(summary.planCompletionFraction, 0);
      expect(summary.dayCompletionFraction, 0);
      expect(summary.activeDuration, const Duration(seconds: 45));
      expect(summary.sessionCount, 1);
      expect(summary.loopCount, 2);
      expect(summary.days[3].hasScheduledPlans, isFalse);
      expect(summary.days[3].isComplete, isFalse);
    });
  });
}

PracticePlan _plan({
  required String id,
  required String sourceId,
  required PracticeGoal goal,
  required Set<int> repeatWeekdays,
}) {
  final timestamp = DateTime.utc(2026, 10, 1);
  return PracticePlan(
    id: id,
    name: id,
    sourceId: sourceId,
    goal: goal,
    startDate: CalendarDate(2026, 10, 1),
    endDate: CalendarDate(2026, 10, 31),
    repeatWeekdays: repeatWeekdays,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

PracticeSession _session({
  required String id,
  required CalendarDate date,
  String? planId,
  String sourceId = 'free-practice-source',
  Duration duration = Duration.zero,
  int loops = 0,
  bool completed = true,
}) {
  final startedAt = DateTime.utc(date.year, date.month, date.day, 8);
  return PracticeSession(
    id: id,
    planId: planId,
    sourceId: sourceId,
    practiceDate: date,
    startedAt: startedAt,
    endedAt: completed ? startedAt.add(duration) : null,
    activeDuration: duration,
    loopCount: loops,
    completed: completed,
  );
}

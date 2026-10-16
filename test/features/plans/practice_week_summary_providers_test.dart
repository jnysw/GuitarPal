import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_week_summary.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/plans/practice_week_summary_providers.dart';

void main() {
  test('this-week provider combines the current date, plans, and sessions', () {
    final today = CalendarDate(2026, 10, 14);
    final plan = _plan();
    final session = _session(plan);
    final container = ProviderContainer(
      overrides: [
        currentCalendarDateProvider.overrideWithValue(today),
        practicePlansProvider.overrideWithValue(AsyncData([plan])),
        practiceSessionsForWeekProvider(today)
            .overrideWithValue(AsyncData([session])),
      ],
    );
    addTearDown(container.dispose);

    final value = container.read(thisWeekPracticeSummaryProvider);

    expect(value, isA<AsyncData<PracticeWeekSummary>>());
    final summary = value.requireValue;
    expect(summary.weekStart, CalendarDate(2026, 10, 12));
    expect(summary.weekEnd, CalendarDate(2026, 10, 18));
    expect(summary.completedDayCount, 1);
    expect(summary.completedPlanCount, 1);
    expect(summary.activeDuration, const Duration(minutes: 6));
    expect(summary.sessionCount, 1);
    expect(summary.loopCount, 4);
  });
}

PracticePlan _plan() {
  final timestamp = DateTime.utc(2026, 10, 1);
  return PracticePlan(
    id: 'plan-1',
    name: '周三循环',
    sourceId: 'source-1',
    goal: const PracticeGoal.loops(4),
    startDate: CalendarDate(2026, 10, 1),
    endDate: CalendarDate(2026, 10, 31),
    repeatWeekdays: const {DateTime.wednesday},
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

PracticeSession _session(PracticePlan plan) {
  final startedAt = DateTime.utc(2026, 10, 14, 8);
  return PracticeSession(
    id: 'session-1',
    planId: plan.id,
    sourceId: plan.sourceId,
    practiceDate: CalendarDate(2026, 10, 14),
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 6)),
    activeDuration: const Duration(minutes: 6),
    loopCount: 4,
    completed: true,
  );
}

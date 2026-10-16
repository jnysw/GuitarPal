import '../practice_session/practice_session.dart';
import 'calendar_date.dart';
import 'practice_plan.dart';
import 'practice_plan_progress.dart';

/// The practice and plan progress for one calendar day in a week.
///
/// A day is complete only when it has at least one scheduled plan and every
/// scheduled plan has reached its goal on that day. Sessions from other days
/// never contribute to a plan's daily progress.
class PracticeDaySummary {
  PracticeDaySummary._({
    required this.date,
    required List<PracticePlanProgress> planProgress,
    required List<PracticeSession> sessions,
  }) : planProgress = List.unmodifiable(planProgress),
       sessions = List.unmodifiable(sessions);

  final CalendarDate date;
  final List<PracticePlanProgress> planProgress;

  /// Valid practice sessions on this day, including recovery checkpoints and
  /// free practice that is not linked to a plan.
  final List<PracticeSession> sessions;

  int get scheduledPlanCount => planProgress.length;

  int get completedPlanCount {
    return planProgress.where((progress) => progress.isComplete).length;
  }

  bool get hasScheduledPlans => planProgress.isNotEmpty;

  bool get isComplete {
    return hasScheduledPlans && completedPlanCount == scheduledPlanCount;
  }

  Duration get activeDuration {
    return sessions.fold(
      Duration.zero,
      (total, session) => total + session.activeDuration,
    );
  }

  int get sessionCount => sessions.length;

  int get loopCount {
    return sessions.fold(0, (total, session) => total + session.loopCount);
  }
}

/// A Monday-to-Sunday view of plan completion and practice activity.
///
/// [scheduledPlanCount] and [completedPlanCount] count daily plan
/// occurrences. For example, one plan scheduled on Monday, Wednesday and
/// Friday contributes three occurrences. [uniqueScheduledPlanCount] counts
/// the distinct plan definitions instead.
class PracticeWeekSummary {
  PracticeWeekSummary._({
    required this.weekStart,
    required this.weekEnd,
    required List<PracticeDaySummary> days,
  }) : days = List.unmodifiable(days);

  factory PracticeWeekSummary.calculate({
    required CalendarDate containingDate,
    required Iterable<PracticePlan> plans,
    required Iterable<PracticeSession> sessions,
  }) {
    final weekStart = weekStartFor(containingDate);
    final weekEnd = weekStart.addDays(6);
    final planValues = List<PracticePlan>.of(plans);
    final validSessions = sessions
        .where(
          (session) =>
              session.hasPracticeActivity &&
              session.practiceDate >= weekStart &&
              session.practiceDate <= weekEnd,
        )
        .toList(growable: false);

    final days = List<PracticeDaySummary>.generate(7, (index) {
      final date = weekStart.addDays(index);
      final daySessions = validSessions
          .where((session) => session.practiceDate == date)
          .toList(growable: false);
      final progress = planValues
          .where((plan) => plan.isScheduledOn(date))
          .map(
            (plan) => PracticePlanProgress(plan: plan, sessions: daySessions),
          )
          .toList(growable: false);
      return PracticeDaySummary._(
        date: date,
        planProgress: progress,
        sessions: daySessions,
      );
    });

    return PracticeWeekSummary._(
      weekStart: weekStart,
      weekEnd: weekEnd,
      days: days,
    );
  }

  final CalendarDate weekStart;
  final CalendarDate weekEnd;
  final List<PracticeDaySummary> days;

  static CalendarDate weekStartFor(CalendarDate date) {
    return date.addDays(DateTime.monday - date.weekday);
  }

  static CalendarDate weekEndFor(CalendarDate date) {
    return weekStartFor(date).addDays(6);
  }

  int get scheduledDayCount {
    return days.where((day) => day.hasScheduledPlans).length;
  }

  int get completedDayCount {
    return days.where((day) => day.isComplete).length;
  }

  int get scheduledPlanCount {
    return days.fold(0, (total, day) => total + day.scheduledPlanCount);
  }

  int get completedPlanCount {
    return days.fold(0, (total, day) => total + day.completedPlanCount);
  }

  int get uniqueScheduledPlanCount {
    return days
        .expand((day) => day.planProgress)
        .map((progress) => progress.plan.id)
        .toSet()
        .length;
  }

  Duration get activeDuration {
    return days.fold(Duration.zero, (total, day) => total + day.activeDuration);
  }

  int get sessionCount {
    return days.fold(0, (total, day) => total + day.sessionCount);
  }

  int get loopCount {
    return days.fold(0, (total, day) => total + day.loopCount);
  }

  double get planCompletionFraction {
    if (scheduledPlanCount == 0) return 0;
    return completedPlanCount / scheduledPlanCount;
  }

  double get dayCompletionFraction {
    if (scheduledDayCount == 0) return 0;
    return completedDayCount / scheduledDayCount;
  }
}

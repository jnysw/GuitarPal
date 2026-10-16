import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_session/practice_session.dart';
import '../../../domain/practice_source/practice_source.dart';

class PracticeTrendBucket {
  const PracticeTrendBucket({
    required this.start,
    required this.end,
    required this.activeDuration,
    required this.sessionCount,
    required this.loopCount,
  });

  final CalendarDate start;
  final CalendarDate end;
  final Duration activeDuration;
  final int sessionCount;
  final int loopCount;

  bool get hasActivity => sessionCount > 0;
}

class PracticeInsights {
  const PracticeInsights._({
    required this.totalActiveDuration,
    required this.sessionCount,
    required this.loopCount,
    required this.activeDayCount,
    required this.currentStreakDays,
    required this.completedSourceCount,
    required this.sourceCount,
    required this.recentDays,
    required this.recentWeeks,
  });

  factory PracticeInsights.calculate({
    required CalendarDate today,
    required Iterable<PracticeSession> sessions,
    required Iterable<PracticeSource> sources,
  }) {
    final validSessions = sessions
        .where(
          (session) =>
              session.hasPracticeActivity && session.practiceDate <= today,
        )
        .toList(growable: false);
    final sourceValues = sources.toList(growable: false);
    final activeDates = validSessions
        .map((session) => session.practiceDate)
        .toSet();

    final recentDayStart = today.addDays(-13);
    final recentDays = List<PracticeTrendBucket>.generate(14, (index) {
      final date = recentDayStart.addDays(index);
      return _bucketForRange(validSessions, date, date);
    }, growable: false);

    final thisWeekStart = today.addDays(DateTime.monday - today.weekday);
    final recentWeekStart = thisWeekStart.addDays(-77);
    final recentWeeks = List<PracticeTrendBucket>.generate(12, (index) {
      final start = recentWeekStart.addDays(index * 7);
      return _bucketForRange(validSessions, start, start.addDays(6));
    }, growable: false);

    return PracticeInsights._(
      totalActiveDuration: validSessions.fold(
        Duration.zero,
        (total, session) => total + session.activeDuration,
      ),
      sessionCount: validSessions.length,
      loopCount: validSessions.fold(
        0,
        (total, session) => total + session.loopCount,
      ),
      activeDayCount: activeDates.length,
      currentStreakDays: _currentStreak(today, activeDates),
      completedSourceCount: sourceValues
          .where((source) => source.isCompleted)
          .length,
      sourceCount: sourceValues.length,
      recentDays: recentDays,
      recentWeeks: recentWeeks,
    );
  }

  final Duration totalActiveDuration;
  final int sessionCount;
  final int loopCount;
  final int activeDayCount;
  final int currentStreakDays;
  final int completedSourceCount;
  final int sourceCount;
  final List<PracticeTrendBucket> recentDays;
  final List<PracticeTrendBucket> recentWeeks;
}

PracticeTrendBucket _bucketForRange(
  List<PracticeSession> sessions,
  CalendarDate start,
  CalendarDate end,
) {
  final values = sessions
      .where(
        (session) =>
            session.practiceDate >= start && session.practiceDate <= end,
      )
      .toList(growable: false);
  return PracticeTrendBucket(
    start: start,
    end: end,
    activeDuration: values.fold(
      Duration.zero,
      (total, session) => total + session.activeDuration,
    ),
    sessionCount: values.length,
    loopCount: values.fold(0, (total, session) => total + session.loopCount),
  );
}

int _currentStreak(CalendarDate today, Set<CalendarDate> activeDates) {
  var cursor = activeDates.contains(today) ? today : today.addDays(-1);
  var streak = 0;
  while (activeDates.contains(cursor)) {
    streak += 1;
    cursor = cursor.addDays(-1);
  }
  return streak;
}

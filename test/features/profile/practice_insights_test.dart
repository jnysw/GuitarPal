import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/profile/domain/practice_insights.dart';

void main() {
  final today = CalendarDate(2026, 10, 14);
  final now = DateTime.utc(2026, 10, 14, 9);

  test('aggregates lifetime statistics and recent trend buckets', () {
    final sources = [
      PracticeSource(
        id: 'completed-source',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '已完成曲目',
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      PracticeSource(
        id: 'pending-source',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.video,
        title: '待练曲目',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final sessions = [
      _session(
        id: 'today',
        date: today,
        duration: const Duration(minutes: 10),
        loops: 2,
      ),
      _session(
        id: 'yesterday-checkpoint',
        date: today.addDays(-1),
        duration: const Duration(minutes: 20),
        loops: 3,
        completed: false,
      ),
      _session(
        id: 'gap-day',
        date: today.addDays(-3),
        duration: const Duration(minutes: 5),
        loops: 1,
      ),
      _session(
        id: 'older',
        date: CalendarDate(2026, 9, 1),
        duration: const Duration(minutes: 15),
        loops: 4,
      ),
      _session(
        id: 'empty',
        date: today.addDays(-2),
        duration: Duration.zero,
        loops: 0,
      ),
      _session(
        id: 'future',
        date: today.addDays(1),
        duration: const Duration(hours: 1),
        loops: 10,
      ),
    ];

    final insights = PracticeInsights.calculate(
      today: today,
      sessions: sessions,
      sources: sources,
    );

    expect(insights.totalActiveDuration, const Duration(minutes: 50));
    expect(insights.sessionCount, 4);
    expect(insights.loopCount, 10);
    expect(insights.activeDayCount, 4);
    expect(insights.currentStreakDays, 2);
    expect(insights.completedSourceCount, 1);
    expect(insights.sourceCount, 2);
    expect(insights.recentDays, hasLength(14));
    expect(insights.recentDays.first.start, CalendarDate(2026, 10, 1));
    expect(insights.recentDays.last.start, today);
    expect(
      insights.recentDays.last.activeDuration,
      const Duration(minutes: 10),
    );
    expect(insights.recentWeeks, hasLength(12));
    expect(insights.recentWeeks.last.end, CalendarDate(2026, 10, 18));
    expect(
      insights.recentWeeks.fold(
        Duration.zero,
        (total, bucket) => total + bucket.activeDuration,
      ),
      const Duration(minutes: 50),
    );
  });

  test('keeps a streak alive through yesterday before today is practiced', () {
    final insights = PracticeInsights.calculate(
      today: today,
      sessions: [
        _session(
          id: 'yesterday',
          date: today.addDays(-1),
          duration: const Duration(minutes: 5),
        ),
        _session(
          id: 'two-days-ago',
          date: today.addDays(-2),
          duration: const Duration(minutes: 5),
        ),
      ],
      sources: const [],
    );

    expect(insights.currentStreakDays, 2);
  });
}

PracticeSession _session({
  required String id,
  required CalendarDate date,
  required Duration duration,
  int loops = 0,
  bool completed = true,
}) {
  final startedAt = date.toLocalDateTime().add(const Duration(hours: 9));
  return PracticeSession(
    id: id,
    sourceId: 'source-1',
    practiceDate: date,
    startedAt: startedAt,
    endedAt: startedAt.add(duration),
    activeDuration: duration,
    loopCount: loops,
    completed: completed,
  );
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_progress.dart';
import 'package:guitar_pal/domain/practice_plan/practice_week_summary.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/application/source_launcher.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/library/practice_source_providers.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/plan_overview_screen.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/plans/practice_week_summary_providers.dart';

void main() {
  testWidgets('records partial loop progress and refreshes the plan card', (
    tester,
  ) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.now();
    final today = CalendarDate.fromDateTime(now);
    final timestamp = now.toUtc();

    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: '指弹教程',
        externalId: 'BV1plan',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await DriftPracticePlanRepository(database).save(
      PracticePlan(
        id: 'plan-1',
        name: '每日循环',
        sourceId: 'source-1',
        goal: const PracticeGoal.loops(5),
        startDate: today,
        endDate: today.addDays(6),
        repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          currentCalendarDateProvider.overrideWithValue(today),
        ],
        child: const MaterialApp(home: PlanOverviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日循环'), findsOneWidget);
    expect(find.text('0/5 次'), findsOneWidget);
    expect(find.byKey(const Key('practice_week_summary')), findsOneWidget);
    expect(find.text('本周进度'), findsOneWidget);

    final recordButton = find.byKey(const ValueKey('plan_record_plan-1'));
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan_record_value_field')),
      '3',
    );
    await tester.tap(find.byKey(const Key('plan_record_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('3/5 次'), findsOneWidget);
    final sessions = await database.select(database.practiceSessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.planId, 'plan-1');
    expect(sessions.single.loopCount, 3);
    expect(sessions.single.completed, isTrue);
    expect(find.text('1 次'), findsOneWidget);
    expect(find.text('3 次'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'opens a reference source externally instead of entering player',
    (tester) async {
      final launcher = _RecordingSourceLauncher();
      final now = DateTime.now();
      final today = CalendarDate.fromDateTime(now);
      final timestamp = now.toUtc();
      final source = PracticeSource(
        id: 'youtube-source',
        platform: SourcePlatform.youtube,
        kind: SourceKind.webReference,
        title: '外部吉他教程',
        originalUri: Uri.parse('https://www.youtube.com/watch?v=test-video'),
        canonicalUri: Uri.parse('https://www.youtube.com/watch?v=test-video'),
        externalId: 'test-video',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final plan = PracticePlan(
        id: 'reference-plan',
        name: '外部来源计划',
        sourceId: source.id,
        goal: const PracticeGoal.duration(Duration(minutes: 10)),
        startDate: today,
        endDate: today.addDays(6),
        repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PlanOverviewScreen()),
          GoRoute(
            path: '/practice/:sourceId',
            builder: (_, _) => const Scaffold(body: Text('播放器哨兵页面')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            practicePlansProvider.overrideWithValue(AsyncData([plan])),
            todayPlanProgressProvider.overrideWithValue(
              const AsyncData(<PracticePlanProgress>[]),
            ),
            thisWeekPracticeSummaryProvider.overrideWithValue(
              AsyncData(
                PracticeWeekSummary.calculate(
                  containingDate: today,
                  plans: [plan],
                  sessions: const [],
                ),
              ),
            ),
            practiceSourceByIdProvider(source.id)
                .overrideWithValue(AsyncData(source)),
            currentCalendarDateProvider.overrideWithValue(today),
            sourceLauncherProvider.overrideWithValue(launcher),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('打开原内容'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan_start_reference-plan')));
      await tester.pumpAndSettle();

      expect(launcher.openedSources, hasLength(1));
      expect(launcher.openedSources.single.id, source.id);
      expect(launcher.openedSources.single.canonicalUri, source.canonicalUri);
      expect(find.text('播放器哨兵页面'), findsNothing);
      expect(find.text('外部来源计划'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

final class _RecordingSourceLauncher implements SourceLauncher {
  final List<PracticeSource> openedSources = [];

  @override
  Future<bool> open(PracticeSource source) async {
    openedSources.add(source);
    return true;
  }
}

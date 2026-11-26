import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/core/platform/practice_reminder_gateway.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/practice_reminder_providers.dart';
import 'package:guitar_pal/features/plans/practice_reminder_settings_screen.dart';

void main() {
  testWidgets('empty reminder center offers to create a plan', (tester) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const PracticeReminderSettingsScreen(),
        ),
        GoRoute(
          path: '/plans/new',
          builder: (_, _) => const Scaffold(body: Text('计划编辑器哨兵')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有可设置提醒的练习计划。'), findsOneWidget);
    await tester.tap(find.text('新建计划'));
    await tester.pumpAndSettle();
    expect(find.text('计划编辑器哨兵'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('enables and disables a reminder outside the plan editor', (
    tester,
  ) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final gateway = _FakeReminderGateway();
    final now = DateTime.utc(2026, 10, 26, 8);
    final today = CalendarDate(2026, 10, 26);
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '测试曲目',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await DriftPracticePlanRepository(database).save(
      PracticePlan(
        id: 'plan-1',
        name: '晚间练习',
        sourceId: 'source-1',
        goal: const PracticeGoal.loops(5),
        startDate: today,
        endDate: today.addDays(10),
        repeatWeekdays: const {1, 3, 5},
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          practiceReminderGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: PracticeReminderSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 / 1 个计划已开启'), findsOneWidget);
    final switchFinder = find.byKey(
      const ValueKey('plan_reminder_switch_plan-1'),
    );
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(gateway.permissionRequests, 1);
    expect(find.text('1 / 1 个计划已开启'), findsOneWidget);
    final enabledPlan = await DriftPracticePlanRepository(database)
        .getById('plan-1');
    expect(enabledPlan?.reminderTime?.hhmm, '20:00');

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(find.text('0 / 1 个计划已开启'), findsOneWidget);
    final disabledPlan = await DriftPracticePlanRepository(database)
        .getById('plan-1');
    expect(disabledPlan?.reminderTime, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}

final class _FakeReminderGateway implements PracticeReminderGateway {
  int permissionRequests = 0;

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    permissionRequests += 1;
    return ReminderPermissionStatus.granted;
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> synchronize(Iterable<PracticePlan> plans) async {}
}

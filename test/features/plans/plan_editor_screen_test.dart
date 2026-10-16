import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/core/platform/practice_reminder_gateway.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/reminder_time.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/plan_editor_screen.dart';
import 'package:guitar_pal/features/plans/practice_reminder_providers.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets(
    'preselects a segment, switches goal type, and saves through real Drift',
    (tester) async {
      await _seedSourceAndSegment(database);
      await _pumpEditor(
        tester,
        database,
        initialSourceId: 'source-1',
        initialSegmentId: 'segment-1',
        withBackRoute: true,
      );

      final sourceDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(PlanEditorKeys.sourceDropdown),
      );
      final segmentDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(PlanEditorKeys.segmentDropdown),
      );
      expect(sourceDropdown.initialValue, 'source-1');
      expect(segmentDropdown.initialValue, 'segment-1');
      expect(find.text('第一句 · 0:03–0:08'), findsOneWidget);

      await tester.ensureVisible(find.byKey(PlanEditorKeys.goalTypeControl));
      await tester.tap(find.text('练习分钟'));
      await tester.pump();

      expect(find.byKey(PlanEditorKeys.loopGoalField), findsNothing);
      expect(find.byKey(PlanEditorKeys.durationGoalField), findsOneWidget);
      await tester.enterText(
        find.byKey(PlanEditorKeys.durationGoalField),
        '25',
      );
      await tester.enterText(PlanEditorKeys.nameField.finder, '  每日指弹强化  ');
      tester.testTextInput.hide();
      await tester.pump();

      await tester.ensureVisible(find.byKey(PlanEditorKeys.saveButton));
      await tester.tap(find.byKey(PlanEditorKeys.saveButton));
      await tester.pumpAndSettle();

      final rows = await database.select(database.practicePlans).get();
      expect(rows, hasLength(1));
      final stored = rows.single;
      expect(stored.name, '每日指弹强化');
      expect(stored.sourceId, 'source-1');
      expect(stored.segmentId, 'segment-1');
      expect(stored.goalType, 'duration');
      expect(stored.targetLoops, isNull);
      expect(stored.targetDurationMilliseconds, 25 * 60 * 1000);
      expect(stored.repeatWeekdayMask, 0x7f);
      expect(stored.startDay, lessThanOrEqualTo(stored.endDay));

      await _disposeEditor(tester);
    },
  );

  testWidgets('shows an actionable empty state when the library is empty', (
    tester,
  ) async {
    await _pumpEditor(tester, database);

    expect(find.byKey(PlanEditorKeys.screen), findsWidgets);
    expect(find.text('还没有可加入计划的练习'), findsOneWidget);
    expect(find.text('请先通过链接或本地视频新建练习内容，再回来创建计划。'), findsOneWidget);
    expect(find.byKey(PlanEditorKeys.createPracticeButton), findsOneWidget);
    expect(find.byKey(PlanEditorKeys.nameField), findsNothing);
    expect(find.byKey(PlanEditorKeys.saveButton), findsNothing);

    await _disposeEditor(tester);
  });

  testWidgets('practice reminder is off by default', (tester) async {
    await _seedSourceAndSegment(database);
    await _pumpEditor(tester, database, initialSourceId: 'source-1');

    await tester.ensureVisible(find.byKey(PlanEditorKeys.reminderSwitch));
    final reminderSwitch = tester.widget<SwitchListTile>(
      find.byKey(PlanEditorKeys.reminderSwitch),
    );
    expect(reminderSwitch.value, isFalse);
    expect(find.byKey(PlanEditorKeys.reminderTimeButton), findsNothing);
    expect(find.text('未开启'), findsOneWidget);

    await _disposeEditor(tester);
  });

  testWidgets('requests permission and saves the default 20:00 reminder', (
    tester,
  ) async {
    await _seedSourceAndSegment(database);
    final gateway = _FakePracticeReminderGateway(
      ReminderPermissionStatus.granted,
    );
    await _pumpEditor(
      tester,
      database,
      initialSourceId: 'source-1',
      withBackRoute: true,
      reminderGateway: gateway,
    );

    await tester.enterText(PlanEditorKeys.nameField.finder, '晚间练习');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byKey(PlanEditorKeys.reminderSwitch));
    await tester.tap(find.byKey(PlanEditorKeys.reminderSwitch));
    await tester.pump();

    expect(find.byKey(PlanEditorKeys.reminderTimeButton), findsOneWidget);
    expect(find.text('提醒时间  20:00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(PlanEditorKeys.saveButton));
    await tester.tap(find.byKey(PlanEditorKeys.saveButton));
    await tester.pumpAndSettle();

    expect(gateway.requestPermissionCalls, 1);
    final rows = await database.select(database.practicePlans).get();
    expect(rows, hasLength(1));
    expect(rows.single.reminderMinutesSinceMidnight, 20 * 60);

    await _disposeEditor(tester);
  });

  testWidgets('shows the persisted reminder while editing', (tester) async {
    await _seedSourceAndSegment(database);
    final today = CalendarDate.fromDateTime(DateTime.now());
    final now = DateTime.utc(2026, 10, 14, 8);
    await DriftPracticePlanRepository(database).save(
      PracticePlan(
        id: 'plan-1',
        name: '午后练习',
        sourceId: 'source-1',
        segmentId: 'segment-1',
        goal: PracticeGoal.loops(8),
        startDate: today,
        endDate: today.addDays(6),
        repeatWeekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        },
        reminderTime: ReminderTime(hour: 14, minute: 35),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpEditor(tester, database, planId: 'plan-1');
    await tester.ensureVisible(find.byKey(PlanEditorKeys.reminderSwitch));

    final reminderSwitch = tester.widget<SwitchListTile>(
      find.byKey(PlanEditorKeys.reminderSwitch),
    );
    expect(reminderSwitch.value, isTrue);
    expect(find.byKey(PlanEditorKeys.reminderTimeButton), findsOneWidget);
    expect(find.text('提醒时间  14:35'), findsOneWidget);

    await _disposeEditor(tester);
  });

  testWidgets('saves the plan without a reminder when permission is denied', (
    tester,
  ) async {
    await _seedSourceAndSegment(database);
    final gateway = _FakePracticeReminderGateway(
      ReminderPermissionStatus.denied,
    );
    await _pumpEditor(
      tester,
      database,
      initialSourceId: 'source-1',
      withBackRoute: true,
      reminderGateway: gateway,
    );

    await tester.enterText(PlanEditorKeys.nameField.finder, '无需通知的练习');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byKey(PlanEditorKeys.reminderSwitch));
    await tester.tap(find.byKey(PlanEditorKeys.reminderSwitch));
    await tester.pump();
    await tester.ensureVisible(find.byKey(PlanEditorKeys.saveButton));
    await tester.tap(find.byKey(PlanEditorKeys.saveButton));
    await tester.pumpAndSettle();

    expect(gateway.requestPermissionCalls, 1);
    final rows = await database.select(database.practicePlans).get();
    expect(rows, hasLength(1));
    expect(rows.single.reminderMinutesSinceMidnight, isNull);

    await _disposeEditor(tester);
  });
}

extension on Key {
  Finder get finder => find.byKey(this);
}

Future<void> _pumpEditor(
  WidgetTester tester,
  db.AppDatabase database, {
  String? planId,
  String? initialSourceId,
  String? initialSegmentId,
  bool withBackRoute = false,
  PracticeReminderGateway? reminderGateway,
}) async {
  final editor = PlanEditorScreen(
    planId: planId,
    initialSourceId: initialSourceId,
    initialSegmentId: initialSegmentId,
  );
  final home = withBackRoute
      ? Navigator(
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: SizedBox.shrink()),
            ),
            MaterialPageRoute<void>(builder: (_) => editor),
          ],
        )
      : editor;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (reminderGateway != null)
          practiceReminderGatewayProvider.overrideWithValue(reminderGateway),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeEditor(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _seedSourceAndSegment(db.AppDatabase database) async {
  final now = DateTime.utc(2026, 10, 13, 8);
  await DriftPracticeSourceRepository(database).save(
    PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.webReference,
      title: '指弹教程',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await DriftPracticeSegmentRepository(database).save(
    PracticeSegment(
      id: 'segment-1',
      sourceId: 'source-1',
      title: '第一句',
      start: const Duration(seconds: 3),
      end: const Duration(seconds: 8),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

class _FakePracticeReminderGateway implements PracticeReminderGateway {
  _FakePracticeReminderGateway(this.permissionStatus);

  final ReminderPermissionStatus permissionStatus;
  int requestPermissionCalls = 0;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    requestPermissionCalls += 1;
    return permissionStatus;
  }

  @override
  Future<void> synchronize(Iterable<PracticePlan> plans) async {}
}

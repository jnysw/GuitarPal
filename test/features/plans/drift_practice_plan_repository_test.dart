import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftPracticePlanRepository repository;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftPracticePlanRepository(database);
    final now = DateTime.utc(2026, 10, 12, 8);
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: 'Blues lesson',
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
  });

  tearDown(() => database.close());

  test(
    'round-trips loop goals, dates, weekdays, and an optional segment',
    () async {
      final plan = _plan(
        id: 'loop-plan',
        segmentId: 'segment-1',
        goal: const PracticeGoal.loops(12),
        repeatWeekdays: const {
          DateTime.monday,
          DateTime.wednesday,
          DateTime.saturday,
        },
      );

      await repository.save(plan);
      final restored = await repository.getById(plan.id);

      expect(restored?.id, plan.id);
      expect(restored?.name, plan.name);
      expect(restored?.sourceId, 'source-1');
      expect(restored?.segmentId, 'segment-1');
      expect(restored?.goal.type, PracticeGoalType.loops);
      expect(restored?.goal.targetLoops, 12);
      expect(restored?.goal.targetDuration, isNull);
      expect(restored?.startDate, CalendarDate(2026, 10, 12));
      expect(restored?.endDate, CalendarDate(2026, 10, 31));
      expect(restored?.repeatWeekdays, plan.repeatWeekdays);
      expect(restored?.createdAt, plan.createdAt);
      expect(restored?.updatedAt, plan.updatedAt);
    },
  );

  test('round-trips duration goals and updates an existing plan', () async {
    final original = _plan(
      id: 'duration-plan',
      goal: const PracticeGoal.duration(Duration(minutes: 15)),
    );
    await repository.save(original);

    final updated = original.copyWith(
      name: '更新后的计划',
      segmentId: 'segment-1',
      goal: const PracticeGoal.duration(Duration(minutes: 20)),
      updatedAt: original.updatedAt.add(const Duration(hours: 1)),
    );
    await repository.save(updated);

    final stored = await repository.watchAll().first;
    expect(stored, hasLength(1));
    expect(stored.single.name, '更新后的计划');
    expect(stored.single.segmentId, 'segment-1');
    expect(stored.single.goal.targetDuration, const Duration(minutes: 20));
    expect(stored.single.goal.targetLoops, isNull);
    expect(stored.single.createdAt, original.createdAt);
    expect(stored.single.updatedAt, updated.updatedAt);
  });

  test('watches only plans scheduled for the requested date', () async {
    await repository.save(
      _plan(
        id: 'weekday-plan',
        repeatWeekdays: const {DateTime.monday, DateTime.wednesday},
      ),
    );
    await repository.save(
      _plan(
        id: 'future-plan',
        startDate: CalendarDate(2026, 11, 2),
        endDate: CalendarDate(2026, 11, 30),
        repeatWeekdays: const {DateTime.monday},
      ),
    );

    final monday = await repository
        .watchScheduledFor(CalendarDate(2026, 10, 12))
        .first;
    final tuesday = await repository
        .watchScheduledFor(CalendarDate(2026, 10, 13))
        .first;

    expect(monday.map((plan) => plan.id), ['weekday-plan']);
    expect(tuesday, isEmpty);
  });
}

PracticePlan _plan({
  required String id,
  String? segmentId,
  PracticeGoal goal = const PracticeGoal.loops(10),
  CalendarDate? startDate,
  CalendarDate? endDate,
  Set<int> repeatWeekdays = const {DateTime.monday},
}) {
  final createdAt = DateTime.utc(2026, 10, 12, 8);
  return PracticePlan(
    id: id,
    name: '每日基本功',
    sourceId: 'source-1',
    segmentId: segmentId,
    goal: goal,
    startDate: startDate ?? CalendarDate(2026, 10, 12),
    endDate: endDate ?? CalendarDate(2026, 10, 31),
    repeatWeekdays: repeatWeekdays,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

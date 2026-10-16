import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_repository.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment_repository.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/plans/application/practice_plan_service.dart';

void main() {
  late _MemoryPlanRepository planRepository;
  late _MemorySourceRepository sourceRepository;
  late _MemorySegmentRepository segmentRepository;
  late PracticePlanService service;

  final startDate = CalendarDate(2026, 10, 13);
  final endDate = CalendarDate(2026, 11, 13);
  final now = DateTime.utc(2026, 10, 13, 8, 30);

  setUp(() {
    planRepository = _MemoryPlanRepository();
    sourceRepository = _MemorySourceRepository()..sources.add(_source());
    segmentRepository = _MemorySegmentRepository()..segments.add(_segment());
    service = PracticePlanService(
      planRepository,
      sourceRepository,
      segmentRepository,
      clock: () => now,
    );
  });

  test('creates and persists a plan with a trimmed name', () async {
    final plan = await service.create(
      name: '  每日主歌练习  ',
      sourceId: 'source-1',
      segmentId: 'segment-1',
      goal: const PracticeGoal.loops(12),
      startDate: startDate,
      endDate: endDate,
      repeatWeekdays: const {1, 3, 5},
    );

    expect(plan.name, '每日主歌练习');
    expect(plan.sourceId, 'source-1');
    expect(plan.segmentId, 'segment-1');
    expect(plan.goal.type, PracticeGoalType.loops);
    expect(plan.goal.targetLoops, 12);
    expect(plan.startDate, startDate);
    expect(plan.endDate, endDate);
    expect(plan.repeatWeekdays, {1, 3, 5});
    expect(plan.createdAt, now);
    expect(plan.updatedAt, now);
    expect(planRepository.plans, [plan]);
  });

  test(
    'updates editable fields while preserving identity and creation time',
    () async {
      final createdAt = DateTime.utc(2026, 10, 1, 6);
      final original = PracticePlan(
        id: 'plan-1',
        name: '旧计划',
        sourceId: 'source-1',
        segmentId: 'segment-1',
        goal: const PracticeGoal.loops(5),
        startDate: startDate,
        endDate: endDate,
        repeatWeekdays: const {1, 2, 3, 4, 5},
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      await planRepository.save(original);

      final updated = await service.update(
        original,
        name: '  周末整曲练习  ',
        sourceId: 'source-1',
        goal: const PracticeGoal.duration(Duration(minutes: 20)),
        startDate: CalendarDate(2026, 10, 17),
        endDate: CalendarDate(2026, 12, 31),
        repeatWeekdays: const {6, 7},
      );

      expect(updated.id, 'plan-1');
      expect(updated.createdAt, createdAt);
      expect(updated.updatedAt, now);
      expect(updated.name, '周末整曲练习');
      expect(updated.segmentId, isNull);
      expect(updated.goal.type, PracticeGoalType.duration);
      expect(updated.goal.targetDuration, const Duration(minutes: 20));
      expect(updated.repeatWeekdays, {6, 7});
      expect(planRepository.plans, [updated]);
    },
  );

  test('rejects a missing source without saving a plan', () async {
    await expectLater(
      service.create(
        name: '不存在的来源',
        sourceId: 'missing-source',
        goal: const PracticeGoal.loops(5),
        startDate: startDate,
        endDate: endDate,
        repeatWeekdays: const {1},
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '所选练习内容不存在',
        ),
      ),
    );

    expect(planRepository.plans, isEmpty);
  });

  test(
    'rejects a segment that does not belong to the selected source',
    () async {
      sourceRepository.sources.add(_source(id: 'source-2'));

      await expectLater(
        service.create(
          name: '错误片段',
          sourceId: 'source-2',
          segmentId: 'segment-1',
          goal: const PracticeGoal.loops(5),
          startDate: startDate,
          endDate: endDate,
          repeatWeekdays: const {1},
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '所选片段不属于当前练习内容',
          ),
        ),
      );

      expect(planRepository.plans, isEmpty);
    },
  );

  test('rejects an end date before the start date', () async {
    await expectLater(
      service.create(
        name: '日期错误',
        sourceId: 'source-1',
        goal: const PracticeGoal.loops(5),
        startDate: CalendarDate(2026, 10, 14),
        endDate: CalendarDate(2026, 10, 13),
        repeatWeekdays: const {1},
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '截止日期不能早于开始日期',
        ),
      ),
    );
  });

  test('rejects an empty or out-of-range weekday selection', () async {
    Future<PracticePlan> create(Set<int> weekdays) {
      return service.create(
        name: '星期错误',
        sourceId: 'source-1',
        goal: const PracticeGoal.loops(5),
        startDate: startDate,
        endDate: endDate,
        repeatWeekdays: weekdays,
      );
    }

    await expectLater(
      create(const {}),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '请至少选择一个练习日',
        ),
      ),
    );
    await expectLater(create(const {0, 1}), throwsArgumentError);
    await expectLater(create(const {7, 8}), throwsArgumentError);
    expect(planRepository.plans, isEmpty);
  });
}

PracticeSource _source({String id = 'source-1'}) {
  final createdAt = DateTime.utc(2026, 10, 1);
  return PracticeSource(
    id: id,
    platform: SourcePlatform.local,
    kind: SourceKind.video,
    title: '练习视频',
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

PracticeSegment _segment() {
  final createdAt = DateTime.utc(2026, 10, 1);
  return PracticeSegment(
    id: 'segment-1',
    sourceId: 'source-1',
    title: '主歌',
    start: const Duration(seconds: 10),
    end: const Duration(seconds: 20),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

final class _MemoryPlanRepository implements PracticePlanRepository {
  final List<PracticePlan> plans = [];

  @override
  Future<void> delete(String id) async {
    plans.removeWhere((plan) => plan.id == id);
  }

  @override
  Future<PracticePlan?> getById(String id) async {
    return plans.where((plan) => plan.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticePlan plan) async {
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index == -1) {
      plans.add(plan);
    } else {
      plans[index] = plan;
    }
  }

  @override
  Stream<List<PracticePlan>> watchAll() => Stream.value(List.of(plans));

  @override
  Stream<List<PracticePlan>> watchScheduledFor(CalendarDate date) {
    return Stream.value(
      plans.where((plan) => plan.isScheduledOn(date)).toList(),
    );
  }
}

final class _MemorySourceRepository implements PracticeSourceRepository {
  final List<PracticeSource> sources = [];

  @override
  Future<void> delete(String id) async {
    sources.removeWhere((source) => source.id == id);
  }

  @override
  Future<PracticeSource?> getById(String id) async {
    return sources.where((source) => source.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSource source) async {
    final index = sources.indexWhere((item) => item.id == source.id);
    if (index == -1) {
      sources.add(source);
    } else {
      sources[index] = source;
    }
  }

  @override
  Stream<List<PracticeSource>> watchAll() => Stream.value(List.of(sources));
}

final class _MemorySegmentRepository implements PracticeSegmentRepository {
  final List<PracticeSegment> segments = [];

  @override
  Future<void> delete(String id) async {
    segments.removeWhere((segment) => segment.id == id);
  }

  @override
  Future<PracticeSegment?> getById(String id) async {
    return segments.where((segment) => segment.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSegment segment) async {
    final index = segments.indexWhere((item) => item.id == segment.id);
    if (index == -1) {
      segments.add(segment);
    } else {
      segments[index] = segment;
    }
  }

  @override
  Stream<List<PracticeSegment>> watchBySource(String sourceId) {
    return Stream.value(
      segments.where((segment) => segment.sourceId == sourceId).toList(),
    );
  }
}

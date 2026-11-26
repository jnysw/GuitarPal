import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_repository.dart';
import 'package:guitar_pal/domain/practice_plan/reminder_time.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment_repository.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/plans/application/practice_plan_service.dart';

void main() {
  late _MemoryPlanRepository planRepository;
  late PracticePlanService service;

  final now = DateTime.utc(2026, 10, 14, 8, 30);
  final startDate = CalendarDate(2026, 10, 14);
  final endDate = CalendarDate(2026, 11, 14);

  setUp(() {
    planRepository = _MemoryPlanRepository();
    service = PracticePlanService(
      planRepository,
      _MemorySourceRepository(_source()),
      const _EmptySegmentRepository(),
      clock: () => now,
    );
  });

  test('create persists the selected reminder time', () async {
    final reminder = ReminderTime(hour: 20, minute: 5);

    final created = await service.create(
      name: '晚间练习',
      sourceId: 'source-1',
      goal: const PracticeGoal.loops(8),
      startDate: startDate,
      endDate: endDate,
      repeatWeekdays: const {DateTime.monday, DateTime.wednesday},
      reminderTime: reminder,
    );

    expect(created.reminderTime, reminder);
    expect(planRepository.plans.single.reminderTime?.hhmm, '20:05');
  });

  test('update can replace and disable an existing reminder', () async {
    final createdAt = DateTime.utc(2026, 10, 1, 6);
    final original = PracticePlan(
      id: 'plan-1',
      name: '每日练习',
      sourceId: 'source-1',
      goal: const PracticeGoal.loops(5),
      startDate: startDate,
      endDate: endDate,
      repeatWeekdays: const {DateTime.wednesday},
      reminderTime: ReminderTime(hour: 20, minute: 0),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await planRepository.save(original);

    final replaced = await service.update(
      original,
      name: original.name,
      sourceId: original.sourceId,
      goal: original.goal,
      startDate: original.startDate,
      endDate: original.endDate,
      repeatWeekdays: original.repeatWeekdays,
      reminderTime: ReminderTime(hour: 7, minute: 45),
    );
    final disabled = await service.update(
      replaced,
      name: replaced.name,
      sourceId: replaced.sourceId,
      goal: replaced.goal,
      startDate: replaced.startDate,
      endDate: replaced.endDate,
      repeatWeekdays: replaced.repeatWeekdays,
      reminderTime: null,
    );

    expect(replaced.reminderTime?.hhmm, '07:45');
    expect(disabled.reminderTime, isNull);
    expect(disabled.id, original.id);
    expect(disabled.createdAt, createdAt);
    expect(disabled.updatedAt, now);
    expect(planRepository.plans.single, same(disabled));
  });
}

PracticeSource _source() {
  final createdAt = DateTime.utc(2026, 10, 1);
  return PracticeSource(
    id: 'source-1',
    platform: SourcePlatform.local,
    kind: SourceKind.video,
    title: '练习视频',
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
    for (final plan in plans) {
      if (plan.id == id) return plan;
    }
    return null;
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
  const _MemorySourceRepository(this.source);

  final PracticeSource source;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<PracticeSource?> getById(String id) async {
    return id == source.id ? source : null;
  }

  @override
  Future<void> save(PracticeSource source) async {}

  @override
  Stream<List<PracticeSource>> watchAll() => Stream.value([source]);
}

final class _EmptySegmentRepository implements PracticeSegmentRepository {
  const _EmptySegmentRepository();

  @override
  Stream<List<PracticeSegment>> watchAll() => Stream.value(const []);

  @override
  Future<void> delete(String id) async {}

  @override
  Future<PracticeSegment?> getById(String id) async => null;

  @override
  Future<void> save(PracticeSegment segment) async {}

  @override
  Stream<List<PracticeSegment>> watchBySource(String sourceId) {
    return Stream.value(const []);
  }
}

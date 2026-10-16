import 'package:uuid/uuid.dart';

import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_plan/practice_plan.dart';
import '../../../domain/practice_plan/practice_plan_repository.dart';
import '../../../domain/practice_plan/reminder_time.dart';
import '../../../domain/practice_segment/practice_segment_repository.dart';
import '../../../domain/practice_source/practice_source_repository.dart';

class PracticePlanService {
  PracticePlanService(
    this._repository,
    this._sourceRepository,
    this._segmentRepository, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PracticePlanRepository _repository;
  final PracticeSourceRepository _sourceRepository;
  final PracticeSegmentRepository _segmentRepository;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<PracticePlan> create({
    required String name,
    required String sourceId,
    String? segmentId,
    required PracticeGoal goal,
    required CalendarDate startDate,
    required CalendarDate endDate,
    required Set<int> repeatWeekdays,
    ReminderTime? reminderTime,
  }) async {
    await _validateTarget(sourceId, segmentId);
    _validateInput(name, goal, startDate, endDate, repeatWeekdays);
    final now = _clock().toUtc();
    final plan = PracticePlan(
      id: _uuid.v4(),
      name: name.trim(),
      sourceId: sourceId,
      segmentId: segmentId,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
      repeatWeekdays: repeatWeekdays,
      reminderTime: reminderTime,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.save(plan);
    return plan;
  }

  Future<PracticePlan> update(
    PracticePlan plan, {
    required String name,
    required String sourceId,
    String? segmentId,
    required PracticeGoal goal,
    required CalendarDate startDate,
    required CalendarDate endDate,
    required Set<int> repeatWeekdays,
    ReminderTime? reminderTime,
  }) async {
    await _validateTarget(sourceId, segmentId);
    _validateInput(name, goal, startDate, endDate, repeatWeekdays);
    final updated = plan.copyWith(
      name: name.trim(),
      sourceId: sourceId,
      segmentId: segmentId,
      goal: goal,
      startDate: startDate,
      endDate: endDate,
      repeatWeekdays: repeatWeekdays,
      reminderTime: reminderTime,
      updatedAt: _clock().toUtc(),
    );
    await _repository.save(updated);
    return updated;
  }

  Future<void> delete(PracticePlan plan) => _repository.delete(plan.id);

  void _validateInput(
    String name,
    PracticeGoal goal,
    CalendarDate startDate,
    CalendarDate endDate,
    Set<int> repeatWeekdays,
  ) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('请输入计划名称');
    }
    if (normalizedName.length > 120) {
      throw const FormatException('计划名称不能超过 120 个字符');
    }
    if (endDate < startDate) {
      throw const FormatException('截止日期不能早于开始日期');
    }
    if (repeatWeekdays.isEmpty) {
      throw const FormatException('请至少选择一个练习日');
    }
    switch (goal.type) {
      case PracticeGoalType.loops:
        if ((goal.targetLoops ?? 0) <= 0) {
          throw const FormatException('目标循环次数必须大于 0');
        }
      case PracticeGoalType.duration:
        if ((goal.targetDuration ?? Duration.zero) <= Duration.zero) {
          throw const FormatException('目标练习时长必须大于 0');
        }
    }
  }

  Future<void> _validateTarget(String sourceId, String? segmentId) async {
    final source = await _sourceRepository.getById(sourceId);
    if (source == null) {
      throw const FormatException('所选练习内容不存在');
    }
    if (segmentId == null) return;
    final segment = await _segmentRepository.getById(segmentId);
    if (segment == null || segment.sourceId != sourceId) {
      throw const FormatException('所选片段不属于当前练习内容');
    }
  }
}

import 'dart:collection';

import 'calendar_date.dart';
import 'reminder_time.dart';

enum PracticeGoalType { loops, duration }

class PracticeGoal {
  const PracticeGoal.loops(int loops)
    : type = PracticeGoalType.loops,
      targetLoops = loops,
      targetDuration = null;

  const PracticeGoal.duration(Duration duration)
    : type = PracticeGoalType.duration,
      targetLoops = null,
      targetDuration = duration;

  final PracticeGoalType type;
  final int? targetLoops;
  final Duration? targetDuration;

  int get targetValue => switch (type) {
    PracticeGoalType.loops => targetLoops!,
    PracticeGoalType.duration => targetDuration!.inMilliseconds,
  };
}

class PracticePlan {
  static const Object _unchangedSegmentId = Object();
  static const Object _unchangedReminderTime = Object();

  PracticePlan({
    required this.id,
    required this.name,
    required this.sourceId,
    required this.goal,
    required this.startDate,
    required this.endDate,
    required Set<int> repeatWeekdays,
    required this.createdAt,
    required this.updatedAt,
    this.segmentId,
    this.reminderTime,
  }) : repeatWeekdays = UnmodifiableSetView(Set<int>.of(repeatWeekdays)) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (endDate < startDate) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'must not precede startDate',
      );
    }
    if (repeatWeekdays.isEmpty ||
        repeatWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(
        repeatWeekdays,
        'repeatWeekdays',
        'must contain weekdays from 1 to 7',
      );
    }
    switch (goal.type) {
      case PracticeGoalType.loops:
        if (goal.targetLoops == null || goal.targetLoops! <= 0) {
          throw ArgumentError.value(
            goal.targetLoops,
            'goal',
            'must be positive',
          );
        }
      case PracticeGoalType.duration:
        if (goal.targetDuration == null ||
            goal.targetDuration! <= Duration.zero) {
          throw ArgumentError.value(
            goal.targetDuration,
            'goal',
            'must be positive',
          );
        }
    }
  }

  final String id;
  final String name;
  final String sourceId;
  final String? segmentId;
  final PracticeGoal goal;
  final CalendarDate startDate;
  final CalendarDate endDate;
  final Set<int> repeatWeekdays;
  final ReminderTime? reminderTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isScheduledOn(CalendarDate date) {
    return date >= startDate &&
        date <= endDate &&
        repeatWeekdays.contains(date.weekday);
  }

  PracticePlan copyWith({
    String? name,
    String? sourceId,
    Object? segmentId = _unchangedSegmentId,
    PracticeGoal? goal,
    CalendarDate? startDate,
    CalendarDate? endDate,
    Set<int>? repeatWeekdays,
    Object? reminderTime = _unchangedReminderTime,
    DateTime? updatedAt,
  }) {
    if (!identical(segmentId, _unchangedSegmentId) &&
        segmentId != null &&
        segmentId is! String) {
      throw ArgumentError.value(
        segmentId,
        'segmentId',
        'must be a String or null',
      );
    }
    if (!identical(reminderTime, _unchangedReminderTime) &&
        reminderTime != null &&
        reminderTime is! ReminderTime) {
      throw ArgumentError.value(
        reminderTime,
        'reminderTime',
        'must be a ReminderTime or null',
      );
    }
    return PracticePlan(
      id: id,
      name: name ?? this.name,
      sourceId: sourceId ?? this.sourceId,
      segmentId: identical(segmentId, _unchangedSegmentId)
          ? this.segmentId
          : segmentId as String?,
      goal: goal ?? this.goal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      reminderTime: identical(reminderTime, _unchangedReminderTime)
          ? this.reminderTime
          : reminderTime as ReminderTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

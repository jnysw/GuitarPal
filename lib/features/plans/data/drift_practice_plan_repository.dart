import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_plan/practice_plan.dart' as domain;
import '../../../domain/practice_plan/practice_plan_repository.dart';
import '../../../domain/practice_plan/reminder_time.dart';

class DriftPracticePlanRepository implements PracticePlanRepository {
  const DriftPracticePlanRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<List<domain.PracticePlan>> watchAll() {
    final query = _database.select(_database.practicePlans)
      ..orderBy([
        (row) => OrderingTerm.asc(row.startDay),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Stream<List<domain.PracticePlan>> watchScheduledFor(CalendarDate date) {
    return watchAll().map(
      (plans) => plans
          .where((plan) => plan.isScheduledOn(date))
          .toList(growable: false),
    );
  }

  @override
  Future<domain.PracticePlan?> getById(String id) async {
    final query = _database.select(_database.practicePlans)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.PracticePlan plan) async {
    await _database
        .into(_database.practicePlans)
        .insertOnConflictUpdate(
          db.PracticePlansCompanion(
            id: Value(plan.id),
            name: Value(plan.name),
            sourceId: Value(plan.sourceId),
            segmentId: Value(plan.segmentId),
            goalType: Value(plan.goal.type.name),
            targetLoops: Value(plan.goal.targetLoops),
            targetDurationMilliseconds: Value(
              plan.goal.targetDuration?.inMilliseconds,
            ),
            startDay: Value(plan.startDate.dayKey),
            endDay: Value(plan.endDate.dayKey),
            repeatWeekdayMask: Value(_encodeWeekdays(plan.repeatWeekdays)),
            reminderMinutesSinceMidnight: Value(
              plan.reminderTime?.minutesSinceMidnight,
            ),
            createdAt: Value(plan.createdAt),
            updatedAt: Value(plan.updatedAt),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.practicePlans,
    )..where((row) => row.id.equals(id))).go();
  }

  domain.PracticePlan _toDomain(db.PracticePlan row) {
    final goalType = domain.PracticeGoalType.values.byName(row.goalType);
    final goal = switch (goalType) {
      domain.PracticeGoalType.loops => domain.PracticeGoal.loops(
        row.targetLoops!,
      ),
      domain.PracticeGoalType.duration => domain.PracticeGoal.duration(
        Duration(milliseconds: row.targetDurationMilliseconds!),
      ),
    };
    return domain.PracticePlan(
      id: row.id,
      name: row.name,
      sourceId: row.sourceId,
      segmentId: row.segmentId,
      goal: goal,
      startDate: CalendarDate.fromDayKey(row.startDay),
      endDate: CalendarDate.fromDayKey(row.endDay),
      repeatWeekdays: _decodeWeekdays(row.repeatWeekdayMask),
      reminderTime: row.reminderMinutesSinceMidnight == null
          ? null
          : ReminderTime.fromMinutesSinceMidnight(
              row.reminderMinutesSinceMidnight!,
            ),
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}

int _encodeWeekdays(Set<int> weekdays) {
  return weekdays.fold(0, (mask, day) => mask | (1 << (day - 1)));
}

Set<int> _decodeWeekdays(int mask) {
  return {
    for (var day = 1; day <= 7; day++)
      if ((mask & (1 << (day - 1))) != 0) day,
  };
}

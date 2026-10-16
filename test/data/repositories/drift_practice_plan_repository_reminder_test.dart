import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/reminder_time.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftPracticePlanRepository repository;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftPracticePlanRepository(database);
    final now = DateTime.utc(2026, 10, 14, 8);
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '练习视频',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  test('round-trips, updates, and clears a nullable reminder time', () async {
    final original = _plan(reminderTime: ReminderTime(hour: 20, minute: 34));

    await repository.save(original);

    final insertedRow = await database
        .select(database.practicePlans)
        .getSingle();
    final restored = await repository.getById(original.id);
    expect(insertedRow.reminderMinutesSinceMidnight, 1234);
    expect(restored?.reminderTime, ReminderTime(hour: 20, minute: 34));

    final updated = original.copyWith(
      reminderTime: ReminderTime(hour: 7, minute: 5),
      updatedAt: original.updatedAt.add(const Duration(hours: 1)),
    );
    await repository.save(updated);

    final replaced = await repository.getById(original.id);
    expect(replaced?.reminderTime?.minutesSinceMidnight, 425);

    await repository.save(updated.copyWith(reminderTime: null));

    final clearedRow = await database
        .select(database.practicePlans)
        .getSingle();
    final cleared = await repository.getById(original.id);
    expect(clearedRow.reminderMinutesSinceMidnight, isNull);
    expect(cleared?.reminderTime, isNull);
  });
}

PracticePlan _plan({ReminderTime? reminderTime}) {
  final createdAt = DateTime.utc(2026, 10, 14, 8);
  return PracticePlan(
    id: 'plan-1',
    name: '晚间基本功',
    sourceId: 'source-1',
    goal: const PracticeGoal.loops(10),
    startDate: CalendarDate(2026, 10, 14),
    endDate: CalendarDate(2026, 10, 31),
    repeatWeekdays: const {
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    },
    reminderTime: reminderTime,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

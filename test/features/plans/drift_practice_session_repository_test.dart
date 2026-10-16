import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_session_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftPracticePlanRepository planRepository;
  late DriftPracticeSessionRepository repository;
  late PracticePlan plan;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    planRepository = DriftPracticePlanRepository(database);
    repository = DriftPracticeSessionRepository(database);
    final now = DateTime.utc(2026, 10, 12, 8);
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '本地练习',
        createdAt: now,
        updatedAt: now,
      ),
    );
    plan = PracticePlan(
      id: 'plan-1',
      name: '循环计划',
      sourceId: 'source-1',
      goal: const PracticeGoal.loops(10),
      startDate: CalendarDate(2026, 10, 12),
      endDate: CalendarDate(2026, 10, 31),
      repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
      createdAt: now,
      updatedAt: now,
    );
    await planRepository.save(plan);
  });

  tearDown(() => database.close());

  test(
    'round-trips session progress and optional historical references',
    () async {
      final session = _session(
        id: 'session-1',
        planId: plan.id,
        segmentId: 'segment-that-may-no-longer-exist',
        date: CalendarDate(2026, 10, 13),
        startedAt: DateTime.utc(2026, 10, 13, 9),
        activeDuration: const Duration(minutes: 7, seconds: 12),
        loopCount: 9,
        completed: true,
      );

      await repository.save(session);
      final restored = await repository
          .watchForDate(session.practiceDate)
          .first;

      expect(restored, hasLength(1));
      expect(restored.single.id, session.id);
      expect(restored.single.planId, plan.id);
      expect(restored.single.sourceId, 'source-1');
      expect(restored.single.segmentId, session.segmentId);
      expect(restored.single.practiceDate, CalendarDate(2026, 10, 13));
      expect(restored.single.startedAt, session.startedAt);
      expect(restored.single.endedAt, session.endedAt);
      expect(restored.single.activeDuration, session.activeDuration);
      expect(restored.single.loopCount, 9);
      expect(restored.single.completed, isTrue);
    },
  );

  test('watchBetween is inclusive and returns newest sessions first', () async {
    await repository.save(
      _session(
        id: 'before',
        date: CalendarDate(2026, 10, 11),
        startedAt: DateTime.utc(2026, 10, 11, 12),
      ),
    );
    await repository.save(
      _session(
        id: 'start',
        date: CalendarDate(2026, 10, 12),
        startedAt: DateTime.utc(2026, 10, 12, 8),
      ),
    );
    await repository.save(
      _session(
        id: 'end',
        date: CalendarDate(2026, 10, 18),
        startedAt: DateTime.utc(2026, 10, 18, 9),
      ),
    );
    await repository.save(
      _session(
        id: 'after',
        date: CalendarDate(2026, 10, 19),
        startedAt: DateTime.utc(2026, 10, 19, 10),
      ),
    );

    final sessions = await repository
        .watchBetween(CalendarDate(2026, 10, 12), CalendarDate(2026, 10, 18))
        .first;

    expect(sessions.map((session) => session.id), ['end', 'start']);
  });

  test('watchAll returns the complete history newest first', () async {
    await repository.save(
      _session(
        id: 'older',
        date: CalendarDate(2026, 9, 1),
        startedAt: DateTime.utc(2026, 9, 1, 9),
      ),
    );
    await repository.save(
      _session(
        id: 'newer',
        date: CalendarDate(2026, 10, 14),
        startedAt: DateTime.utc(2026, 10, 14, 9),
      ),
    );

    final sessions = await repository.watchAll().first;

    expect(sessions.map((session) => session.id), ['newer', 'older']);
  });

  test('deleting a plan preserves its sessions and clears planId', () async {
    await repository.save(
      _session(
        id: 'historical-session',
        planId: plan.id,
        date: CalendarDate(2026, 10, 13),
        startedAt: DateTime.utc(2026, 10, 13, 9),
      ),
    );

    await planRepository.delete(plan.id);

    expect(await planRepository.getById(plan.id), isNull);
    final sessions = await repository
        .watchForDate(CalendarDate(2026, 10, 13))
        .first;
    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'historical-session');
    expect(sessions.single.planId, isNull);
    expect(sessions.single.sourceId, 'source-1');
  });
}

PracticeSession _session({
  required String id,
  String? planId,
  String? segmentId,
  required CalendarDate date,
  required DateTime startedAt,
  Duration activeDuration = const Duration(minutes: 1),
  int loopCount = 1,
  bool completed = true,
}) {
  return PracticeSession(
    id: id,
    planId: planId,
    sourceId: 'source-1',
    segmentId: segmentId,
    practiceDate: date,
    startedAt: startedAt,
    endedAt: startedAt.add(activeDuration),
    activeDuration: activeDuration,
    loopCount: loopCount,
    completed: completed,
  );
}

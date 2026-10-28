import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/features/audio_tools/application/stem_practice_tracker.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/stem_practice_target_repository.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/plans/application/practice_playback_session_recorder.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_session_repository.dart';

void main() {
  late db.AppDatabase database;
  late StemPracticeTargetRepository targets;
  final day = DateTime(2026, 10, 28, 12);
  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    targets = StemPracticeTargetRepository(database);
    await database
        .into(database.practiceSources)
        .insert(
          db.PracticeSourcesCompanion.insert(
            id: 'source',
            platform: 'local',
            kind: 'video',
            title: '练习曲',
            createdAt: day,
            updatedAt: day,
          ),
        );
    await AlgorithmTaskRepository(database).insert(
      AlgorithmTaskRecord(
        id: 'task',
        endpoint: 'https://algorithm.example',
        inputPath: '/test.wav',
        inputName: 'test.wav',
        inputSizeBytes: 1000,
        inputDurationMs: 8000,
        ownsInput: false,
        state: AlgorithmTaskState.completed,
        createdAt: day,
        updatedAt: day,
        failures: 0,
      ),
    );
  });
  tearDown(() => database.close());

  test('six stems use one stable session; speed/seeks/reset do not multiply wall time or loops', () async {
    await targets.link('task', sourceId: 'source');
    final repository = DriftPracticeSessionRepository(database);
    var now = day;
    final tracker = StemPracticeTracker(
      PracticePlaybackSessionRecorder(
        repository,
        sourceId: 'source',
        clock: () => now,
      ),
      initialNativeLoops: 8,
    );
    tracker.observe(
      playing: true,
      nativeLoops: 8,
    ); // loops heard before linking are not credited.
    now = now.add(const Duration(seconds: 3));
    tracker.observe(playing: true, nativeLoops: 10);
    await tracker.checkpoint();
    tracker.resetNativeCounter();
    now = now.add(
      const Duration(seconds: 20),
    ); // loading another mode is not playing.
    tracker.observe(playing: true, nativeLoops: 0);
    now = now.add(const Duration(seconds: 2));
    tracker.observe(playing: false, nativeLoops: 1);
    await tracker.checkpoint();
    tracker.suspend();
    now = now.add(const Duration(minutes: 2));
    tracker.observe(
      playing: true,
      nativeLoops: 6,
    ); // stale/inactive snapshots cannot restart timing.
    tracker.resume();
    tracker.observe(playing: false, nativeLoops: 6);
    tracker.suspend();
    now = now.add(const Duration(minutes: 1));
    tracker.resume();
    tracker.observe(playing: false, nativeLoops: 9);
    await tracker.finish();
    await tracker.finish();
    final rows = await database.select(database.practiceSessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.activeDurationMilliseconds, 5000);
    expect(rows.single.loopCount, 3);
    expect(rows.single.completed, isTrue);
    final outbox = await (database.select(database.syncOutboxEntries)).get();
    expect(
      outbox.where((e) => e.entityType == 'practiceSession'),
      hasLength(1),
    );
    final today = await repository
        .watchForDate(CalendarDate.fromDateTime(day))
        .first;
    expect(today.single.hasPracticeActivity, isTrue);
    await targets.link('task');
    await AlgorithmTaskRepository(database).delete('task');
    expect(
      await database.select(database.practiceSessions).get(),
      hasLength(1),
    );
  });

  test('links reject missing sources, mismatched plans, segment plans and deleted tasks', () async {
    await database
        .into(database.practiceSources)
        .insert(
          db.PracticeSourcesCompanion.insert(
            id: 'other',
            platform: 'local',
            kind: 'video',
            title: '其他曲目',
            createdAt: day,
            updatedAt: day,
          ),
        );
    await database
        .into(database.practiceSegments)
        .insert(
          db.PracticeSegmentsCompanion.insert(
            id: 'segment',
            sourceId: 'source',
            title: '片段',
            startMilliseconds: 0,
            endMilliseconds: 1000,
            createdAt: day,
            updatedAt: day,
          ),
        );
    for (final entry in [
      ('whole', 'source', null),
      ('wrong', 'other', null),
      ('fragment', 'source', 'segment'),
    ]) {
      await database
          .into(database.practicePlans)
          .insert(
            db.PracticePlansCompanion.insert(
              id: entry.$1,
              name: entry.$1,
              sourceId: entry.$2,
              segmentId: drift.Value(entry.$3),
              goalType: 'duration',
              targetDurationMilliseconds: const drift.Value(5000),
              startDay: 20261028,
              endDay: 20261030,
              repeatWeekdayMask: 127,
              createdAt: day,
              updatedAt: day,
            ),
          );
    }
    await expectLater(
      targets.link('task', sourceId: 'source', planId: 'wrong'),
      throwsFormatException,
    );
    await expectLater(
      targets.link('task', sourceId: 'source', planId: 'fragment'),
      throwsFormatException,
    );
    await targets.link('task', sourceId: 'source', planId: 'whole');
    expect((await targets.load('task'))!.planId, 'whole');
    await (database.delete(
      database.practicePlans,
    )..where((p) => p.id.equals('whole'))).go();
    expect((await targets.load('task'))!.planId, isNull);
    await expectLater(
      targets.link('task', sourceId: 'missing'),
      throwsFormatException,
    );
    await expectLater(
      targets.link('task', planId: 'missing'),
      throwsFormatException,
    );
    await expectLater(
      targets.link('task', sourceId: 'source', planId: 'missing'),
      throwsFormatException,
    );
    await targets.link('task', sourceId: 'source');
    expect((await targets.load('task'))!.sourceTitle, '练习曲');
    await database.delete(database.practiceSources).go();
    expect(await targets.load('task'), isNull);
    final task = (await AlgorithmTaskRepository(database).get('task'))!;
    expect(task.linkedSourceId, isNull);
    await AlgorithmTaskRepository(database).delete('task');
    await expectLater(targets.link('task'), throwsFormatException);
  });

  test('v11 migration adds nullable targets while preserving tasks, cached results and old practice', () async {
    final directory = await Directory.systemTemp.createTemp('gp_v11_stats_');
    final file = File('${directory.path}/db.sqlite');
    final original = db.AppDatabase(NativeDatabase(file));
    await original.customStatement(
      "INSERT INTO algorithm_tasks (id,endpoint,input_path,input_name,input_size_bytes,input_duration_ms,status,created_at,updated_at,result_json) VALUES ('cached','https://algorithm.example','/input.wav','input.wav',100,8000,'completed',1,1,'{\"retained\":true}')",
    );
    await DriftPracticeSessionRepository(original).save(
      PracticeSession(
        id: 'old',
        sourceId: 'historical',
        practiceDate: CalendarDate.fromDateTime(day),
        startedAt: day.toUtc(),
        activeDuration: const Duration(seconds: 5),
        loopCount: 1,
        completed: true,
      ),
    );
    await original.close();
    final migrated = db.AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'ALTER TABLE algorithm_tasks DROP COLUMN linked_source_id',
          );
          raw.execute('ALTER TABLE algorithm_tasks DROP COLUMN linked_plan_id');
          raw.execute('PRAGMA user_version = 11');
        },
      ),
    );
    try {
      final task = (await AlgorithmTaskRepository(migrated).get('cached'))!;
      expect(task.resultJson, '{"retained":true}');
      expect(task.linkedSourceId, isNull);
      expect(task.linkedPlanId, isNull);
      expect(
        (await migrated.select(migrated.practiceSessions).get()).single.id,
        'old',
      );
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });
}

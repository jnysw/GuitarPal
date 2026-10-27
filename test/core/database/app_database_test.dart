import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('schema version includes persisted algorithm tasks', () {
    expect(database.schemaVersion, 10);
  });

  test('practice source can be stored in the initial schema', () async {
    final now = DateTime.utc(2026, 9, 27);

    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source-1',
            platform: 'bilibili',
            kind: 'webReference',
            originalUrl: const Value('https://www.bilibili.com/video/BV1test'),
            title: 'Solo lesson',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final stored = await database.select(database.practiceSources).getSingle();

    expect(stored.id, 'source-1');
    expect(stored.platform, 'bilibili');
    expect(stored.syncStatus, 'local');
    expect(stored.note, equals(null));
  });

  test('practice segments belong to a source and cascade on delete', () async {
    final now = DateTime.utc(2026, 10, 12);
    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source-with-segment',
            platform: 'bilibili',
            kind: 'webReference',
            title: 'Blues Solo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practiceSegments)
        .insert(
          PracticeSegmentsCompanion.insert(
            id: 'segment-1',
            sourceId: 'source-with-segment',
            title: '第一句',
            startMilliseconds: 2000,
            endMilliseconds: 6500,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final stored = await database.select(database.practiceSegments).getSingle();
    expect(stored.startMilliseconds, 2000);
    expect(stored.endMilliseconds, 6500);
    expect(stored.note, equals(null));
    expect(stored.preferredSpeed, 1.0);

    await (database.delete(
      database.practiceSources,
    )..where((row) => row.id.equals('source-with-segment'))).go();
    expect(await database.select(database.practiceSegments).get(), isEmpty);
  });

  test('deleting a segment keeps its plan and clears segmentId', () async {
    final now = DateTime.utc(2026, 10, 13, 8);
    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source-with-plan',
            platform: 'local',
            kind: 'video',
            title: '节奏练习',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practiceSegments)
        .insert(
          PracticeSegmentsCompanion.insert(
            id: 'segment-with-plan',
            sourceId: 'source-with-plan',
            title: '主歌',
            startMilliseconds: 1000,
            endMilliseconds: 5000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practicePlans)
        .insert(
          PracticePlansCompanion.insert(
            id: 'plan-with-segment',
            name: '主歌循环',
            sourceId: 'source-with-plan',
            segmentId: const Value('segment-with-plan'),
            goalType: 'loops',
            targetLoops: const Value(10),
            startDay: 20261013,
            endDay: 20261031,
            repeatWeekdayMask: 0x7f,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (database.delete(
      database.practiceSegments,
    )..where((row) => row.id.equals('segment-with-plan'))).go();

    final plan = await database.select(database.practicePlans).getSingle();
    expect(plan.id, 'plan-with-segment');
    expect(plan.segmentId, equals(null));
  });

  test('deleting media preserves session history and clears planId', () async {
    final now = DateTime.utc(2026, 10, 13, 8);
    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'historical-source',
            platform: 'local',
            kind: 'video',
            title: '历史练习',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practicePlans)
        .insert(
          PracticePlansCompanion.insert(
            id: 'historical-plan',
            name: '历史计划',
            sourceId: 'historical-source',
            goalType: 'duration',
            targetDurationMilliseconds: const Value(600000),
            startDay: 20261013,
            endDay: 20261031,
            repeatWeekdayMask: 0x7f,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practiceSessions)
        .insert(
          PracticeSessionsCompanion.insert(
            id: 'historical-session',
            planId: const Value('historical-plan'),
            sourceId: 'historical-source',
            segmentId: const Value('deleted-segment-id'),
            practiceDay: 20261013,
            startedAt: now,
            endedAt: Value(now.add(const Duration(minutes: 8))),
            activeDurationMilliseconds: const Value(480000),
            loopCount: const Value(4),
            completed: const Value(true),
          ),
        );

    await (database.delete(
      database.practiceSources,
    )..where((row) => row.id.equals('historical-source'))).go();

    expect(await database.select(database.practicePlans).get(), isEmpty);
    final session = await database
        .select(database.practiceSessions)
        .getSingle();
    expect(session.id, 'historical-session');
    expect(session.planId, equals(null));
    expect(session.sourceId, 'historical-source');
    expect(session.segmentId, 'deleted-segment-id');
    expect(session.activeDurationMilliseconds, 480000);
    expect(session.completed, isTrue);
  });

  test('practice recording keeps historical snapshots', () async {
    final now = DateTime.utc(2026, 10, 14, 12);
    await database
        .into(database.practiceRecordings)
        .insert(
          PracticeRecordingsCompanion.insert(
            id: 'take-1',
            sourceId: 'historical-source',
            segmentId: const Value('historical-segment'),
            kind: 'segmentTake',
            filePath: 'practice_recordings/take-1.m4a',
            durationMilliseconds: 12500,
            referenceStartMilliseconds: 32000,
            referenceEndMilliseconds: const Value(44500),
            referenceSpeed: const Value(0.83),
            title: '主歌第 3 次',
            note: const Value('换弦更稳了'),
            recordedAt: now,
          ),
        );

    final stored = await database
        .select(database.practiceRecordings)
        .getSingle();
    expect(stored.sourceId, 'historical-source');
    expect(stored.segmentId, 'historical-segment');
    expect(stored.durationMilliseconds, 12500);
    expect(stored.referenceStartMilliseconds, 32000);
    expect(stored.referenceEndMilliseconds, 44500);
    expect(stored.referenceSpeed, 0.83);
  });
}

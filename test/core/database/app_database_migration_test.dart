import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';

void main() {
  test('migrates version 7 by creating practice recordings', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'guitar_pal_schema_v7_',
    );
    final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
    final migratedDatabase = AppDatabase(
      NativeDatabase(
        databaseFile,
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA user_version = 7');
        },
      ),
    );

    try {
      expect(
        await migratedDatabase
            .select(migratedDatabase.practiceRecordings)
            .get(),
        isEmpty,
      );
      final now = DateTime.utc(2026, 10, 14, 13);
      await migratedDatabase
          .into(migratedDatabase.practiceRecordings)
          .insert(
            PracticeRecordingsCompanion.insert(
              id: 'migrated-take',
              sourceId: 'legacy-source',
              kind: 'segmentTake',
              filePath: 'practice_recordings/migrated-take.m4a',
              durationMilliseconds: 4000,
              referenceStartMilliseconds: 12000,
              title: '迁移后录音',
              recordedAt: now,
            ),
          );
      expect(
        (await migratedDatabase
                .select(migratedDatabase.practiceRecordings)
                .getSingle())
            .id,
        'migrated-take',
      );
    } finally {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'migrates version 2 segments with safe note and speed defaults',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'guitar_pal_schema_v2_',
      );
      final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
      final migratedDatabase = AppDatabase(
        NativeDatabase(
          databaseFile,
          setup: (rawDatabase) {
            rawDatabase.execute('''
              CREATE TABLE practice_sources (
                id TEXT NOT NULL PRIMARY KEY,
                platform TEXT NOT NULL,
                kind TEXT NOT NULL,
                original_url TEXT NULL,
                canonical_url TEXT NULL,
                external_id TEXT NULL,
                title TEXT NOT NULL,
                thumbnail_url TEXT NULL,
                duration_milliseconds INTEGER NULL,
                sync_status TEXT NOT NULL DEFAULT 'local',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            rawDatabase.execute('''
              CREATE TABLE practice_segments (
                id TEXT NOT NULL PRIMARY KEY,
                source_id TEXT NOT NULL,
                title TEXT NOT NULL,
                start_milliseconds INTEGER NOT NULL,
                end_milliseconds INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
            rawDatabase.execute(
              '''
                INSERT INTO practice_segments (
                  id,
                  source_id,
                  title,
                  start_milliseconds,
                  end_milliseconds,
                  created_at,
                  updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
              ''',
              [
                'legacy-segment',
                'legacy-source',
                '旧片段',
                1000,
                3000,
                DateTime.utc(2026, 10, 12).millisecondsSinceEpoch ~/ 1000,
                DateTime.utc(2026, 10, 12).millisecondsSinceEpoch ~/ 1000,
              ],
            );
            rawDatabase.execute('PRAGMA user_version = 2');
          },
        ),
      );

      try {
        final stored = await migratedDatabase
            .select(migratedDatabase.practiceSegments)
            .getSingle();
        expect(stored.id, 'legacy-segment');
        expect(stored.note, equals(null));
        expect(stored.preferredSpeed, 1.0);
      } finally {
        await migratedDatabase.close();
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  test('migrates version 3 data and creates plan and session tables', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'guitar_pal_schema_v3_',
    );
    final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
    final timestamp =
        DateTime.utc(2026, 10, 12, 8).millisecondsSinceEpoch ~/ 1000;
    final migratedDatabase = AppDatabase(
      NativeDatabase(
        databaseFile,
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA foreign_keys = ON');
          rawDatabase.execute('''
            CREATE TABLE practice_sources (
              id TEXT NOT NULL PRIMARY KEY,
              platform TEXT NOT NULL,
              kind TEXT NOT NULL,
              original_url TEXT NULL,
              canonical_url TEXT NULL,
              external_id TEXT NULL,
              title TEXT NOT NULL,
              thumbnail_url TEXT NULL,
              duration_milliseconds INTEGER NULL,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute('''
            CREATE TABLE practice_segments (
              id TEXT NOT NULL PRIMARY KEY,
              source_id TEXT NOT NULL REFERENCES practice_sources(id)
                ON DELETE CASCADE,
              title TEXT NOT NULL,
              start_milliseconds INTEGER NOT NULL,
              end_milliseconds INTEGER NOT NULL,
              note TEXT NULL,
              preferred_speed REAL NOT NULL DEFAULT 1.0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute(
            '''
              INSERT INTO practice_sources (
                id, platform, kind, title, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              'legacy-source',
              'bilibili',
              'webReference',
              '旧练习来源',
              timestamp,
              timestamp,
            ],
          );
          rawDatabase.execute(
            '''
              INSERT INTO practice_segments (
                id,
                source_id,
                title,
                start_milliseconds,
                end_milliseconds,
                note,
                preferred_speed,
                created_at,
                updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              'legacy-segment',
              'legacy-source',
              '旧片段',
              1000,
              3000,
              '保留这条笔记',
              0.75,
              timestamp,
              timestamp,
            ],
          );
          rawDatabase.execute('PRAGMA user_version = 3');
        },
      ),
    );

    try {
      final source = await migratedDatabase
          .select(migratedDatabase.practiceSources)
          .getSingle();
      final segment = await migratedDatabase
          .select(migratedDatabase.practiceSegments)
          .getSingle();
      expect(source.id, 'legacy-source');
      expect(source.title, '旧练习来源');
      expect(segment.id, 'legacy-segment');
      expect(segment.note, '保留这条笔记');
      expect(segment.preferredSpeed, 0.75);
      expect(
        await migratedDatabase.select(migratedDatabase.practicePlans).get(),
        isEmpty,
      );
      expect(
        await migratedDatabase.select(migratedDatabase.practiceSessions).get(),
        isEmpty,
      );

      final now = DateTime.utc(2026, 10, 13, 8);
      await migratedDatabase
          .into(migratedDatabase.practicePlans)
          .insert(
            PracticePlansCompanion.insert(
              id: 'migrated-plan',
              name: '迁移后的计划',
              sourceId: 'legacy-source',
              segmentId: const Value('legacy-segment'),
              goalType: 'loops',
              targetLoops: const Value(8),
              startDay: 20261013,
              endDay: 20261031,
              repeatWeekdayMask: 0x7f,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await migratedDatabase
          .into(migratedDatabase.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'migrated-session',
              planId: const Value('migrated-plan'),
              sourceId: 'legacy-source',
              segmentId: const Value('legacy-segment'),
              practiceDay: 20261013,
              startedAt: now,
            ),
          );

      await (migratedDatabase.delete(
        migratedDatabase.practicePlans,
      )..where((row) => row.id.equals('migrated-plan'))).go();
      final session = await migratedDatabase
          .select(migratedDatabase.practiceSessions)
          .getSingle();
      expect(session.planId, equals(null));
      expect(session.sourceId, 'legacy-source');
    } finally {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    }
  });

  test('migrates version 4 plans with a disabled reminder default', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'guitar_pal_schema_v4_',
    );
    final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
    final timestamp =
        DateTime.utc(2026, 10, 14, 8).millisecondsSinceEpoch ~/ 1000;
    final migratedDatabase = AppDatabase(
      NativeDatabase(
        databaseFile,
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA foreign_keys = ON');
          rawDatabase.execute('''
            CREATE TABLE practice_sources (
              id TEXT NOT NULL PRIMARY KEY,
              platform TEXT NOT NULL,
              kind TEXT NOT NULL,
              original_url TEXT NULL,
              canonical_url TEXT NULL,
              external_id TEXT NULL,
              title TEXT NOT NULL,
              thumbnail_url TEXT NULL,
              duration_milliseconds INTEGER NULL,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute('''
            CREATE TABLE practice_segments (
              id TEXT NOT NULL PRIMARY KEY,
              source_id TEXT NOT NULL REFERENCES practice_sources(id)
                ON DELETE CASCADE,
              title TEXT NOT NULL,
              start_milliseconds INTEGER NOT NULL,
              end_milliseconds INTEGER NOT NULL,
              note TEXT NULL,
              preferred_speed REAL NOT NULL DEFAULT 1.0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute('''
            CREATE TABLE practice_plans (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              source_id TEXT NOT NULL REFERENCES practice_sources(id)
                ON DELETE CASCADE,
              segment_id TEXT NULL REFERENCES practice_segments(id)
                ON DELETE SET NULL,
              goal_type TEXT NOT NULL,
              target_loops INTEGER NULL,
              target_duration_milliseconds INTEGER NULL,
              start_day INTEGER NOT NULL,
              end_day INTEGER NOT NULL,
              repeat_weekday_mask INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute('''
            CREATE TABLE practice_sessions (
              id TEXT NOT NULL PRIMARY KEY,
              plan_id TEXT NULL REFERENCES practice_plans(id)
                ON DELETE SET NULL,
              source_id TEXT NOT NULL,
              segment_id TEXT NULL,
              practice_day INTEGER NOT NULL,
              started_at INTEGER NOT NULL,
              ended_at INTEGER NULL,
              active_duration_milliseconds INTEGER NOT NULL DEFAULT 0,
              loop_count INTEGER NOT NULL DEFAULT 0,
              completed INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDatabase.execute(
            '''
              INSERT INTO practice_sources (
                id, platform, kind, title, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            ['legacy-source', 'local', 'video', '旧练习视频', timestamp, timestamp],
          );
          rawDatabase.execute(
            '''
              INSERT INTO practice_plans (
                id,
                name,
                source_id,
                goal_type,
                target_loops,
                start_day,
                end_day,
                repeat_weekday_mask,
                created_at,
                updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              'legacy-plan',
              '旧版计划',
              'legacy-source',
              'loops',
              12,
              20261014,
              20261031,
              0x7f,
              timestamp,
              timestamp,
            ],
          );
          rawDatabase.execute('PRAGMA user_version = 4');
        },
      ),
    );

    try {
      final migrated = await migratedDatabase
          .select(migratedDatabase.practicePlans)
          .getSingle();
      expect(migrated.id, 'legacy-plan');
      expect(migrated.name, '旧版计划');
      expect(migrated.targetLoops, 12);
      expect(migrated.reminderMinutesSinceMidnight, null);

      await (migratedDatabase.update(
        migratedDatabase.practicePlans,
      )..where((row) => row.id.equals('legacy-plan'))).write(
        const PracticePlansCompanion(
          reminderMinutesSinceMidnight: Value(20 * 60 + 15),
        ),
      );

      final updated = await migratedDatabase
          .select(migratedDatabase.practicePlans)
          .getSingle();
      expect(updated.reminderMinutesSinceMidnight, 1215);
    } finally {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'migrates version 5 sources with a pending completion default',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'guitar_pal_schema_v5_',
      );
      final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
      final timestamp =
          DateTime.utc(2026, 10, 14, 9).millisecondsSinceEpoch ~/ 1000;
      final migratedDatabase = AppDatabase(
        NativeDatabase(
          databaseFile,
          setup: (rawDatabase) {
            rawDatabase.execute('''
            CREATE TABLE practice_sources (
              id TEXT NOT NULL PRIMARY KEY,
              platform TEXT NOT NULL,
              kind TEXT NOT NULL,
              original_url TEXT NULL,
              canonical_url TEXT NULL,
              external_id TEXT NULL,
              title TEXT NOT NULL,
              thumbnail_url TEXT NULL,
              duration_milliseconds INTEGER NULL,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
            rawDatabase.execute(
              '''
              INSERT INTO practice_sources (
                id, platform, kind, title, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
              [
                'legacy-source-v5',
                'bilibili',
                'webReference',
                '第五版来源',
                timestamp,
                timestamp,
              ],
            );
            rawDatabase.execute('PRAGMA user_version = 5');
          },
        ),
      );

      try {
        final migrated = await migratedDatabase
            .select(migratedDatabase.practiceSources)
            .getSingle();
        expect(migrated.title, '第五版来源');
        expect(migrated.completedAt, null);

        final completedAt = DateTime.utc(2026, 10, 14, 10);
        await (migratedDatabase.update(migratedDatabase.practiceSources)
              ..where((row) => row.id.equals('legacy-source-v5')))
            .write(PracticeSourcesCompanion(completedAt: Value(completedAt)));

        final updated = await migratedDatabase
            .select(migratedDatabase.practiceSources)
            .getSingle();
        expect(updated.completedAt?.toUtc(), completedAt);
      } finally {
        await migratedDatabase.close();
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  test('migrates version 6 sources with an empty overall note', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'guitar_pal_schema_v6_',
    );
    final databaseFile = File('${tempDirectory.path}/guitar_pal.sqlite');
    final timestamp =
        DateTime.utc(2026, 10, 14, 11).millisecondsSinceEpoch ~/ 1000;
    final migratedDatabase = AppDatabase(
      NativeDatabase(
        databaseFile,
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE practice_sources (
              id TEXT NOT NULL PRIMARY KEY,
              platform TEXT NOT NULL,
              kind TEXT NOT NULL,
              original_url TEXT NULL,
              canonical_url TEXT NULL,
              external_id TEXT NULL,
              title TEXT NOT NULL,
              thumbnail_url TEXT NULL,
              duration_milliseconds INTEGER NULL,
              sync_status TEXT NOT NULL DEFAULT 'local',
              completed_at INTEGER NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute(
            '''
              INSERT INTO practice_sources (
                id, platform, kind, title, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?)
            ''',
            [
              'legacy-source-v6',
              'local',
              'video',
              '第六版来源',
              timestamp,
              timestamp,
            ],
          );
          rawDatabase.execute('PRAGMA user_version = 6');
        },
      ),
    );

    try {
      final migrated = await migratedDatabase
          .select(migratedDatabase.practiceSources)
          .getSingle();
      expect(migrated.title, '第六版来源');
      expect(migrated.note, equals(null));

      await (migratedDatabase.update(migratedDatabase.practiceSources)
            ..where((row) => row.id.equals('legacy-source-v6')))
          .write(const PracticeSourcesCompanion(note: Value('迁移后可写入')));
      expect(
        (await migratedDatabase
                .select(migratedDatabase.practiceSources)
                .getSingle())
            .note,
        '迁移后可写入',
      );
    } finally {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    }
  });
}

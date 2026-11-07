import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/sync/drift_sync_outbox_repository.dart';
import 'package:guitar_pal/core/sync/sync_outbox.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_session_repository.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftSyncOutboxRepository repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftSyncOutboxRepository(database);
  });

  tearDown(() => database.close());

  test(
    'coalesces mutations and protects a newer revision from stale acks',
    () async {
      final firstTime = DateTime.utc(2026, 10, 27, 8);
      await repository.enqueue(
        entityType: SyncEntityType.practiceSource,
        entityId: 'source-1',
        operation: SyncOperation.upsert,
        changedAt: firstTime,
      );
      final first = (await repository.getPending()).single;
      expect(first.revision, 1);

      await repository.enqueue(
        entityType: SyncEntityType.practiceSource,
        entityId: 'source-1',
        operation: SyncOperation.delete,
        changedAt: firstTime.add(const Duration(minutes: 1)),
      );
      final second = (await repository.getPending()).single;
      expect(second.operation, SyncOperation.delete);
      expect(second.revision, 2);
      expect(await repository.acknowledge(first), isFalse);

      expect(
        await repository.markFailed(second, 'network unavailable'),
        isTrue,
      );
      final failed = (await repository.getPending()).single;
      expect(failed.attemptCount, 1);
      expect(failed.lastError, 'network unavailable');
      expect((await repository.watchSummary().first).failedCount, 1);

      await repository.enqueue(
        entityType: SyncEntityType.practiceSource,
        entityId: 'source-1',
        operation: SyncOperation.upsert,
        changedAt: firstTime.add(const Duration(minutes: 2)),
      );
      final third = (await repository.getPending()).single;
      expect(third.revision, 3);
      expect(third.attemptCount, 0);
      expect(third.lastError, isNull);
      expect(await repository.acknowledge(failed), isFalse);
      expect(await repository.acknowledge(third), isTrue);
      expect((await repository.getPending()), isEmpty);
    },
  );

  test(
    'queues metadata changes and coalesces a source cascade safely',
    () async {
      final now = DateTime.utc(2026, 10, 27, 9);
      final deleteTime = now.add(const Duration(hours: 1));
      final sourceRepository = DriftPracticeSourceRepository(
        database,
        clock: () => deleteTime,
      );
      final segmentRepository = DriftPracticeSegmentRepository(database);
      final planRepository = DriftPracticePlanRepository(database);
      final sessionRepository = DriftPracticeSessionRepository(database);

      await sourceRepository.save(
        PracticeSource(
          id: 'source-1',
          platform: SourcePlatform.local,
          kind: SourceKind.video,
          title: '同步测试',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await segmentRepository.save(
        PracticeSegment(
          id: 'segment-1',
          sourceId: 'source-1',
          title: '第一段',
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 4),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await planRepository.save(
        PracticePlan(
          id: 'plan-1',
          name: '同步计划',
          sourceId: 'source-1',
          segmentId: 'segment-1',
          goal: const PracticeGoal.loops(8),
          startDate: CalendarDate(2026, 10, 27),
          endDate: CalendarDate(2026, 11, 27),
          repeatWeekdays: const {DateTime.tuesday},
          createdAt: now,
          updatedAt: now,
        ),
      );
      await sessionRepository.save(
        PracticeSession(
          id: 'session-1',
          planId: 'plan-1',
          sourceId: 'source-1',
          segmentId: 'segment-1',
          practiceDate: CalendarDate(2026, 10, 27),
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 2)),
          activeDuration: const Duration(minutes: 2),
          loopCount: 8,
          completed: true,
        ),
      );

      expect((await repository.getPending()), hasLength(4));
      await sourceRepository.delete('source-1');

      final changes = {
        for (final change in await repository.getPending())
          change.entityType: change,
      };
      expect(changes, hasLength(4));
      expect(
        changes[SyncEntityType.practiceSource]?.operation,
        SyncOperation.delete,
      );
      expect(
        changes[SyncEntityType.practiceSegment]?.operation,
        SyncOperation.delete,
      );
      expect(
        changes[SyncEntityType.practicePlan]?.operation,
        SyncOperation.delete,
      );
      expect(
        changes[SyncEntityType.practiceSession]?.operation,
        SyncOperation.upsert,
      );
      expect(changes.values.every((change) => change.revision == 2), isTrue);
      expect(
        (await database.select(database.practiceSessions).getSingle()).planId,
        isNull,
      );
    },
  );
}

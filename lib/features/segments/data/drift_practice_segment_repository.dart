import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/sync/drift_sync_outbox_repository.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../domain/practice_segment/practice_segment.dart' as domain;
import '../../../domain/practice_segment/practice_segment_repository.dart';

class DriftPracticeSegmentRepository implements PracticeSegmentRepository {
  DriftPracticeSegmentRepository(this._database, {DateTime Function()? clock})
    : _syncOutbox = DriftSyncOutboxRepository(_database),
      _clock = clock ?? DateTime.now;

  final db.AppDatabase _database;
  final DriftSyncOutboxRepository _syncOutbox;
  final DateTime Function() _clock;

  @override
  Stream<List<domain.PracticeSegment>> watchAll() {
    final query = _database.select(_database.practiceSegments)
      ..orderBy([
        (row) => OrderingTerm.asc(row.sourceId),
        (row) => OrderingTerm.asc(row.startMilliseconds),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Stream<List<domain.PracticeSegment>> watchBySource(String sourceId) {
    final query = _database.select(_database.practiceSegments)
      ..where((row) => row.sourceId.equals(sourceId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.startMilliseconds),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<domain.PracticeSegment?> getById(String id) async {
    final query = _database.select(_database.practiceSegments)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.PracticeSegment segment) async {
    await _database.transaction(() async {
      await _database
          .into(_database.practiceSegments)
          .insertOnConflictUpdate(
            db.PracticeSegmentsCompanion(
              id: Value(segment.id),
              sourceId: Value(segment.sourceId),
              title: Value(segment.title),
              startMilliseconds: Value(segment.start.inMilliseconds),
              endMilliseconds: Value(segment.end.inMilliseconds),
              note: Value(segment.note),
              preferredSpeed: Value(segment.preferredSpeed),
              createdAt: Value(segment.createdAt),
              updatedAt: Value(segment.updatedAt),
            ),
          );
      await _syncOutbox.enqueue(
        entityType: SyncEntityType.practiceSegment,
        entityId: segment.id,
        operation: SyncOperation.upsert,
        changedAt: segment.updatedAt,
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      final affectedPlanIds =
          await (_database.selectOnly(_database.practicePlans)
                ..addColumns([_database.practicePlans.id])
                ..where(_database.practicePlans.segmentId.equals(id)))
              .map((row) => row.read(_database.practicePlans.id)!)
              .get();
      final deleted = await (_database.delete(
        _database.practiceSegments,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) return;

      final changedAt = _clock().toUtc();
      if (affectedPlanIds.isNotEmpty) {
        await (_database.update(_database.practicePlans)
              ..where((row) => row.id.isIn(affectedPlanIds)))
            .write(db.PracticePlansCompanion(updatedAt: Value(changedAt)));
      }
      await _syncOutbox.enqueue(
        entityType: SyncEntityType.practiceSegment,
        entityId: id,
        operation: SyncOperation.delete,
        changedAt: changedAt,
      );
      for (final planId in affectedPlanIds) {
        await _syncOutbox.enqueue(
          entityType: SyncEntityType.practicePlan,
          entityId: planId,
          operation: SyncOperation.upsert,
          changedAt: changedAt,
        );
      }
    });
  }

  domain.PracticeSegment _toDomain(db.PracticeSegment row) {
    return domain.PracticeSegment(
      id: row.id,
      sourceId: row.sourceId,
      title: row.title,
      start: Duration(milliseconds: row.startMilliseconds),
      end: Duration(milliseconds: row.endMilliseconds),
      note: row.note,
      preferredSpeed: row.preferredSpeed,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}

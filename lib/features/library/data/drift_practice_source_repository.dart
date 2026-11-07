import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/sync/drift_sync_outbox_repository.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../domain/practice_source/practice_source.dart' as domain;
import '../../../domain/practice_source/practice_source_repository.dart';

class DriftPracticeSourceRepository implements PracticeSourceRepository {
  DriftPracticeSourceRepository(this._database, {DateTime Function()? clock})
    : _syncOutbox = DriftSyncOutboxRepository(_database),
      _clock = clock ?? DateTime.now;

  final db.AppDatabase _database;
  final DriftSyncOutboxRepository _syncOutbox;
  final DateTime Function() _clock;

  @override
  Stream<List<domain.PracticeSource>> watchAll() {
    final query = _database.select(_database.practiceSources)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<domain.PracticeSource?> getById(String id) async {
    final query = _database.select(_database.practiceSources)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.PracticeSource source) async {
    await _database.transaction(() async {
      await _database
          .into(_database.practiceSources)
          .insertOnConflictUpdate(
            db.PracticeSourcesCompanion(
              id: Value(source.id),
              platform: Value(source.platform.name),
              kind: Value(source.kind.name),
              originalUrl: Value(source.originalUri?.toString()),
              canonicalUrl: Value(source.canonicalUri?.toString()),
              externalId: Value(source.externalId),
              title: Value(source.title),
              thumbnailUrl: Value(source.thumbnailUri?.toString()),
              durationMilliseconds: Value(source.duration?.inMilliseconds),
              note: Value(source.note),
              completedAt: Value(source.completedAt),
              createdAt: Value(source.createdAt),
              updatedAt: Value(source.updatedAt),
            ),
          );
      await _syncOutbox.enqueue(
        entityType: SyncEntityType.practiceSource,
        entityId: source.id,
        operation: SyncOperation.upsert,
        changedAt: source.updatedAt,
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      final segmentIds =
          await (_database.selectOnly(_database.practiceSegments)
                ..addColumns([_database.practiceSegments.id])
                ..where(_database.practiceSegments.sourceId.equals(id)))
              .map((row) => row.read(_database.practiceSegments.id)!)
              .get();
      final planIds =
          await (_database.selectOnly(_database.practicePlans)
                ..addColumns([_database.practicePlans.id])
                ..where(_database.practicePlans.sourceId.equals(id)))
              .map((row) => row.read(_database.practicePlans.id)!)
              .get();
      final sessionIds = planIds.isEmpty
          ? const <String>[]
          : await (_database.selectOnly(_database.practiceSessions)
                  ..addColumns([_database.practiceSessions.id])
                  ..where(_database.practiceSessions.planId.isIn(planIds)))
                .map((row) => row.read(_database.practiceSessions.id)!)
                .get();
      final deleted = await (_database.delete(
        _database.practiceSources,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) return;

      final changedAt = _clock().toUtc();
      await _syncOutbox.enqueue(
        entityType: SyncEntityType.practiceSource,
        entityId: id,
        operation: SyncOperation.delete,
        changedAt: changedAt,
      );
      for (final segmentId in segmentIds) {
        await _syncOutbox.enqueue(
          entityType: SyncEntityType.practiceSegment,
          entityId: segmentId,
          operation: SyncOperation.delete,
          changedAt: changedAt,
        );
      }
      for (final planId in planIds) {
        await _syncOutbox.enqueue(
          entityType: SyncEntityType.practicePlan,
          entityId: planId,
          operation: SyncOperation.delete,
          changedAt: changedAt,
        );
      }
      for (final sessionId in sessionIds) {
        await _syncOutbox.enqueue(
          entityType: SyncEntityType.practiceSession,
          entityId: sessionId,
          operation: SyncOperation.upsert,
          changedAt: changedAt,
        );
      }
    });
  }

  domain.PracticeSource _toDomain(db.PracticeSource row) {
    return domain.PracticeSource(
      id: row.id,
      platform: domain.SourcePlatform.values.byName(row.platform),
      kind: domain.SourceKind.values.byName(row.kind),
      originalUri: _parseUri(row.originalUrl),
      canonicalUri: _parseUri(row.canonicalUrl),
      externalId: row.externalId,
      title: row.title,
      thumbnailUri: _parseUri(row.thumbnailUrl),
      duration: row.durationMilliseconds == null
          ? null
          : Duration(milliseconds: row.durationMilliseconds!),
      note: row.note,
      completedAt: row.completedAt?.toUtc(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Uri? _parseUri(String? value) {
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value);
  }
}

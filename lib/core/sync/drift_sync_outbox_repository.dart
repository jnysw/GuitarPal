import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import 'sync_outbox.dart';

class DriftSyncOutboxRepository implements SyncOutboxRepository {
  const DriftSyncOutboxRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<SyncOutboxSummary> watchSummary() {
    final query = _database.select(_database.syncOutboxEntries)
      ..orderBy([(row) => OrderingTerm.asc(row.changedAt)]);
    return query.watch().map((rows) {
      if (rows.isEmpty) return const SyncOutboxSummary.empty();
      return SyncOutboxSummary(
        pendingCount: rows.length,
        failedCount: rows.where((row) => row.lastError != null).length,
        oldestChangedAt: rows.first.changedAt.toUtc(),
      );
    });
  }

  @override
  Future<List<SyncOutboxEntry>> getPending({int limit = 50}) async {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', '必须大于 0');
    final query = _database.select(_database.syncOutboxEntries)
      ..orderBy([
        (row) => OrderingTerm.asc(row.changedAt),
        (row) => OrderingTerm.asc(row.entityType),
        (row) => OrderingTerm.asc(row.entityId),
      ])
      ..limit(limit);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required DateTime changedAt,
  }) async {
    final normalizedId = entityId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(entityId, 'entityId', '不能为空');
    }
    final existing =
        await (_database.select(_database.syncOutboxEntries)..where(
              (row) =>
                  row.entityType.equals(entityType.name) &
                  row.entityId.equals(normalizedId),
            ))
            .getSingleOrNull();
    await _database
        .into(_database.syncOutboxEntries)
        .insertOnConflictUpdate(
          db.SyncOutboxEntriesCompanion.insert(
            entityType: entityType.name,
            entityId: normalizedId,
            operation: operation.name,
            revision: Value((existing?.revision ?? 0) + 1),
            changedAt: changedAt.toUtc(),
            attemptCount: const Value(0),
            lastError: const Value(null),
          ),
        );
  }

  @override
  Future<bool> acknowledge(SyncOutboxEntry entry) async {
    final deleted =
        await (_database.delete(_database.syncOutboxEntries)..where(
              (row) =>
                  row.entityType.equals(entry.entityType.name) &
                  row.entityId.equals(entry.entityId) &
                  row.revision.equals(entry.revision),
            ))
            .go();
    return deleted == 1;
  }

  @override
  Future<bool> markFailed(SyncOutboxEntry entry, String error) async {
    final message = error.trim();
    final updated =
        await (_database.update(_database.syncOutboxEntries)..where(
              (row) =>
                  row.entityType.equals(entry.entityType.name) &
                  row.entityId.equals(entry.entityId) &
                  row.revision.equals(entry.revision),
            ))
            .write(
              db.SyncOutboxEntriesCompanion(
                attemptCount: Value(entry.attemptCount + 1),
                lastError: Value(message.isEmpty ? '同步失败' : message),
              ),
            );
    return updated == 1;
  }

  SyncOutboxEntry _toDomain(db.SyncOutboxEntry row) {
    return SyncOutboxEntry(
      entityType: SyncEntityType.values.byName(row.entityType),
      entityId: row.entityId,
      operation: SyncOperation.values.byName(row.operation),
      revision: row.revision,
      changedAt: row.changedAt.toUtc(),
      attemptCount: row.attemptCount,
      lastError: row.lastError,
    );
  }
}

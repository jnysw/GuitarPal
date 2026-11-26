enum SyncEntityType {
  practiceSource,
  practiceSegment,
  practicePlan,
  practiceSession,
}

enum SyncOperation { upsert, delete }

class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.changedAt,
    required this.attemptCount,
    this.lastError,
  });

  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final int revision;
  final DateTime changedAt;
  final int attemptCount;
  final String? lastError;
}

class SyncOutboxSummary {
  const SyncOutboxSummary({
    required this.pendingCount,
    required this.failedCount,
    this.oldestChangedAt,
  });

  const SyncOutboxSummary.empty()
    : pendingCount = 0,
      failedCount = 0,
      oldestChangedAt = null;

  final int pendingCount;
  final int failedCount;
  final DateTime? oldestChangedAt;

  bool get isEmpty => pendingCount == 0;
}

abstract interface class SyncOutboxRepository {
  Stream<SyncOutboxSummary> watchSummary();

  Future<List<SyncOutboxEntry>> getPending({int limit = 50});

  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperation operation,
    required DateTime changedAt,
  });

  Future<bool> acknowledge(SyncOutboxEntry entry);

  Future<bool> markFailed(SyncOutboxEntry entry, String error);
}

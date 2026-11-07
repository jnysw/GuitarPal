import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/sync/drift_sync_outbox_repository.dart';
import '../../../core/sync/sync_outbox.dart';
import '../../../domain/practice_plan/calendar_date.dart';
import '../../../domain/practice_session/practice_session.dart' as domain;
import '../../../domain/practice_session/practice_session_repository.dart';

class DriftPracticeSessionRepository implements PracticeSessionRepository {
  DriftPracticeSessionRepository(this._database)
    : _syncOutbox = DriftSyncOutboxRepository(_database);

  final db.AppDatabase _database;
  final DriftSyncOutboxRepository _syncOutbox;

  @override
  Stream<List<domain.PracticeSession>> watchAll() {
    final query = _database.select(_database.practiceSessions)
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Stream<List<domain.PracticeSession>> watchForDate(CalendarDate date) {
    final query = _database.select(_database.practiceSessions)
      ..where((row) => row.practiceDay.equals(date.dayKey))
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Stream<List<domain.PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    final query = _database.select(_database.practiceSessions)
      ..where(
        (row) =>
            row.practiceDay.isBiggerOrEqualValue(start.dayKey) &
            row.practiceDay.isSmallerOrEqualValue(end.dayKey),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<void> save(domain.PracticeSession session) async {
    await _database.transaction(() async {
      await _database
          .into(_database.practiceSessions)
          .insertOnConflictUpdate(
            db.PracticeSessionsCompanion(
              id: Value(session.id),
              planId: Value(session.planId),
              sourceId: Value(session.sourceId),
              segmentId: Value(session.segmentId),
              practiceDay: Value(session.practiceDate.dayKey),
              startedAt: Value(session.startedAt),
              endedAt: Value(session.endedAt),
              activeDurationMilliseconds: Value(
                session.activeDuration.inMilliseconds,
              ),
              loopCount: Value(session.loopCount),
              completed: Value(session.completed),
            ),
          );
      await _syncOutbox.enqueue(
        entityType: SyncEntityType.practiceSession,
        entityId: session.id,
        operation: SyncOperation.upsert,
        changedAt: session.endedAt ?? session.startedAt,
      );
    });
  }

  domain.PracticeSession _toDomain(db.PracticeSession row) {
    return domain.PracticeSession(
      id: row.id,
      planId: row.planId,
      sourceId: row.sourceId,
      segmentId: row.segmentId,
      practiceDate: CalendarDate.fromDayKey(row.practiceDay),
      startedAt: row.startedAt.toUtc(),
      endedAt: row.endedAt?.toUtc(),
      activeDuration: Duration(milliseconds: row.activeDurationMilliseconds),
      loopCount: row.loopCount,
      completed: row.completed,
    );
  }
}

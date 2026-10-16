import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../domain/practice_recording/practice_recording.dart' as domain;
import '../../../domain/practice_recording/practice_recording_repository.dart';

class DriftPracticeRecordingRepository implements PracticeRecordingRepository {
  const DriftPracticeRecordingRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<List<domain.PracticeRecording>> watchAll() {
    final query = _database.select(_database.practiceRecordings)
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return query.watch().map(_mapRows);
  }

  @override
  Stream<List<domain.PracticeRecording>> watchBySource(String sourceId) {
    final query = _database.select(_database.practiceRecordings)
      ..where((row) => row.sourceId.equals(sourceId))
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return query.watch().map(_mapRows);
  }

  @override
  Stream<List<domain.PracticeRecording>> watchByPlan(String planId) {
    final query = _database.select(_database.practiceRecordings)
      ..where((row) => row.planId.equals(planId))
      ..orderBy([(row) => OrderingTerm.desc(row.recordedAt)]);
    return query.watch().map(_mapRows);
  }

  @override
  Future<domain.PracticeRecording?> getById(String id) async {
    final query = _database.select(_database.practiceRecordings)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(domain.PracticeRecording recording) async {
    await _database
        .into(_database.practiceRecordings)
        .insertOnConflictUpdate(
          db.PracticeRecordingsCompanion(
            id: Value(recording.id),
            sourceId: Value(recording.sourceId),
            segmentId: Value(recording.segmentId),
            planId: Value(recording.planId),
            sessionId: Value(recording.sessionId),
            kind: Value(recording.kind.name),
            filePath: Value(recording.filePath),
            durationMilliseconds: Value(recording.duration.inMilliseconds),
            referenceStartMilliseconds: Value(
              recording.referenceStart.inMilliseconds,
            ),
            referenceEndMilliseconds: Value(
              recording.referenceEnd?.inMilliseconds,
            ),
            referenceSpeed: Value(recording.referenceSpeed),
            title: Value(recording.title.trim()),
            note: Value(recording.note?.trim()),
            recordedAt: Value(recording.recordedAt.toUtc()),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.practiceRecordings,
    )..where((row) => row.id.equals(id))).go();
  }

  List<domain.PracticeRecording> _mapRows(List<db.PracticeRecording> rows) {
    return rows.map(_toDomain).toList(growable: false);
  }

  domain.PracticeRecording _toDomain(db.PracticeRecording row) {
    return domain.PracticeRecording(
      id: row.id,
      sourceId: row.sourceId,
      segmentId: row.segmentId,
      planId: row.planId,
      sessionId: row.sessionId,
      kind: domain.PracticeRecordingKind.values.byName(row.kind),
      filePath: row.filePath,
      duration: Duration(milliseconds: row.durationMilliseconds),
      referenceStart: Duration(milliseconds: row.referenceStartMilliseconds),
      referenceEnd: row.referenceEndMilliseconds == null
          ? null
          : Duration(milliseconds: row.referenceEndMilliseconds!),
      referenceSpeed: row.referenceSpeed,
      title: row.title,
      note: row.note,
      recordedAt: row.recordedAt.toUtc(),
    );
  }
}

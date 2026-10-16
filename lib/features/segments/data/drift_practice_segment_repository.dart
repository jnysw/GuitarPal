import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../domain/practice_segment/practice_segment.dart' as domain;
import '../../../domain/practice_segment/practice_segment_repository.dart';

class DriftPracticeSegmentRepository implements PracticeSegmentRepository {
  const DriftPracticeSegmentRepository(this._database);

  final db.AppDatabase _database;

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
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.practiceSegments,
    )..where((row) => row.id.equals(id))).go();
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

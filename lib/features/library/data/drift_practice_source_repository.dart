import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../domain/practice_source/practice_source.dart' as domain;
import '../../../domain/practice_source/practice_source_repository.dart';

class DriftPracticeSourceRepository implements PracticeSourceRepository {
  const DriftPracticeSourceRepository(this._database);

  final db.AppDatabase _database;

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
  }

  @override
  Future<void> delete(String id) async {
    await (_database.delete(
      _database.practiceSources,
    )..where((row) => row.id.equals(id))).go();
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

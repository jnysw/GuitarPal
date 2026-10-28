import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class PracticeSources extends Table {
  TextColumn get id => text()();

  TextColumn get platform => text()();

  TextColumn get kind => text()();

  TextColumn get originalUrl => text().nullable()();

  TextColumn get canonicalUrl => text().nullable()();

  TextColumn get externalId => text().nullable()();

  TextColumn get title => text().withLength(min: 1, max: 300)();

  TextColumn get thumbnailUrl => text().nullable()();

  IntColumn get durationMilliseconds => integer().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get syncStatus => text().withDefault(const Constant('local'))();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PracticeSegments extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId =>
      text().references(PracticeSources, #id, onDelete: KeyAction.cascade)();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  IntColumn get startMilliseconds => integer()();

  IntColumn get endMilliseconds => integer()();

  TextColumn get note => text().nullable()();

  RealColumn get preferredSpeed => real().withDefault(const Constant(1.0))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PracticePlans extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get sourceId =>
      text().references(PracticeSources, #id, onDelete: KeyAction.cascade)();

  TextColumn get segmentId => text().nullable().references(
    PracticeSegments,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get goalType => text()();

  IntColumn get targetLoops => integer().nullable()();

  IntColumn get targetDurationMilliseconds => integer().nullable()();

  IntColumn get startDay => integer()();

  IntColumn get endDay => integer()();

  IntColumn get repeatWeekdayMask => integer()();

  IntColumn get reminderMinutesSinceMidnight => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Completed and in-progress practice history.
///
/// Source and segment IDs intentionally are not foreign keys: deleting media
/// must not erase historical practice totals. Plan IDs become null when a plan
/// is deleted for the same reason.
class PracticeSessions extends Table {
  TextColumn get id => text()();

  TextColumn get planId => text().nullable().references(
    PracticePlans,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get sourceId => text()();

  TextColumn get segmentId => text().nullable()();

  IntColumn get practiceDay => integer()();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime().nullable()();

  IntColumn get activeDurationMilliseconds =>
      integer().withDefault(const Constant(0))();

  IntColumn get loopCount => integer().withDefault(const Constant(0))();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// User-recorded guitar takes and selected plan outcomes.
///
/// Source, segment, and session IDs are historical snapshots rather than
/// foreign keys. Deleting source or plan metadata must not silently erase an
/// audio file or the user's progress history.
class PracticeRecordings extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId => text()();

  TextColumn get segmentId => text().nullable()();

  TextColumn get planId => text().nullable()();

  TextColumn get sessionId => text().nullable()();

  TextColumn get kind => text()();

  TextColumn get filePath => text().unique()();

  IntColumn get durationMilliseconds => integer()();

  IntColumn get referenceStartMilliseconds => integer()();

  IntColumn get referenceEndMilliseconds => integer().nullable()();

  RealColumn get referenceSpeed => real().withDefault(const Constant(1.0))();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  TextColumn get note => text().nullable()();

  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Coalesced local metadata changes waiting to be synchronized.
///
/// There is at most one row per entity. [revision] is incremented whenever a
/// newer local mutation replaces a queued one, so a slow upload cannot
/// accidentally acknowledge a change that happened while it was in flight.
class SyncOutboxEntries extends Table {
  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get operation => text()();

  IntColumn get revision => integer().withDefault(const Constant(1))();

  DateTimeColumn get changedAt => dateTime()();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};
}

/// Private development-service jobs. Never part of metadata cloud sync.
class AlgorithmTasks extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text().withDefault(const Constant('chords'))();
  TextColumn get endpoint => text()();
  TextColumn get inputPath => text()();
  TextColumn get inputName => text()();
  IntColumn get inputSizeBytes => integer()();
  IntColumn get inputDurationMs => integer()();
  BoolColumn get ownsInput => boolean().withDefault(const Constant(false))();
  TextColumn get recordingId => text().nullable()();
  TextColumn get linkedSourceId => text().nullable().references(
    PracticeSources,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get linkedPlanId => text().nullable().references(
    PracticePlans,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get status => text()();
  TextColumn get remoteJobId => text().nullable()();
  IntColumn get progress => integer().nullable()();
  TextColumn get message => text().nullable()();
  TextColumn get resultJson => text().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get nextPollAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    PracticeSources,
    PracticeSegments,
    PracticePlans,
    PracticeSessions,
    PracticeRecordings,
    SyncOutboxEntries,
    AlgorithmTasks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'guitar_pal'));

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(practiceSegments);
      } else if (from < 3) {
        await migrator.addColumn(practiceSegments, practiceSegments.note);
        await migrator.addColumn(
          practiceSegments,
          practiceSegments.preferredSpeed,
        );
      }
      if (from < 4) {
        await migrator.createTable(practicePlans);
        await migrator.createTable(practiceSessions);
      } else if (from < 5) {
        await migrator.addColumn(
          practicePlans,
          practicePlans.reminderMinutesSinceMidnight,
        );
      }
      if (from < 6) {
        await migrator.addColumn(practiceSources, practiceSources.completedAt);
      }
      if (from < 7) {
        await migrator.addColumn(practiceSources, practiceSources.note);
      }
      if (from < 8) {
        await migrator.createTable(practiceRecordings);
      }
      if (from < 9) {
        await migrator.createTable(syncOutboxEntries);
        await _backfillSyncOutbox();
      }
      if (from < 10) {
        await migrator.createTable(algorithmTasks);
      } else {
        if (from < 11) {
          await migrator.addColumn(algorithmTasks, algorithmTasks.operation);
        }
        if (from < 12) {
          await migrator.addColumn(
            algorithmTasks,
            algorithmTasks.linkedSourceId,
          );
          await migrator.addColumn(algorithmTasks, algorithmTasks.linkedPlanId);
        }
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _backfillSyncOutbox() async {
    if (await _tableExists('practice_sources')) {
      await customStatement('''
        INSERT OR REPLACE INTO sync_outbox_entries (
          entity_type, entity_id, operation, revision, changed_at, attempt_count
        )
        SELECT 'practiceSource', id, 'upsert', 1, updated_at, 0
        FROM practice_sources
      ''');
    }
    if (await _tableExists('practice_segments')) {
      await customStatement('''
        INSERT OR REPLACE INTO sync_outbox_entries (
          entity_type, entity_id, operation, revision, changed_at, attempt_count
        )
        SELECT 'practiceSegment', id, 'upsert', 1, updated_at, 0
        FROM practice_segments
      ''');
    }
    if (await _tableExists('practice_plans')) {
      await customStatement('''
        INSERT OR REPLACE INTO sync_outbox_entries (
          entity_type, entity_id, operation, revision, changed_at, attempt_count
        )
        SELECT 'practicePlan', id, 'upsert', 1, updated_at, 0
        FROM practice_plans
      ''');
    }
    if (await _tableExists('practice_sessions')) {
      await customStatement('''
        INSERT OR REPLACE INTO sync_outbox_entries (
          entity_type, entity_id, operation, revision, changed_at, attempt_count
        )
        SELECT 'practiceSession', id, 'upsert', 1,
          COALESCE(ended_at, started_at), 0
        FROM practice_sessions
      ''');
    }
  }

  Future<bool> _tableExists(String name) async {
    final row = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: [Variable.withString('table'), Variable.withString(name)],
      readsFrom: const {},
    ).getSingleOrNull();
    return row != null;
  }
}

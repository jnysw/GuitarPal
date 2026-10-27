import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/algorithm_task.dart';

class AlgorithmTaskRepository {
  const AlgorithmTaskRepository(this.database);
  final db.AppDatabase database;

  Stream<List<AlgorithmTaskRecord>> watchAll() =>
      (database.select(database.algorithmTasks)
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .watch()
          .map((rows) => rows.map(_map).toList(growable: false));

  Future<AlgorithmTaskRecord?> get(String id) async {
    final row = await (database.select(
      database.algorithmTasks,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<void> insert(AlgorithmTaskRecord value) => database
      .into(database.algorithmTasks)
      .insert(
        db.AlgorithmTasksCompanion.insert(
          id: value.id,
          endpoint: value.endpoint,
          inputPath: value.inputPath,
          inputName: value.inputName,
          inputSizeBytes: value.inputSizeBytes,
          inputDurationMs: value.inputDurationMs,
          ownsInput: Value(value.ownsInput),
          recordingId: Value(value.recordingId),
          status: value.state.name,
          createdAt: value.createdAt,
          updatedAt: value.updatedAt,
        ),
      )
      .then((_) {});

  Future<void> update(
    String id,
    AlgorithmTaskState state, {
    String? jobId,
    int? progress,
    String? message,
    String? resultJson,
    int? failures,
    DateTime? nextPollAt,
  }) async {
    await (database.update(
      database.algorithmTasks,
    )..where((r) => r.id.equals(id))).write(
      db.AlgorithmTasksCompanion(
        status: Value(state.name),
        remoteJobId: jobId == null ? const Value.absent() : Value(jobId),
        progress: Value(progress),
        message: Value(message),
        resultJson: resultJson == null
            ? const Value.absent()
            : Value(resultJson),
        consecutiveFailures: failures == null
            ? const Value.absent()
            : Value(failures),
        nextPollAt: Value(nextPollAt),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> recoverInterruptedSubmissions() async {
    await (database.update(database.algorithmTasks)..where(
          (r) =>
              r.status.equals(AlgorithmTaskState.submitting.name) &
              r.remoteJobId.isNull(),
        ))
        .write(
          db.AlgorithmTasksCompanion(
            status: Value(AlgorithmTaskState.submissionUnknown.name),
            message: const Value('提交时应用已离开，服务器是否接收未知；不会自动重复上传'),
          ),
        );
  }

  Future<void> delete(String id) async {
    await (database.delete(
      database.algorithmTasks,
    )..where((r) => r.id.equals(id))).go();
  }

  AlgorithmTaskRecord _map(db.AlgorithmTask row) => AlgorithmTaskRecord(
    id: row.id,
    endpoint: row.endpoint,
    inputPath: row.inputPath,
    inputName: row.inputName,
    inputSizeBytes: row.inputSizeBytes,
    inputDurationMs: row.inputDurationMs,
    ownsInput: row.ownsInput,
    recordingId: row.recordingId,
    state: AlgorithmTaskState.values.byName(row.status),
    remoteJobId: row.remoteJobId,
    progress: row.progress,
    message: row.message,
    resultJson: row.resultJson,
    failures: row.consecutiveFailures,
    nextPollAt: row.nextPollAt?.toUtc(),
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

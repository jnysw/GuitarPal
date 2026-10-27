import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/features/audio_tools/application/algorithm_task_service.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  group('task service', () {
    late AppDatabase database;
    late AlgorithmTaskRepository repository;
    late AlgorithmTaskService service;
    late _Api api;
    var now = DateTime.utc(2026, 10, 27, 12);
    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = AlgorithmTaskRepository(database);
      api = _Api();
      service = AlgorithmTaskService(
        repository,
        allowLocalHttp: true,
        apiFactory: (_) => api,
        clock: () => now,
      );
    });
    tearDown(() => database.close());

    test(
      'persists receipt and caches result without requerying it offline',
      () async {
        await service.submit(_task('job-local'));
        expect(
          (await repository.get('job-local'))?.remoteJobId,
          'contract_job_1',
        );
        api.state = LegacyJobState.completed;
        await service.refresh('job-local');
        final completed = (await repository.get('job-local'))!;
        expect(completed.state, AlgorithmTaskState.completed);
        expect(jsonDecode(completed.resultJson!)['segments'], hasLength(3));
        api.error = const AlgorithmApiError(
          'job_not_found',
          'missing',
          httpStatus: 404,
        );
        await service.refresh('job-local', force: true);
        expect(api.statusCalls, 1);
        expect(
          (await repository.get('job-local'))?.resultJson,
          completed.resultJson,
        );
      },
    );

    test(
      'lost POST response and app restart never automatically resubmit',
      () async {
        api.uploadError = const AlgorithmApiError('network_timeout', 'timeout');
        await service.submit(_task('uncertain'));
        expect(
          (await repository.get('uncertain'))?.state,
          AlgorithmTaskState.submissionUnknown,
        );
        await service.refresh('uncertain', force: true);
        expect(api.uploadCalls, 1);
        expect(api.statusCalls, 0);
        await repository.insert(_task('interrupted'));
        await repository.recoverInterruptedSubmissions();
        expect(
          (await repository.get('interrupted'))?.state,
          AlgorithmTaskState.submissionUnknown,
        );
      },
    );

    test(
      'HTTP-200 failed jobs stop and GET retries respect Retry-After',
      () async {
        await service.submit(_task('failed'));
        api.state = LegacyJobState.failed;
        await service.refresh('failed');
        expect(
          (await repository.get('failed'))?.state,
          AlgorithmTaskState.failed,
        );
        expect(api.resultCalls, 0);

        await service.submit(_task('retry'));
        api.error = const AlgorithmApiError(
          'queue_full',
          'busy',
          httpStatus: 429,
          retryAfter: Duration(seconds: 20),
        );
        await service.refresh('retry');
        expect(
          (await repository.get('retry'))?.nextPollAt,
          now.add(const Duration(seconds: 20)),
        );
        final calls = api.statusCalls;
        now = now.add(const Duration(seconds: 10));
        await service.refresh('retry');
        expect(api.statusCalls, calls);
        now = now.add(const Duration(seconds: 10));
        api.error = const AlgorithmApiError(
          'job_not_found',
          'gone',
          httpStatus: 404,
        );
        await service.refresh('retry');
        expect((await repository.get('retry'))?.state, AlgorithmTaskState.lost);
        expect(api.uploadCalls, 2);
      },
    );

    test(
      'separation operation survives persistence, polling and caching',
      () async {
        await service.submit(
          _task('separate', operation: AlgorithmOperation.separation),
        );
        expect(
          (await repository.get('separate'))!.operation,
          AlgorithmOperation.separation,
        );
        api.state = LegacyJobState.completed;
        await service.refresh('separate');
        expect(api.lastOperation, AlgorithmOperation.separation);
        final task = (await repository.get('separate'))!;
        expect(task.state, AlgorithmTaskState.completed);
        expect(jsonDecode(task.resultJson!)['stems'], hasLength(7));
      },
    );

    test('late query responses do not revive deleted local history', () async {
      await service.submit(_task('deleted'));
      api.pending = Completer<void>();
      final first = service.refresh('deleted');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await service.refresh('deleted');
      expect(api.statusCalls, 1);
      await repository.delete('deleted');
      api.pending!.complete();
      await first;
      expect(await repository.get('deleted'), isNull);
    });
  });
  test('v10 migration preserves old chord tasks and cached results', () async {
    final dir = await Directory.systemTemp.createTemp('gp_v10_');
    final file = File('${dir.path}/test.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await AlgorithmTaskRepository(old).insert(_task('old-chords'));
    await AlgorithmTaskRepository(old).update(
      'old-chords',
      AlgorithmTaskState.completed,
      resultJson: '{"cached":true}',
    );
    await old.close();
    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('ALTER TABLE algorithm_tasks DROP COLUMN operation');
          raw.execute('PRAGMA user_version = 10');
        },
      ),
    );
    try {
      final task = (await AlgorithmTaskRepository(migrated).get('old-chords'))!;
      expect(task.operation, AlgorithmOperation.chords);
      expect(task.state, AlgorithmTaskState.completed);
      expect(task.resultJson, '{"cached":true}');
    } finally {
      await migrated.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'v9 migration preserves source, A-B, sessions and recording paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'guitarpal_v9_algorithms_',
      );
      final file = File('${directory.path}/test.sqlite');
      final original = AppDatabase(NativeDatabase(file));
      final date = DateTime.utc(2026, 10, 27);
      await original
          .into(original.practiceSources)
          .insert(
            PracticeSourcesCompanion.insert(
              id: 'source',
              platform: 'local',
              kind: 'video',
              title: '保留曲目',
              createdAt: date,
              updatedAt: date,
            ),
          );
      await original
          .into(original.practiceSegments)
          .insert(
            PracticeSegmentsCompanion.insert(
              id: 'segment',
              sourceId: 'source',
              title: '保留片段',
              startMilliseconds: 3250,
              endMilliseconds: 8750,
              createdAt: date,
              updatedAt: date,
            ),
          );
      await original
          .into(original.practiceSessions)
          .insert(
            PracticeSessionsCompanion.insert(
              id: 'session',
              sourceId: 'source',
              practiceDay: 20261027,
              startedAt: date,
            ),
          );
      await original
          .into(original.practiceRecordings)
          .insert(
            PracticeRecordingsCompanion.insert(
              id: 'recording',
              sourceId: 'source',
              kind: 'segmentTake',
              filePath: 'practice_recordings/keep.m4a',
              durationMilliseconds: 5500,
              referenceStartMilliseconds: 3250,
              title: '保留录音',
              recordedAt: date,
            ),
          );
      await original.close();
      final migrated = AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute('DROP TABLE algorithm_tasks');
            raw.execute('PRAGMA user_version = 9');
          },
        ),
      );
      try {
        expect(
          (await migrated.select(migrated.practiceSources).getSingle()).title,
          '保留曲目',
        );
        final segment = await migrated
            .select(migrated.practiceSegments)
            .getSingle();
        expect(
          [segment.startMilliseconds, segment.endMilliseconds],
          [3250, 8750],
        );
        expect(
          await migrated.select(migrated.practiceSessions).get(),
          hasLength(1),
        );
        expect(
          (await migrated.select(migrated.practiceRecordings).getSingle())
              .filePath,
          'practice_recordings/keep.m4a',
        );
        expect(await migrated.select(migrated.algorithmTasks).get(), isEmpty);
      } finally {
        await migrated.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

AlgorithmTaskRecord _task(
  String id, {
  AlgorithmOperation operation = AlgorithmOperation.chords,
}) {
  final time = DateTime.utc(2026, 10, 27);
  return AlgorithmTaskRecord(
    id: id,
    operation: operation,
    endpoint: 'http://127.0.0.1:8000',
    inputPath: '/private/test.wav',
    inputName: 'test.wav',
    inputSizeBytes: 8000,
    inputDurationMs: 8000,
    ownsInput: false,
    state: AlgorithmTaskState.submitting,
    createdAt: time,
    updatedAt: time,
    failures: 0,
  );
}

class _Api implements AlgorithmApi {
  AlgorithmOperation? lastOperation;
  int uploadCalls = 0, statusCalls = 0, resultCalls = 0;
  LegacyJobState state = LegacyJobState.queued;
  AlgorithmApiError? uploadError, error;
  Completer<void>? pending;
  @override
  Future<void> ping() async {}
  @override
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int, int)? onProgress,
  }) async {
    uploadCalls++;
    lastOperation = operation;
    if (uploadError != null) throw uploadError!;
    return LegacyUploadReceipt.fromJson(
      {
        'job_id': 'contract_job_1',
        'status': 'queued',
        'poll_url': '${algorithmJobRoot(operation, 'contract_job_1')}/status',
        'result_url': '${algorithmJobRoot(operation, 'contract_job_1')}/result',
      },
      AlgorithmEndpoint('http://127.0.0.1:8000', allowLocalHttp: true),
      operation,
    );
  }

  @override
  Future<LegacyAlgorithmStatus> status(
    String jobId,
    AlgorithmOperation operation,
  ) async {
    statusCalls++;
    lastOperation = operation;
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
    return LegacyAlgorithmStatus.fromJson({
      'job_id': jobId,
      'status': state.name,
      'progress': state == LegacyJobState.completed ? 100 : 10,
      'message': 'test',
      'error': state == LegacyJobState.failed ? '推理失败' : null,
    }, operation);
  }

  @override
  Future<Map<String, Object?>> result(
    String jobId,
    AlgorithmOperation operation,
  ) async {
    resultCalls++;
    lastOperation = operation;
    if (operation == AlgorithmOperation.separation) return separationFixture();
    return jsonDecode(
      File('contracts/legacy_algorithm/fixtures/chords_result.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
  }

  @override
  void close() {}
}

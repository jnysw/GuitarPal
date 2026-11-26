import 'dart:convert';

import '../data/algorithm_task_repository.dart';
import '../data/legacy_algorithm_api.dart';
import '../domain/algorithm_task.dart';
import '../domain/legacy_algorithm_models.dart';

typedef AlgorithmApiFactory = AlgorithmApi Function(AlgorithmEndpoint endpoint);

class AlgorithmTaskService {
  AlgorithmTaskService(
    this.repository, {
    required this.allowLocalHttp,
    AlgorithmApiFactory? apiFactory,
    DateTime Function()? clock,
  }) : _factory = apiFactory ?? LegacyAlgorithmApi.new,
       _clock = clock ?? DateTime.now;
  final AlgorithmTaskRepository repository;
  final bool allowLocalHttp;
  final AlgorithmApiFactory _factory;
  final DateTime Function() _clock;
  final Set<String> _refreshing = {};
  Future<void>? _initialization;
  Future<void> initialize() =>
      _initialization ??= repository.recoverInterruptedSubmissions();

  /// A read-only check before expensive extraction or creation of a task.
  Future<void> checkConnection(
    String origin, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
  }) async {
    final api = _factory(
      AlgorithmEndpoint(origin, allowLocalHttp: allowLocalHttp),
    );
    try {
      await api.ping(operation: operation);
    } on FormatException {
      throw const AlgorithmApiError(
        'invalid_health_response',
        '分析服务暂不可用，请稍后重试',
      );
    } finally {
      api.close();
    }
  }

  Future<void> submit(
    AlgorithmTaskRecord task, {
    void Function(int, int)? onProgress,
  }) async {
    await initialize();
    final endpoint = AlgorithmEndpoint(
      task.endpoint,
      allowLocalHttp: allowLocalHttp,
    );
    await repository.insert(task);
    final api = _factory(endpoint);
    try {
      final receipt = await api.upload(
        task.inputPath,
        task.inputName,
        operation: task.operation,
        onProgress: onProgress,
      );
      await repository.update(
        task.id,
        AlgorithmTaskState.queued,
        jobId: receipt.jobId,
        message: '服务器已接收，等待分析',
      );
    } on AlgorithmReceiptError catch (error) {
      await repository.update(
        task.id,
        AlgorithmTaskState.queued,
        jobId: error.jobId,
        message: error.message,
      );
    } on AlgorithmApiError catch (error) {
      final definitelyRejected =
          {
            'input_unavailable',
            'invalid_file_size',
            'unsupported_format',
            'upload_not_sent',
            'authorization_required',
            'credential_storage_unavailable',
          }.contains(error.code) ||
          (error.code == 'model_unavailable' && error.httpStatus == 503) ||
          (error.httpStatus != null &&
              error.httpStatus! >= 400 &&
              error.httpStatus! < 500);
      await repository.update(
        task.id,
        definitelyRejected
            ? AlgorithmTaskState.failed
            : AlgorithmTaskState.submissionUnknown,
        message:
            '${error.message}${definitelyRejected ? '' : '；接收状态未知，不会自动重复上传'}',
      );
    } on Object {
      await repository.update(
        task.id,
        AlgorithmTaskState.submissionUnknown,
        message: '未获得可靠的任务回执；接收状态未知，不会自动重复上传',
      );
    } finally {
      api.close();
    }
  }

  /// Explicit recovery for a lost response. No upload or guessed job ID.
  Future<void> recoverWithJobId(String id, String jobId) async {
    await initialize();
    algorithmId(jobId);
    final task = await repository.get(id);
    if (task == null ||
        task.state != AlgorithmTaskState.submissionUnknown ||
        task.remoteJobId != null) {
      throw const FormatException('任务状态已变化，请刷新');
    }
    final api = _factory(
      AlgorithmEndpoint(task.endpoint, allowLocalHttp: allowLocalHttp),
    );
    try {
      final status = await api.status(jobId, task.operation);
      if (status.jobId != jobId) throw const FormatException('任务编号不匹配');
      await repository.update(
        id,
        AlgorithmTaskState.queued,
        jobId: jobId,
        message: '已找回任务，正在查询结果',
      );
    } finally {
      api.close();
    }
    await refresh(id, force: true);
  }

  Iterable<AlgorithmTaskRecord> pendingPollBatch(
    Iterable<AlgorithmTaskRecord> tasks, {
    required int limit,
  }) {
    final now = _clock().toUtc();
    final due =
        tasks
            .where(
              (task) => !_refreshing.contains(task.id) && _pollDue(task, now),
            )
            .toList()
          ..sort((a, b) {
            final order = a.updatedAt.compareTo(b.updatedAt);
            return order == 0 ? a.createdAt.compareTo(b.createdAt) : order;
          });
    return due.take(limit);
  }

  bool _pollDue(AlgorithmTaskRecord task, DateTime now) =>
      task.shouldPoll &&
      task.resultJson == null &&
      !(task.nextPollAt?.isAfter(now) ?? false);

  Future<void> refresh(String id, {bool force = false}) async {
    await initialize();
    if (!_refreshing.add(id)) return;
    try {
      final task = await repository.get(id);
      if (task == null ||
          task.remoteJobId == null ||
          task.resultJson != null ||
          (!force && !_pollDue(task, _clock().toUtc()))) {
        return;
      }
      final api = _factory(
        AlgorithmEndpoint(task.endpoint, allowLocalHttp: allowLocalHttp),
      );
      try {
        final status = await api.status(task.remoteJobId!, task.operation);
        if (status.state == LegacyJobState.failed) {
          await repository.update(
            id,
            AlgorithmTaskState.failed,
            message: status.error ?? '服务器分析失败',
          );
        } else if (status.state == LegacyJobState.completed) {
          final result = await api.result(task.remoteJobId!, task.operation);
          await repository.update(
            id,
            AlgorithmTaskState.completed,
            progress: 100,
            resultJson: jsonEncode(result),
            failures: 0,
            message: task.operation == AlgorithmOperation.chords
                ? '和弦结果已保存在本机'
                : '分轨清单已保存在本机，请在过期前下载音轨',
          );
        } else {
          await repository.update(
            id,
            status.state == LegacyJobState.queued
                ? AlgorithmTaskState.queued
                : AlgorithmTaskState.processing,
            progress: status.progress,
            failures: 0,
            message: status.displayMessage(task.operation),
          );
        }
      } on AlgorithmApiError catch (error) {
        final failures = task.failures + 1;
        if (error.httpStatus == 401 ||
            {
              'authorization_required',
              'credential_storage_unavailable',
            }.contains(error.code)) {
          await repository.update(
            id,
            AlgorithmTaskState.authorizationRequired,
            message: error.message,
          );
        } else if (error.httpStatus == 404 || error.httpStatus == 410) {
          await repository.update(
            id,
            AlgorithmTaskState.lost,
            message: '这条服务器任务已过期或无法由当前会话打开。可查看本机已有结果。',
          );
        } else if (error.httpStatus == 409 || error.isTemporary) {
          final seconds = (2 * (1 << failures.clamp(0, 4))).clamp(2, 30);
          await repository.update(
            id,
            AlgorithmTaskState.unavailable,
            failures: failures,
            message: error.message,
            nextPollAt: _clock().toUtc().add(
              error.retryAfter ?? Duration(seconds: seconds),
            ),
          );
        } else {
          await repository.update(
            id,
            AlgorithmTaskState.failed,
            message: error.message,
          );
        }
      } on Object {
        await repository.update(
          id,
          AlgorithmTaskState.invalidResult,
          message: '服务器响应不符合接口约定，可在服务端修复后手动重新查询',
        );
      } finally {
        api.close();
      }
    } finally {
      _refreshing.remove(id);
    }
  }
}

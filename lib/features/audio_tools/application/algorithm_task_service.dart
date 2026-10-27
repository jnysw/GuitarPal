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

  Future<void> submit(
    AlgorithmTaskRecord task, {
    void Function(int, int)? onProgress,
  }) async {
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
    } on AlgorithmApiError catch (error) {
      final definitelyRejected =
          {
            'input_unavailable',
            'invalid_file_size',
            'unsupported_format',
          }.contains(error.code) ||
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

  Future<void> refresh(String id, {bool force = false}) async {
    if (!_refreshing.add(id)) return;
    try {
      final task = await repository.get(id);
      if (task == null ||
          task.remoteJobId == null ||
          task.resultJson != null ||
          (!force &&
              (!task.shouldPoll ||
                  (task.nextPollAt?.isAfter(_clock().toUtc()) ?? false)))) {
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
            message: status.message,
          );
        }
      } on AlgorithmApiError catch (error) {
        final failures = task.failures + 1;
        if (error.httpStatus == 404 || error.httpStatus == 410) {
          await repository.update(
            id,
            AlgorithmTaskState.lost,
            message: '服务器任务不存在或已过期；可能因重启丢失。本机已有结果仍会保留',
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

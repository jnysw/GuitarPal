import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../domain/legacy_algorithm_models.dart';
import '../domain/video_stem_choice.dart';
import 'resumable_stem_transfer.dart';
export 'resumable_stem_transfer.dart'
    show StemDownloadCancellation, StemDownloadPaused, StemDownloadProgress;

class AlgorithmStemPlatform {
  const AlgorithmStemPlatform();
  static const _channel = MethodChannel('com.guitarpal/algorithm_stems');
  Future<Directory> directory() async =>
      Directory((await _channel.invokeMethod<String>('directory'))!);
  Future<void> play(String path, Duration position) => _channel.invokeMethod(
    'play',
    {'path': path, 'positionMs': position.inMilliseconds},
  );
  Future<void> pause() => _channel.invokeMethod('pause');
  Future<void> stop() => _channel.invokeMethod('stop');
  Future<void> seek(Duration position) =>
      _channel.invokeMethod('seek', {'positionMs': position.inMilliseconds});
  Future<Map<String, Object?>> snapshot() async =>
      (await _channel.invokeMapMethod<String, Object?>('snapshot'))!;
}

/// Durable verified files and resumable downloads, shared by both playback UIs.
class AlgorithmStemStore {
  AlgorithmStemStore(
    this.root, {
    http.Client Function()? clientFactory,
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) : _transfer = ResumableStemTransfer(
         root,
         clientFactory: clientFactory ?? http.Client.new,
         timeout: timeout,
         maxAttempts: maxAttempts,
         retryDelay: retryDelay,
       );
  final Future<Directory> Function() root;
  final ResumableStemTransfer _transfer;
  Future<File?> localFile(String taskId, LegacyStemFile stem) =>
      _transfer.localFile(taskId, stem);
  Future<Map<String, StemCacheStatus>> inspect(
    String taskId,
    List<LegacyStemFile> stems,
  ) async {
    final states = <String, StemCacheStatus>{};
    for (final stem in stems) {
      final file = await localFile(taskId, stem);
      states[stem.id] = StemCacheStatus(
        complete: file != null,
        receivedBytes: file != null
            ? stem.sizeBytes
            : await _transfer.partialBytes(taskId, stem),
      );
    }
    return Map.unmodifiable(states);
  }

  Future<File> download(
    String taskId,
    LegacyStemFile stem, {
    void Function(int, int)? onProgress,
    StemDownloadCancellation? cancellation,
  }) => _transfer.download(
    taskId,
    stem,
    onProgress: onProgress,
    cancellation: cancellation,
  );
  Future<Map<String, String>> downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
  }) => _transfer.downloadBatch(
    taskId,
    stems,
    cancellation: cancellation,
    onProgress: onProgress,
  );
  Future<void> deleteTask(String taskId) async {
    final prefix = '${algorithmId(taskId)}_';
    if (_transfer.isDownloadingTask(taskId)) throw StateError('请先暂停音轨下载');
    final directory = await root();
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.uri.pathSegments.last.startsWith(prefix)) {
        await entry.delete();
      }
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../domain/legacy_algorithm_models.dart';

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

/// Durable app-private files, never cacheDir. Partial transfers are not playable.
class AlgorithmStemStore {
  AlgorithmStemStore(
    this.root, {
    http.Client Function()? clientFactory,
    this.timeout = const Duration(minutes: 5),
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final Future<Directory> Function() root;
  final http.Client Function() _clientFactory;
  final Duration timeout;
  final Set<String> _downloading = {};

  Future<File> _file(String taskId, LegacyStemFile stem) async {
    final directory = await root();
    await directory.create(recursive: true);
    return File(
      '${directory.path}/${algorithmId(taskId)}_${stem.id}.${stem.extension}',
    );
  }

  Future<File?> localFile(String taskId, LegacyStemFile stem) async {
    final file = await _file(taskId, stem);
    return await file.exists() && await file.length() == stem.sizeBytes
        ? file
        : null;
  }

  Future<File> download(
    String taskId,
    LegacyStemFile stem, {
    void Function(int, int)? onProgress,
  }) async {
    final key = '${algorithmId(taskId)}_${stem.id}';
    if (!_downloading.add(key)) throw StateError('此音轨正在下载');
    http.Client? client;
    File? partial;
    final abort = Completer<void>();
    try {
      final cached = await localFile(taskId, stem);
      if (cached != null) return cached;
      final file = await _file(taskId, stem);
      partial = File('${file.path}.part');
      client = _clientFactory();
      final request = http.AbortableRequest(
        'GET',
        stem.downloadUri,
        abortTrigger: abort.future,
      )..followRedirects = false;
      final currentClient = client;
      final temporary = partial;
      Future<File> transfer() async {
        final response = await currentClient.send(request);
        if (response.statusCode != 200) {
          throw AlgorithmApiError(
            'download_http_${response.statusCode}',
            response.statusCode == 404 || response.statusCode == 410
                ? '服务器音轨已过期或不存在；已下载的本机音轨仍可使用'
                : '音轨下载失败（HTTP ${response.statusCode}）',
            httpStatus: response.statusCode,
          );
        }
        if (response.contentLength != null &&
            response.contentLength != stem.sizeBytes) {
          throw const FormatException('音轨长度与清单不一致');
        }
        final mime = response.headers['content-type']?.split(';').first.trim();
        if (mime != stem.contentType) throw const FormatException('音轨类型与清单不一致');
        var received = 0;
        final sink = temporary.openWrite();
        try {
          await for (final chunk in response.stream) {
            received += chunk.length;
            if (received > stem.sizeBytes) {
              throw const FormatException('音轨下载超出声明大小');
            }
            sink.add(chunk);
            // Flush each network chunk to keep memory bounded for large WAVs.
            await sink.flush();
            onProgress?.call(received, stem.sizeBytes);
          }
        } finally {
          await sink.close();
        }
        if (received != stem.sizeBytes) {
          throw const FormatException('音轨下载不完整，请重试');
        }
        final handle = await temporary.open();
        late List<int> header;
        try {
          header = await handle.read(12);
        } finally {
          await handle.close();
        }
        final signature = String.fromCharCodes(header);
        if (stem.extension == 'wav'
            ? !(signature.startsWith('RIFF') && signature.endsWith('WAVE'))
            : !signature.startsWith('fLaC')) {
          throw const FormatException('下载内容不是有效的 WAV / FLAC 文件');
        }
        return temporary.rename(file.path);
      }

      final running = transfer();
      try {
        return await running.timeout(timeout);
      } on TimeoutException {
        if (!abort.isCompleted) abort.complete();
        currentClient.close();
        // Wait for the aborted stream/sink before allowing another download.
        try {
          await running;
        } on Object {
          /* original timeout is shown */
        }
        throw const AlgorithmApiError('network_timeout', '音轨下载超时，请重试');
      }
    } finally {
      if (!abort.isCompleted) abort.complete();
      client?.close();
      // Let an aborted transfer finish closing its sink before removing .part.
      // .part is never considered cached, including after process termination.
      if (partial != null && await partial.exists()) {
        try {
          await partial.delete();
        } on FileSystemException {
          /* retry overwrites it */
        }
      }
      _downloading.remove(key);
    }
  }

  Future<void> deleteTask(String taskId) async {
    final prefix = '${algorithmId(taskId)}_';
    if (_downloading.any((key) => key.startsWith(prefix))) {
      throw StateError('请等待音轨下载完成');
    }
    final directory = await root();
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.uri.pathSegments.last.startsWith(prefix)) {
        await entry.delete();
      }
    }
  }
}

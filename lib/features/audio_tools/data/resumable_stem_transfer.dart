import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/legacy_algorithm_models.dart';
import 'stem_audio_validation.dart';

class StemDownloadPaused implements Exception {
  const StemDownloadPaused();
  @override
  String toString() => '下载已暂停，已完成和可续传的进度保留在本机';
}

class StemDownloadCancellation {
  bool _cancelled = false;
  final _done = Completer<void>();
  final _listeners = <void Function()>{};
  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _done.future;
  void check() {
    if (_cancelled) throw const StemDownloadPaused();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _done.complete();
    for (final callback in _listeners.toList()) {
      callback();
    }
    _listeners.clear();
  }

  void Function() listen(void Function() callback) {
    if (_cancelled) {
      callback();
      return () {};
    }
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }
}

class StemDownloadProgress {
  const StemDownloadProgress(
    this.receivedBytes,
    this.totalBytes,
    this.completedFiles,
    this.totalFiles,
    this.bytesPerSecond,
  );
  final int receivedBytes, totalBytes, completedFiles, totalFiles;
  final double bytesPerSecond;
  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
  Duration? get remaining => bytesPerSecond > 0
      ? Duration(
          seconds: ((totalBytes - receivedBytes) / bytesPerSecond).ceil(),
        )
      : null;
}

/// Range + If-Range transfers. Completed and partial files survive network loss.
class ResumableStemTransfer {
  ResumableStemTransfer(
    this.root, {
    required this.clientFactory,
    required this.timeout,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  });
  final Future<Directory> Function() root;
  final http.Client Function() clientFactory;

  /// Inactivity budget, not a total-file deadline.
  final Duration timeout, retryDelay;
  final int maxAttempts;
  final _active = <String>{};
  final _batches = <String>{};
  final _verified = <String, String>{};
  bool isDownloadingTask(String id) =>
      _batches.contains(algorithmId(id)) ||
      _active.any((k) => k.startsWith('${algorithmId(id)}_'));

  Future<File> file(String taskId, LegacyStemFile stem) async {
    final directory = await root();
    await directory.create(recursive: true);
    return File(
      '${directory.path}/${algorithmId(taskId)}_${algorithmId(stem.id)}.${stem.extension}',
    );
  }

  String _identity(LegacyStemFile s) => jsonEncode([
    s.downloadUri.toString(),
    s.sizeBytes,
    s.contentType,
    s.sampleRate,
    s.channels,
    s.duration.inMilliseconds,
  ]);
  Future<Map<String, Object?>?> _json(File f) async {
    try {
      if (!await f.exists() || await f.length() > 16384) return null;
      return algorithmObject(jsonDecode(await f.readAsString()));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeJson(File f, Map<String, Object?> value) async {
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(f.path);
  }

  Future<void> _remove(File f) async {
    if (await f.exists()) await f.delete();
  }

  Future<String> _hash(File f) async =>
      (await sha256.bind(f.openRead()).first).toString();

  Future<File?> localFile(String taskId, LegacyStemFile stem) async {
    final target = await file(taskId, stem);
    if (!await target.exists()) return null;
    final receiptFile = File('${target.path}.verified.json');
    final receipt = await _json(receiptFile);
    try {
      if (receipt != null && receipt['identity'] != _identity(stem)) {
        throw const FormatException('缓存清单已变化');
      }
      final stat = await target.stat();
      final stamp =
          '${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stem.sha256 ?? ''}';
      if (_verified[target.path] == stamp) return target;
      await validateStemAudio(target, stem);
      final digest = await _hash(target);
      if (stem.sha256 != null && digest != stem.sha256) {
        throw const FormatException('音轨缓存与服务器校验不一致');
      }
      if (receipt != null && receipt['sha256'] != digest) {
        throw const FormatException('音轨缓存已损坏');
      }
      await _writeJson(receiptFile, {
        'identity': _identity(stem),
        'sha256': digest,
      });
      _verified[target.path] = stamp;
      return target;
    } on FormatException {
      _verified.remove(target.path);
      await _remove(target);
      await _remove(receiptFile);
      for (final suffix in ['.mix.wav', '.mix.identity', '.mix.wav.part']) {
        await _remove(File('${target.path}$suffix'));
      }
      return null;
    }
  }

  Future<int> partialBytes(String taskId, LegacyStemFile stem) async {
    final target = await file(taskId, stem);
    final part = File('${target.path}.part');
    final meta = await _json(File('${part.path}.json'));
    if (meta?['identity'] != _identity(stem) ||
        _validator(meta) == null ||
        !await part.exists()) {
      return 0;
    }
    final n = await part.length();
    return n <= stem.sizeBytes ? n : 0;
  }

  String? _validator(Map<String, Object?>? meta) {
    final etag = meta?['etag'];
    if (etag is String &&
        etag.startsWith('"') &&
        etag.endsWith('"') &&
        !etag.contains('\r') &&
        !etag.contains('\n')) {
      return etag;
    }
    final modified = meta?['lastModified'];
    if (modified is String) {
      try {
        HttpDate.parse(modified);
        return modified;
      } on Object {
        /* no safe validator */
      }
    }
    return null;
  }

  Future<File> download(
    String taskId,
    LegacyStemFile stem, {
    void Function(int, int)? onProgress,
    StemDownloadCancellation? cancellation,
    http.Client? client,
  }) async {
    final key = '${algorithmId(taskId)}_${algorithmId(stem.id)}';
    if (!_active.add(key)) throw StateError('此音轨正在下载');
    final token = cancellation ?? StemDownloadCancellation();
    var connection = client;
    try {
      token.check();
      final cached = await localFile(taskId, stem);
      if (cached != null) {
        onProgress?.call(stem.sizeBytes, stem.sizeBytes);
        return cached;
      }
      connection ??= clientFactory();
      final target = await file(taskId, stem);
      for (var attempt = 0; ; attempt++) {
        token.check();
        try {
          return await _attempt(target, stem, connection, token, onProgress);
        } on Object catch (error) {
          token.check();
          final retryable =
              error is TimeoutException ||
              error is http.ClientException ||
              error is SocketException ||
              (error is AlgorithmApiError &&
                  (error.isTemporary ||
                      error.code == 'download_incomplete' ||
                      error.code == 'download_checksum_mismatch' ||
                      error.code == 'partial_invalidated'));
          if (!retryable || attempt + 1 >= maxAttempts) {
            if (error is TimeoutException ||
                error is http.ClientException ||
                error is SocketException) {
              throw const AlgorithmApiError(
                'network_timeout',
                '音轨连接中断，已保留进度；点击继续下载，无需重新分轨',
              );
            }
            rethrow;
          }
          final delay = error is AlgorithmApiError && error.retryAfter != null
              ? error.retryAfter!
              : retryDelay * (attempt + 1);
          await Future.any([Future<void>.delayed(delay), token.whenCancelled]);
        }
      }
    } on FileSystemException catch (e) {
      throw AlgorithmApiError(
        'storage_error',
        [28, 122].contains(e.osError?.errorCode)
            ? '本机空间不足；请释放空间后继续下载，已完成音轨会保留'
            : '本机音轨读写失败，请检查存储空间后继续',
      );
    } finally {
      if (client == null) connection?.close();
      _active.remove(key);
    }
  }

  Future<File> _attempt(
    File target,
    LegacyStemFile stem,
    http.Client client,
    StemDownloadCancellation token,
    void Function(int, int)? onProgress,
  ) async {
    final part = File('${target.path}.part'),
        metaFile = File('${target.path}.part.json');
    var meta = await _json(metaFile);
    var offset = await partialBytesFrom(target, stem, meta);
    if (offset == stem.sizeBytes) return _publish(target, part, metaFile, stem);
    if (offset == 0) {
      await _remove(part);
      await _remove(metaFile);
    }
    onProgress?.call(offset, stem.sizeBytes);
    final abort = Completer<void>();
    final detach = token.listen(() {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      token.check();
      final request = http.AbortableRequest(
        'GET',
        stem.downloadUri,
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers['Accept-Encoding'] = 'identity';
      if (offset > 0) {
        request.headers['Range'] = 'bytes=$offset-';
        request.headers['If-Range'] = _validator(meta)!;
      }
      final response = await Future.any([
        client.send(request),
        token.whenCancelled.then<http.StreamedResponse>(
          (_) => throw const StemDownloadPaused(),
        ),
      ]).timeout(timeout);
      if (response.statusCode == 416 && offset > 0) {
        await _remove(part);
        await _remove(metaFile);
        throw const AlgorithmApiError(
          'partial_invalidated',
          '服务器不再接受该轨的续传区间，正在重新获取这一条音轨',
        );
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        // Abort rather than buffer an arbitrary error body.
        if (!abort.isCompleted) abort.complete();
        throw AlgorithmApiError(
          'download_http_${response.statusCode}',
          response.statusCode == 404 || response.statusCode == 410
              ? '服务器音轨已过期或不存在；本机已完成音轨保留，无需删除或重复下载'
              : '音轨下载失败（HTTP ${response.statusCode}），已保留进度',
          httpStatus: response.statusCode,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      }
      final mime = response.headers['content-type']?.split(';').first.trim();
      if (mime != stem.contentType) {
        throw const FormatException('服务器音轨类型与清单不一致');
      }
      if (response.headers['content-encoding'] != null &&
          response.headers['content-encoding'] != 'identity') {
        throw const FormatException('服务器压缩传输不支持安全续传');
      }
      if (response.statusCode == 206) {
        final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(response.headers['content-range'] ?? '');
        if (offset == 0 ||
            match == null ||
            int.parse(match[1]!) != offset ||
            int.parse(match[2]!) != stem.sizeBytes - 1 ||
            int.parse(match[3]!) != stem.sizeBytes ||
            (response.headers['etag'] != null &&
                meta?['etag'] != null &&
                response.headers['etag'] != meta!['etag'])) {
          await _remove(part);
          await _remove(metaFile);
          throw const FormatException('服务器续传区间或文件版本不一致，已丢弃该轨不可靠片段，请重试');
        }
      } else {
        offset = 0;
      } // Server ignored Range, or If-Range version changed: replace, never append.
      final expected = stem.sizeBytes - offset;
      if (response.contentLength != null &&
          response.contentLength != expected) {
        throw const FormatException('服务器音轨长度与清单不一致');
      }
      final previousEtag = meta?['etag'],
          previousModified = meta?['lastModified'];
      meta = {
        'identity': _identity(stem),
        'etag': response.headers['etag'] ?? (offset > 0 ? previousEtag : null),
        'lastModified':
            response.headers['last-modified'] ??
            (offset > 0 ? previousModified : null),
      };
      // Reset before publishing the new validator, so an old prefix cannot be
      // paired with the new file after a crash.
      final output = await part.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      try {
        await _writeJson(metaFile, meta);
        var received = offset;
        onProgress?.call(received, stem.sizeBytes);
        await for (final chunk in _cancellable(
          response.stream,
          token,
        ).timeout(timeout)) {
          token.check();
          if (received + chunk.length > stem.sizeBytes) {
            await _remove(metaFile);
            throw const FormatException('服务器音轨超出声明大小');
          }
          // Await bounded writes without flushing every network packet.
          await output.writeFrom(chunk);
          received += chunk.length;
          onProgress?.call(received, stem.sizeBytes);
        }
        if (received != stem.sizeBytes) {
          throw const AlgorithmApiError(
            'download_incomplete',
            '音轨传输未完成，已保留进度；可继续下载',
          );
        }
        await output.flush();
      } finally {
        await output.close();
      }
      token.check();
      return await _publish(target, part, metaFile, stem);
    } finally {
      if (!abort.isCompleted) abort.complete();
      detach();
    }
  }

  Future<int> partialBytesFrom(
    File target,
    LegacyStemFile stem,
    Map<String, Object?>? meta,
  ) async {
    final part = File('${target.path}.part');
    if (meta?['identity'] != _identity(stem) ||
        _validator(meta) == null ||
        !await part.exists()) {
      return 0;
    }
    final size = await part.length();
    return size <= stem.sizeBytes ? size : 0;
  }

  Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds != null && seconds > 0 ? Duration(seconds: seconds) : null;
  }

  Future<File> _publish(
    File target,
    File part,
    File meta,
    LegacyStemFile stem,
  ) async {
    try {
      await validateStemAudio(part, stem);
    } on FormatException {
      await _remove(part);
      await _remove(meta);
      rethrow;
    }
    final digest = await _hash(part);
    if (stem.sha256 != null && digest != stem.sha256) {
      await _remove(part);
      await _remove(meta);
      throw const AlgorithmApiError(
        'download_checksum_mismatch',
        '这一轨的文件校验未通过，请重试下载；其他完整音轨已保留，无需重新分析',
      );
    }
    await part.rename(target.path);
    await _writeJson(File('${target.path}.verified.json'), {
      'identity': _identity(stem),
      'sha256': digest,
    });
    final stat = await target.stat();
    _verified[target.path] =
        '${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stem.sha256 ?? ''}';
    await _remove(meta);
    return target;
  }

  Future<Map<String, String>> downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
    int parallelism = 2,
  }) async {
    final id = algorithmId(taskId);
    if (!_batches.add(id)) throw StateError('此任务正在下载');
    try {
      return await _downloadBatch(
        taskId,
        stems,
        cancellation: cancellation,
        onProgress: onProgress,
        parallelism: parallelism,
      );
    } finally {
      _batches.remove(id);
    }
  }

  Future<Map<String, String>> _downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
    required int parallelism,
  }) async {
    if (stems.isEmpty ||
        stems.map((s) => s.id).toSet().length != stems.length ||
        parallelism < 1 ||
        parallelism > 3) {
      throw const FormatException('下载清单无效');
    }
    final token = cancellation ?? StemDownloadCancellation(),
        clock = Stopwatch()..start();
    final received = <String, int>{}, paths = <String, String>{};
    for (final s in stems) {
      token.check();
      final local = await localFile(taskId, s);
      if (local != null) {
        paths[s.id] = local.path;
        received[s.id] = s.sizeBytes;
      } else {
        received[s.id] = await partialBytes(taskId, s);
      }
    }
    final initial = received.values.fold(0, (a, b) => a + b),
        total = stems.fold(0, (a, s) => a + s.sizeBytes);
    var lastNotify = -1000, index = 0;
    void notify({bool force = false}) {
      final ms = clock.elapsedMilliseconds;
      if (!force && ms - lastNotify < 200) return;
      lastNotify = ms;
      final n = received.values.fold(0, (a, b) => a + b);
      onProgress?.call(
        StemDownloadProgress(
          n,
          total,
          paths.length,
          stems.length,
          ms >= 500 && n > initial ? (n - initial) * 1000 / ms : 0,
        ),
      );
    }

    notify(force: true);
    final remaining = stems.where((s) => !paths.containsKey(s.id)).toList();
    Object? failure;
    StackTrace? trace;
    Future<void> worker() async {
      http.Client? connection;
      try {
        connection = clientFactory();
        while (index < remaining.length) {
          token.check();
          final stem = remaining[index++];
          final f = await download(
            taskId,
            stem,
            client: connection,
            cancellation: token,
            onProgress: (n, _) {
              received[stem.id] = n;
              notify();
            },
          );
          paths[stem.id] = f.path;
          notify(force: true);
        }
      } on Object catch (e, st) {
        failure ??= e;
        trace ??= st;
        token.cancel();
      } finally {
        connection?.close();
      }
    }

    await Future.wait(
      List.generate(remaining.length.clamp(0, parallelism), (_) => worker()),
    );
    if (failure != null) Error.throwWithStackTrace(failure!, trace!);
    token.check();
    return {for (final stem in stems) stem.id: paths[stem.id]!};
  }
}

Stream<List<int>> _cancellable(
  Stream<List<int>> source,
  StemDownloadCancellation token,
) {
  StreamSubscription<List<int>>? subscription;
  void Function()? detach;
  late StreamController<List<int>> output;
  output = StreamController<List<int>>(
    onListen: () {
      if (token.isCancelled) {
        output.addError(const StemDownloadPaused());
        unawaited(output.close());
        return;
      }
      subscription = source.listen(
        output.add,
        onError: output.addError,
        onDone: output.close,
      );
      detach = token.listen(() {
        output.addError(const StemDownloadPaused());
        unawaited(output.close());
        unawaited(subscription?.cancel());
      });
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      detach?.call();
      await subscription?.cancel();
    },
  );
  return output.stream;
}

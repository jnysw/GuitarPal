import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/legacy_algorithm_models.dart';

abstract interface class AlgorithmApi {
  Future<void> ping({AlgorithmOperation operation = AlgorithmOperation.chords});
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int sent, int total)? onProgress,
  });
  Future<LegacyAlgorithmStatus> status(
    String jobId,
    AlgorithmOperation operation,
  );
  Future<Map<String, Object?>> result(
    String jobId,
    AlgorithmOperation operation,
  );
  void close();
}

class LegacyAlgorithmApi implements AlgorithmApi {
  LegacyAlgorithmApi(
    this.endpoint, {
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 90),
    this.healthTimeout = const Duration(seconds: 8),
    this.uploadTimeout = const Duration(minutes: 10),
  }) : _client = client ?? http.Client();

  final AlgorithmEndpoint endpoint;
  final http.Client _client;
  final Duration requestTimeout;
  final Duration healthTimeout;
  final Duration uploadTimeout;
  static const maximumInputBytes = 50 * 1024 * 1024;
  bool get _usesTailnet =>
      endpoint.origin.host.toLowerCase().endsWith('.ts.net');
  String get _connectionMessage =>
      _usesTailnet ? '无法连接测试服务，请确认手机已连接 Tailscale 后重试' : '暂时无法连接分析服务，请稍后重试';

  @override
  Future<void> ping({
    AlgorithmOperation operation = AlgorithmOperation.chords,
  }) async {
    final data = await _get(
      '/api/v1/health/ping',
      timeout: healthTimeout < requestTimeout ? healthTimeout : requestTimeout,
    );
    if (data['ping'] != 'pong') throw const FormatException('存活检查响应无效');
    if (operation != AlgorithmOperation.separation) return;
    try {
      final health = await _get(
        '/api/v1/separation/health',
        timeout: healthTimeout < requestTimeout
            ? healthTimeout
            : requestTimeout,
      );
      if (health['status'] == 'unavailable') {
        throw const AlgorithmApiError(
          'model_unavailable',
          '分轨服务尚未就绪，请稍后重试；已下载的音轨仍可使用',
        );
      }
      if (!{'ready', 'not_loaded'}.contains(health['status']) ||
          health['model_loaded'] is! bool ||
          (health['status'] == 'ready' && health['model_loaded'] != true)) {
        throw const FormatException('分轨就绪检查响应无效');
      }
      // Older services may load the model on the first queued job.
    } on AlgorithmApiError catch (e) {
      if (e.httpStatus == 404) {
        return; // Legacy service without this optional route.
      }
      if (e.httpStatus == 503) {
        throw const AlgorithmApiError(
          'model_unavailable',
          '分轨服务尚未就绪，请稍后重试；已下载的音轨仍可使用',
        );
      }
      rethrow;
    }
  }

  @override
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(path);
    late final int length;
    try {
      length = await file.length();
    } on FileSystemException {
      throw const AlgorithmApiError('input_unavailable', '本机音频已失效，请重新选择文件');
    }
    if (length <= 0 || length > maximumInputBytes) {
      throw const AlgorithmApiError('invalid_file_size', '音频必须非空且不超过 50 MiB');
    }
    final safeName = filename
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'[\r\n"]'), '_');
    if (!RegExp(
      r'\.(mp3|wav|flac|ogg|m4a)$',
      caseSensitive: false,
    ).hasMatch(safeName)) {
      throw const AlgorithmApiError(
        'unsupported_format',
        '请选择 MP3、WAV、FLAC、OGG 或 M4A 音频',
      );
    }
    final abort = Completer<void>();
    final query = operation == AlgorithmOperation.chords
        ? {'smooth_method': 'hmm', 'include_raw_chords': 'false'}
        : {'output_format': 'flac16'};
    // Device stays under the server's control; no arbitrary checkpoint/URL.
    final route = operation == AlgorithmOperation.chords
        ? '/api/v1/jobs'
        : '/api/v1/separation/jobs';
    final request = http.AbortableMultipartRequest(
      'POST',
      endpoint.route(route, query),
      abortTrigger: abort.future,
    )..followRedirects = false;
    var sent = 0;
    request.files.add(
      http.MultipartFile(
        'audio',
        file.openRead().map((chunk) {
          sent += chunk.length;
          onProgress?.call(sent, length);
          return chunk;
        }),
        length,
        filename: safeName,
      ),
    );
    late final Map<String, Object?> data;
    try {
      data = await _send(request, abort, 202, timeout: uploadTimeout);
    } on AlgorithmApiError catch (e) {
      if (sent == 0 && {'network_error', 'network_timeout'}.contains(e.code)) {
        throw const AlgorithmApiError('upload_not_sent', '音频尚未发送，请检查连接后重试');
      }
      rethrow;
    }
    try {
      return LegacyUploadReceipt.fromJson(data, endpoint, operation);
    } on FormatException {
      // Preserve a valid ID even when optional receipt metadata has drifted.
      final id = algorithmId(data['job_id']);
      throw AlgorithmReceiptError(id);
    }
  }

  @override
  Future<LegacyAlgorithmStatus> status(
    String jobId,
    AlgorithmOperation operation,
  ) async {
    final value = LegacyAlgorithmStatus.fromJson(
      await _get('${algorithmJobRoot(operation, jobId)}/status'),
      operation,
    );
    if (value.jobId != jobId) throw const FormatException('状态响应任务 ID 不匹配');
    return value;
  }

  @override
  Future<Map<String, Object?>> result(
    String jobId,
    AlgorithmOperation operation,
  ) async {
    final data = await _get('${algorithmJobRoot(operation, jobId)}/result');
    if (data['job_id'] != jobId || data['status'] != 'completed') {
      throw const FormatException('结果响应任务 ID 或状态不匹配');
    }
    if (operation == AlgorithmOperation.chords) {
      LegacyChordResult.fromJson(data);
    } else {
      LegacySeparationResult.fromJson(data, endpoint);
    }
    return data;
  }

  Future<Map<String, Object?>> _get(String path, {Duration? timeout}) {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      endpoint.route(path),
      abortTrigger: abort.future,
    )..followRedirects = false;
    return _send(request, abort, 200, timeout: timeout);
  }

  Future<Map<String, Object?>> _send(
    http.BaseRequest request,
    Completer<void> abort,
    int expected, {
    Duration? timeout,
  }) async {
    Future<Map<String, Object?>> read() async {
      final response = await _client.send(request);
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 8 * 1024 * 1024) {
          if (!abort.isCompleted) abort.complete();
          throw const FormatException('算法服务响应过大');
        }
        bytes.addAll(chunk);
      }
      Map<String, Object?> data;
      try {
        data = algorithmObject(jsonDecode(utf8.decode(bytes)));
      } on FormatException {
        if (response.statusCode != expected) {
          throw AlgorithmApiError(
            'http_${response.statusCode}',
            '算法服务返回 HTTP ${response.statusCode}',
            httpStatus: response.statusCode,
          );
        }
        rethrow;
      }
      if (response.statusCode != expected) {
        final delay = int.tryParse(response.headers['retry-after'] ?? '');
        throw AlgorithmApiError(
          data['error'] is String
              ? data['error'] as String
              : 'http_${response.statusCode}',
          data['detail'] is String ? data['detail'] as String : '算法服务请求失败',
          httpStatus: response.statusCode,
          retryAfter: delay != null && delay > 0
              ? Duration(seconds: delay)
              : null,
        );
      }
      return data;
    }

    try {
      return await read().timeout(
        timeout ?? requestTimeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw AlgorithmApiError(
            'network_timeout',
            request.method == 'POST'
                ? '请求超时；服务器可能已接收，请勿自动重复上传'
                : _usesTailnet
                ? '分析服务响应超时，请确认 Tailscale 连接后重试'
                : '分析服务响应超时，请稍后重试',
          );
        },
      );
    } on http.ClientException {
      throw AlgorithmApiError('network_error', _connectionMessage);
    } on SocketException {
      throw AlgorithmApiError('network_error', _connectionMessage);
    }
  }

  @override
  void close() => _client.close();
}

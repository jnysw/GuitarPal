/// The Windows handoff API is deliberately isolated from GuitarPal /v1.
/// Its chord coordinates are relative to silence-trimmed audio, not the source.
enum AlgorithmOperation { chords, separation }

enum LegacyJobState { queued, processing, completed, failed }

class AlgorithmEndpoint {
  AlgorithmEndpoint(String value, {required bool allowLocalHttp}) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        !['', '/', '/api/v1', '/api/v1/'].contains(parsed.path) ||
        (parsed.scheme != 'https' &&
            !(allowLocalHttp &&
                parsed.scheme == 'http' &&
                _privateHost(parsed.host)))) {
      throw const FormatException('请输入 HTTPS 服务地址；调试版也支持局域网 HTTP 地址');
    }
    origin = parsed.replace(path: '', query: null, fragment: null);
  }

  late final Uri origin;

  Uri route(String path, [Map<String, String>? query]) =>
      origin.resolve(path).replace(queryParameters: query);

  Uri checkedRelativeUrl(String value, String expectedPath) {
    final relative = Uri.tryParse(value);
    if (relative == null ||
        relative.hasScheme ||
        relative.hasAuthority ||
        relative.path != expectedPath ||
        relative.hasQuery ||
        relative.hasFragment) {
      throw const FormatException('服务器返回了不符合任务约定的地址');
    }
    return origin.resolve(value);
  }

  static bool _privateHost(String host) {
    if (host == 'localhost' || host == '::1') return true;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    final a = parts[0]!, b = parts[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 100 && b >= 64 && b <= 127);
  }
}

class AlgorithmApiError implements Exception {
  const AlgorithmApiError(
    this.code,
    this.message, {
    this.httpStatus,
    this.retryAfter,
  });
  final String code;
  final String message;
  final int? httpStatus;
  final Duration? retryAfter;
  bool get isTemporary =>
      httpStatus == 429 ||
      (httpStatus ?? 0) >= 500 ||
      code == 'network_error' ||
      code == 'network_timeout';
  @override
  String toString() => message;
}

class LegacyUploadReceipt {
  LegacyUploadReceipt.fromJson(
    Map<String, Object?> json,
    AlgorithmEndpoint endpoint,
    AlgorithmOperation operation,
  ) : jobId = algorithmId(json['job_id']) {
    if (json['status'] != 'queued') throw const FormatException('任务接收状态无效');
    final root = algorithmJobRoot(operation, jobId);
    endpoint.checkedRelativeUrl(
      algorithmText(json['poll_url']),
      '$root/status',
    );
    endpoint.checkedRelativeUrl(
      algorithmText(json['result_url']),
      '$root/result',
    );
  }
  final String jobId;
}

class LegacyAlgorithmStatus {
  LegacyAlgorithmStatus.fromJson(
    Map<String, Object?> json,
    AlgorithmOperation operation,
  ) : jobId = algorithmId(json['job_id']),
      state = LegacyJobState.values.byName(algorithmText(json['status'])),
      message = algorithmText(json['message'], allowEmpty: true),
      progress = json['progress'] == null
          ? null
          : algorithmInteger(json['progress']) {
    if (progress != null && (progress! < 0 || progress! > 100)) {
      throw const FormatException('服务器任务进度无效');
    }
    final rawError = json['error'];
    if (rawError != null) {
      error = operation == AlgorithmOperation.chords
          ? algorithmText(rawError)
          : algorithmText(algorithmObject(rawError)['message']);
    }
    if (state == LegacyJobState.completed && progress != 100) {
      throw const FormatException('完成任务必须返回 100 的阶段进度');
    }
  }
  final String jobId;
  final LegacyJobState state;
  final String message;
  final int? progress;
  String? error;
}

class LegacyChordSegment {
  LegacyChordSegment.fromJson(Map<String, Object?> json)
    : rawLabel = algorithmText(json['chord']),
      roman = algorithmText(json['roman'], allowEmpty: true),
      start = algorithmSeconds(json['start']),
      end = algorithmSeconds(json['end']) {
    if (end <= start) throw const FormatException('和弦片段长度无效');
  }
  final String rawLabel;
  final String roman;
  final Duration start;
  final Duration end;
  // v1 supplies synthetic 1.0; never expose it as model confidence.
  double? get confidence => null;
  String get displayLabel => displayLegacyChord(rawLabel);
}

class LegacyChordResult {
  LegacyChordResult.fromJson(Map<String, Object?> json)
    : jobId = algorithmId(json['job_id']),
      declaredDuration = algorithmSeconds(json['duration_seconds']),
      keyEstimate = algorithmText(json['key'], allowEmpty: true),
      progression = algorithmText(json['progression'], allowEmpty: true),
      segments = List.unmodifiable(
        algorithmList(json['segments'])
            .map((s) => LegacyChordSegment.fromJson(algorithmObject(s))),
      ) {
    if (json['status'] != 'completed' || declaredDuration <= Duration.zero) {
      throw const FormatException('和弦结果尚未完成或时长无效');
    }
    var end = Duration.zero;
    for (final segment in segments) {
      // Measured v1 output may end one/two analysis frames past its duration
      // header (7.850s vs 7.895s). Preserve both the header and raw intervals;
      // allow only a bounded tail difference, never overlaps or reordered data.
      if (segment.start < end ||
          segment.start >= declaredDuration ||
          segment.end > declaredDuration + const Duration(milliseconds: 50)) {
        throw const FormatException('和弦结果区间乱序、重叠或越界');
      }
      end = segment.end;
    }
  }
  final String jobId;
  final Duration declaredDuration;
  Duration get duration => declaredDuration;
  Duration get coverageEnd =>
      segments.isEmpty ? Duration.zero : segments.last.end;
  bool get hasTailTimingDifference => coverageEnd > declaredDuration;
  final String keyEstimate;
  final String progression;
  final List<LegacyChordSegment> segments;
  bool get canSyncWithOriginal => false;
}

class LegacyStemFile {
  LegacyStemFile.fromJson(
    Map<String, Object?> json,
    AlgorithmEndpoint endpoint,
    String jobId,
  ) : id = algorithmText(json['id']),
      origin = algorithmText(json['origin']),
      sizeBytes = algorithmInteger(json['size_bytes']),
      duration = algorithmSeconds(json['duration_seconds']),
      sampleRate = algorithmInteger(json['sample_rate']),
      channels = algorithmInteger(json['channels']),
      contentType = algorithmText(json['content_type']) {
    if (!{
          'bass',
          'drums',
          'other',
          'vocals',
          'guitar',
          'piano',
          'instrumental',
        }.contains(id) ||
        origin != (id == 'instrumental' ? 'derived' : 'model') ||
        sizeBytes <= 0 ||
        sizeBytes > 256 * 1024 * 1024 ||
        duration <= Duration.zero ||
        duration > const Duration(minutes: 10) ||
        sampleRate <= 0 ||
        !{1, 2}.contains(channels) ||
        !{'audio/wav', 'audio/flac'}.contains(json['content_type'])) {
      throw const FormatException('分轨文件元数据无效');
    }
    downloadUri = endpoint.checkedRelativeUrl(
      algorithmText(json['download_url']),
      '${algorithmJobRoot(AlgorithmOperation.separation, jobId)}/files/$id',
    );
  }
  final String id;
  final String origin;
  final int sizeBytes;
  final Duration duration;
  final int sampleRate;
  final int channels;
  final String contentType;
  String get extension => contentType == 'audio/flac' ? 'flac' : 'wav';
  String get displayName => const {
    'vocals': '人声',
    'drums': '鼓',
    'bass': '贝斯',
    'guitar': '吉他',
    'piano': '钢琴',
    'other': '其他',
    'instrumental': '伴奏',
  }[id]!;
  late final Uri downloadUri;
}

class LegacySeparationResult {
  LegacySeparationResult.fromJson(
    Map<String, Object?> json,
    AlgorithmEndpoint endpoint,
  ) : jobId = algorithmId(json['job_id']),
      expiresAt = DateTime.parse(algorithmText(json['expires_at'])).toUtc(),
      duration = algorithmSeconds(json['duration_seconds']) {
    if (json['status'] != 'completed' ||
        duration <= Duration.zero ||
        duration > const Duration(minutes: 10)) {
      throw const FormatException('分轨结果状态或时长无效');
    }
    stems = List.unmodifiable(
      algorithmList(json['stems']).map(
        (s) => LegacyStemFile.fromJson(algorithmObject(s), endpoint, jobId),
      ),
    );
    if (stems.length != 7 ||
        stems.map((s) => s.id).toSet().length != 7 ||
        stems.any((s) => (s.duration - duration).inMilliseconds.abs() > 100)) {
      throw const FormatException('分轨结果必须包含七条完整且时长一致的音轨');
    }
  }
  final String jobId;
  final DateTime expiresAt;
  final Duration duration;
  late final List<LegacyStemFile> stems;
}

String algorithmJobRoot(AlgorithmOperation operation, String jobId) =>
    '/api/v1/${operation == AlgorithmOperation.separation ? 'separation/' : ''}jobs/${algorithmId(jobId)}';

String algorithmId(Object? value) {
  final id = algorithmText(value);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
    throw const FormatException('任务 ID 无效');
  }
  return id;
}

String algorithmText(Object? value, {bool allowEmpty = false}) {
  if (value is! String ||
      value.length > 4096 ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw const FormatException('算法服务文本字段无效');
  }
  return value;
}

int algorithmInteger(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value != value.roundToDouble()) {
    throw const FormatException('算法服务整数字段无效');
  }
  return value.toInt();
}

Duration algorithmSeconds(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 36000) {
    throw const FormatException('算法服务时间字段无效');
  }
  return Duration(milliseconds: (value * 1000).round());
}

Map<String, Object?> algorithmObject(Object? value) {
  if (value is! Map<String, Object?>) throw const FormatException('算法服务对象字段无效');
  return value;
}

List<Object?> algorithmList(Object? value) {
  if (value is! List || value.length > 20000) {
    throw const FormatException('算法结果列表无效');
  }
  return value;
}

String displayLegacyChord(String label) {
  if (label == 'N') return '无和弦';
  if (label == 'X') return '未知';
  final match = RegExp(r'^([A-G](?:#|b)?):([^/]+)(/[^/]+)?$').firstMatch(label);
  if (match == null) return label;
  final suffix = {
    'maj': '',
    'min': 'm',
    '7': '7',
    'maj7': 'maj7',
    'min7': 'm7',
    'maj6': '6',
    'min6': 'm6',
    'minmaj7': 'm(maj7)',
    'hdim7': 'm7♭5',
    'dim': 'dim',
    'dim7': 'dim7',
    'aug': 'aug',
    'sus2': 'sus2',
    'sus4': 'sus4',
  }[match.group(2)];
  return suffix == null
      ? label
      : '${match.group(1)}$suffix${match.group(3) ?? ''}';
}

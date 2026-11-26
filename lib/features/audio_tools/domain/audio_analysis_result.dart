import 'audio_time_mapping.dart';

enum AudioJobStatus {
  created,
  queued,
  running,
  retryWait,
  cancelRequested,
  succeeded,
  partiallySucceeded,
  failed,
  canceled;

  bool get isTerminal => switch (this) {
    succeeded || partiallySucceeded || failed || canceled => true,
    _ => false,
  };

  static AudioJobStatus parse(Object? value) => switch (value) {
    'created' => created,
    'queued' => queued,
    'running' => running,
    'retry_wait' => retryWait,
    'cancel_requested' => cancelRequested,
    'succeeded' => succeeded,
    'partially_succeeded' => partiallySucceeded,
    'failed' => failed,
    'canceled' => canceled,
    _ => throw const FormatException('未知音频任务状态'),
  };
}

class UnsupportedAudioResultVersion implements Exception {
  const UnsupportedAudioResultVersion(this.version);
  final Object? version;
}

class ChordSegment {
  const ChordSegment._({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.rawLabel,
    required this.chordKey,
    required this.displayLabel,
    required this.confidence,
    required this.origin,
    required this.roman,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String rawLabel;
  final String chordKey;
  final String displayLabel;
  final double? confidence;
  final String origin;
  final String? roman;

  bool get isNoChord => chordKey == 'N';
  bool get isUnknown => chordKey == 'X';
  bool get canRecommendVoicing => !isNoChord && !isUnknown;
  bool contains(int positionMs) => startMs <= positionMs && positionMs < endMs;

  factory ChordSegment.fromJson(Map<String, Object?> json) {
    final start = _integer(json, 'start_ms');
    final end = _integer(json, 'end_ms');
    if (end <= start) throw const FormatException('和弦区间必须为正长度');
    final chordKey = _text(json, 'chord_key');
    final rawLabel = _text(json, 'raw_label');
    final origin = _text(json, 'origin');
    if (origin == 'machine' &&
        (rawLabel == 'N' || rawLabel == 'X') &&
        chordKey != rawLabel) {
      throw const FormatException('无和弦和未知标签不能互相转换');
    }
    if (origin != 'machine' && origin != 'human') {
      throw const FormatException('和弦来源无效');
    }
    return ChordSegment._(
      id: _text(json, 'id'),
      startMs: start,
      endMs: end,
      rawLabel: rawLabel,
      chordKey: chordKey,
      displayLabel: _text(json, 'display_label'),
      confidence: _probability(json['confidence']),
      origin: origin,
      roman: _optionalText(json['roman']),
    );
  }
}

/// Validated chord branch in source-media coordinates, ready for offline use.
/// This is a protocol model; it does not start jobs or fabricate predictions.
class ChordAnalysisResult {
  ChordAnalysisResult._({
    required this.jobId,
    required this.assetId,
    required this.mediaRevisionId,
    required this.analysisId,
    required this.profileId,
    required this.status,
    required this.revision,
    required this.mapping,
    required this.segments,
    required this.confidenceMethod,
  });

  final String jobId;
  final String assetId;
  final String mediaRevisionId;
  final String analysisId;
  final String profileId;
  final AudioJobStatus status;
  final int revision;
  final AudioTimeMapping mapping;
  final List<ChordSegment> segments;
  final String? confidenceMethod;

  factory ChordAnalysisResult.fromJson(Map<String, Object?> json) {
    if (json['schema_version'] is! int || json['schema_version'] != 1) {
      throw UnsupportedAudioResultVersion(json['schema_version']);
    }
    if (json['timebase'] != 'source_media_ms') {
      throw const FormatException('和弦结果必须使用原媒体坐标');
    }
    final status = AudioJobStatus.parse(json['status']);
    if (status != AudioJobStatus.succeeded &&
        status != AudioJobStatus.partiallySucceeded) {
      throw const FormatException('任务尚无可用结果');
    }
    final separation = json['separation'];
    if (status == AudioJobStatus.succeeded &&
        separation != null &&
        _object(separation)['status'] != 'succeeded') {
      throw const FormatException('全部成功状态不能包含失败分支');
    }
    final coverage = _object(json['coverage']);
    final wireMapping = _object(json['mapping']);
    final mapping = AudioTimeMapping(
      sourceOffsetMs: _integer(wireMapping, 'source_offset_ms'),
      inputDurationMs:
          _integer(coverage, 'end_ms') - _integer(coverage, 'start_ms'),
      trimStartMs: _integer(wireMapping, 'trim_start_ms'),
    );
    if (_integer(coverage, 'start_ms') != mapping.sourceOffsetMs) {
      throw const FormatException('覆盖范围与上传区间不一致');
    }
    final chords = _object(json['chords']);
    if (chords['input_kind'] != 'original') {
      throw const FormatException('当前版本只支持原曲和弦结果');
    }
    final confidenceMethod = _optionalText(chords['confidence_method']);
    final rawSegments = chords['segments'];
    if (rawSegments is! List || rawSegments.length > 20000) {
      throw const FormatException('和弦分段列表无效或过大');
    }
    final segments = rawSegments
        .map((value) => ChordSegment.fromJson(_object(value)))
        .toList(growable: false);
    var previousEnd = mapping.sourceOffsetMs;
    final ids = <String>{};
    for (final segment in segments) {
      if (!ids.add(segment.id) ||
          segment.startMs < previousEnd ||
          segment.endMs > mapping.coverageEndMs) {
        throw const FormatException('和弦区间重复、重叠、乱序或越界');
      }
      if (segment.confidence != null && confidenceMethod == null) {
        throw const FormatException('模型置信度必须注明真实聚合方法');
      }
      previousEnd = segment.endMs;
    }
    final revision = _integer(chords, 'revision');
    if (revision == 0) throw const FormatException('结果修订号必须大于 0');
    return ChordAnalysisResult._(
      jobId: _text(json, 'job_id'),
      assetId: _text(json, 'asset_id'),
      mediaRevisionId: _text(json, 'media_revision_id'),
      analysisId: _text(chords, 'analysis_id'),
      profileId: _text(chords, 'profile_id'),
      status: status,
      revision: revision,
      mapping: mapping,
      segments: List.unmodifiable(segments),
      confidenceMethod: confidenceMethod,
    );
  }

  /// Binary search uses the media clock directly, including seeks/A-B jumps.
  /// A gap and the right-open boundary never retain the preceding chord.
  ChordSegment? currentAt(int sourcePositionMs) {
    final index = _lastStartingAtOrBefore(sourcePositionMs);
    if (index < 0) return null;
    final segment = segments[index];
    return segment.contains(sourcePositionMs) ? segment : null;
  }

  ChordSegment? nextAt(int sourcePositionMs) {
    final index = _lastStartingAtOrBefore(sourcePositionMs) + 1;
    return index < segments.length ? segments[index] : null;
  }

  int _lastStartingAtOrBefore(int positionMs) {
    var lower = 0;
    var upper = segments.length;
    while (lower < upper) {
      final middle = (lower + upper) ~/ 2;
      if (segments[middle].startMs <= positionMs) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    return lower - 1;
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('音频协议对象无效');
  }
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key 必须为非负整数');
  }
  return value;
}

String _text(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw FormatException('$key 无效');
  }
  return value;
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw const FormatException('可选文本字段无效');
  }
  return value;
}

double? _probability(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException('模型置信度必须在 0–1 之间或为 null');
  }
  return value.toDouble();
}

import 'dart:io';

import 'legacy_algorithm_models.dart';

/// Extracted input coordinates, independent of statistical source associations.
class VideoAnalysisBinding {
  VideoAnalysisBinding({
    required this.sourceId,
    required this.path,
    required this.sourceBytes,
    required this.modifiedMs,
    required this.sourceDurationMs,
    required this.startMs,
    required this.durationMs,
    required this.inputSha256,
    required this.waveform,
    this.manualChordZeroMs,
  }) {
    if (startMs < 0 ||
        durationMs < 2000 ||
        durationMs > 600000 ||
        startMs + durationMs > sourceDurationMs ||
        sourceBytes <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(inputSha256) ||
        waveform.length > 240 ||
        waveform.any((v) => !v.isFinite || v < 0 || v > 1)) {
      throw const FormatException('视频分析映射无效');
    }
    if (manualChordZeroMs != null &&
        (manualChordZeroMs! < startMs || manualChordZeroMs! > endMs)) {
      throw const FormatException('和弦人工校准超出分析区间');
    }
  }
  final String sourceId, path, inputSha256;
  final int sourceBytes, modifiedMs, sourceDurationMs, startMs, durationMs;
  final List<double> waveform;
  final int? manualChordZeroMs;
  VideoAnalysisBinding withChordZero(int zero) => VideoAnalysisBinding(
    sourceId: sourceId,
    path: path,
    sourceBytes: sourceBytes,
    modifiedMs: modifiedMs,
    sourceDurationMs: sourceDurationMs,
    startMs: startMs,
    durationMs: durationMs,
    inputSha256: inputSha256,
    waveform: waveform,
    manualChordZeroMs: zero,
  );
  int get endMs => startMs + durationMs;
  bool matches(String id, String filePath, FileStat stat) =>
      sourceId == id &&
      path == filePath &&
      stat.type == FileSystemEntityType.file &&
      stat.size == sourceBytes &&
      stat.modified.millisecondsSinceEpoch == modifiedMs;
  Map<String, Object?> toJson() => {
    'version': 1,
    'sourceId': sourceId,
    'path': path,
    'sourceBytes': sourceBytes,
    'modifiedMs': modifiedMs,
    'sourceDurationMs': sourceDurationMs,
    'startMs': startMs,
    'durationMs': durationMs,
    'inputSha256': inputSha256,
    'waveform': waveform,
    'manualChordZeroMs': manualChordZeroMs,
  };
  factory VideoAnalysisBinding.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) throw const FormatException('视频映射版本不支持');
    return VideoAnalysisBinding(
      sourceId: algorithmText(json['sourceId']),
      path: algorithmText(json['path']),
      sourceBytes: algorithmInteger(json['sourceBytes']),
      modifiedMs: algorithmInteger(json['modifiedMs']),
      sourceDurationMs: algorithmInteger(json['sourceDurationMs']),
      startMs: algorithmInteger(json['startMs']),
      durationMs: algorithmInteger(json['durationMs']),
      inputSha256: algorithmText(json['inputSha256']),
      manualChordZeroMs: json['manualChordZeroMs'] == null
          ? null
          : algorithmInteger(json['manualChordZeroMs']),
      waveform: algorithmList(json['waveform']).map((v) {
        if (v is! num) throw const FormatException('波形无效');
        return v.toDouble();
      }).toList(),
    );
  }
}

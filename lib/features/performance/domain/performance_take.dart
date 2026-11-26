import 'dart:convert';

import '../../audio_tools/domain/legacy_algorithm_models.dart';
import 'backing_preset.dart';

/// Immutable local capture journal. Raw microphone audio is never replaced by a mix.
class PerformanceTake {
  PerformanceTake._(this._json, this.preset);
  final Map<String, Object?> _json;
  final BackingPreset preset;
  String get id => _json['id'] as String;
  String get sourceId => preset.sourceId;
  bool get trial => _json['trial'] == true;
  int get durationMs => (_json['durationMs'] as num).toInt();
  int get endSourceMs => (_json['endSourceMs'] as num).toInt();
  int? get leadMs => (_json['leadMs'] as num?)?.toInt();
  int get alignmentMs => (_json['alignmentMs'] as num).toInt();
  DateTime get createdAt => DateTime.parse(_json['createdAt'] as String);
  String get filePath => 'practice_recordings/$id.m4a';
  String get reason => _json['reason'] as String;
  Map<String, Object?> toJson() =>
      jsonDecode(jsonEncode({..._json, 'preset': preset.toJson()}))
          as Map<String, Object?>;
  PerformanceTake update(Map<String, Object?> changes) =>
      PerformanceTake.fromJson({...toJson(), ...changes});
  factory PerformanceTake.begin(
    String id,
    PerformanceCandidate c,
    BackingPreset p, {
    required bool trial,
  }) => PerformanceTake.fromJson({
    'version': 1,
    'id': id,
    'preset': p.toJson(),
    'trial': trial,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'durationMs': 0,
    'endSourceMs': p.startMs,
    'leadMs': null,
    'alignmentMs': 0,
    'sourcePath': c.binding.path,
    'sourceBytes': c.binding.sourceBytes,
    'modifiedMs': c.binding.modifiedMs,
    'reason': 'capturing',
    'timingMethod': 'command-ack-and-hardware-head-estimate',
    'deviceLatencyCalibrated': false,
  });
  factory PerformanceTake.fromJson(Map<String, Object?> m) {
    if (m['version'] != 1) throw const FormatException('演奏录音版本暂不支持');
    algorithmId(m['id']);
    final p = BackingPreset.fromJson(algorithmObject(m['preset']));
    for (final key in [
      'durationMs',
      'endSourceMs',
      'alignmentMs',
      'sourceBytes',
      'modifiedMs',
    ]) {
      if (m[key] is! num ||
          !(m[key] as num).isFinite ||
          (m[key] as num).toInt() != m[key]) {
        throw const FormatException('演奏录音时间信息无效');
      }
    }
    final d = (m['durationMs'] as num).toInt(),
        end = (m['endSourceMs'] as num).toInt();
    if (d < 0 ||
        d > 1250000 ||
        end < p.startMs ||
        end > p.startMs + p.durationMs ||
        (m['alignmentMs'] as num).abs() > 2000 ||
        m['trial'] is! bool ||
        m['sourcePath'] is! String ||
        m['reason'] is! String ||
        DateTime.tryParse(m['createdAt'] as String? ?? '') == null) {
      throw const FormatException('演奏录音快照无效');
    }
    if (m['leadMs'] != null &&
        (m['leadMs'] is! num ||
            !(m['leadMs'] as num).isFinite ||
            (m['leadMs'] as num).abs() > 10000)) {
      throw const FormatException('录音起点估计无效');
    }
    for (final key in ['reviewMicVolume', 'reviewBackingVolume']) {
      if (m[key] != null &&
          (m[key] is! num ||
              !(m[key] as num).isFinite ||
              (m[key] as num) < 0 ||
              (m[key] as num) > 1)) {
        throw const FormatException('回听音量无效');
      }
    }
    // Deeply detach device lists and nested maps via the JSON storage boundary.
    return PerformanceTake._(
      Map.unmodifiable(jsonDecode(jsonEncode(m)) as Map<String, Object?>),
      p,
    );
  }
  void verifyCandidate(PerformanceCandidate c) {
    preset.validateAgainst(c);
    if (_json['sourcePath'] != c.binding.path ||
        _json['sourceBytes'] != c.binding.sourceBytes ||
        _json['modifiedMs'] != c.binding.modifiedMs) {
      throw const FormatException('原视频已变化，只能回听麦克风录音');
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../domain/practice_source/practice_source.dart';
import '../../audio_tools/domain/algorithm_task.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/stem_mix_settings.dart';
import '../../audio_tools/domain/video_analysis_binding.dart';
import '../../audio_tools/domain/video_stem_choice.dart';

class PerformanceCandidate {
  PerformanceCandidate._(this.task, this.binding, this.result);
  final AlgorithmTaskRecord task;
  final VideoAnalysisBinding binding;
  final LegacySeparationResult result;
  String get manifestHash =>
      sha256.convert(utf8.encode(task.resultJson!)).toString();
  bool get wholeSong =>
      binding.startMs == 0 &&
      (binding.endMs - binding.sourceDurationMs).abs() <= 100;
  static PerformanceCandidate? fromTask(
    PracticeSource source,
    FileStat stat,
    AlgorithmTaskRecord task,
  ) {
    try {
      if (source.platform != SourcePlatform.local ||
          source.kind != SourceKind.video ||
          task.operation != AlgorithmOperation.separation ||
          task.state != AlgorithmTaskState.completed ||
          task.linkedSourceId != source.id ||
          task.resultJson == null ||
          task.mediaBindingJson == null) {
        return null;
      }
      final binding = VideoAnalysisBinding.fromJson(
        algorithmObject(jsonDecode(task.mediaBindingJson!)),
      );
      if (!binding.matches(
        source.id,
        source.canonicalUri!.toFilePath(),
        stat,
      )) {
        return null;
      }
      final result = LegacySeparationResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
        AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
      );
      if (task.remoteJobId != null && result.jobId != task.remoteJobId) {
        return null;
      }
      if ((result.duration.inMilliseconds - binding.durationMs).abs() > 100) {
        return null;
      }
      return PerformanceCandidate._(task, binding, result);
    } on Object {
      return null;
    }
  }
}

Set<String> performanceBackingTracks(
  LegacySeparationResult result, {
  bool omitGuitar = false,
  bool omitVocals = false,
}) {
  final ids = result.stems
      .where((s) => s.origin == 'model')
      .map((s) => s.id)
      .toSet();
  if ((omitGuitar && !ids.contains('guitar')) ||
      (omitVocals && !ids.contains('vocals'))) {
    throw const FormatException('此结果没有对应的独立音轨');
  }
  if (omitGuitar) ids.remove('guitar');
  if (omitVocals) ids.remove('vocals');
  videoStemSubset(result, ids);
  return ids;
}

class BackingPreset {
  BackingPreset({
    required this.sourceId,
    required this.taskId,
    required this.inputSha256,
    required this.manifestHash,
    required this.startMs,
    required this.durationMs,
    required Map<String, StemMixControl> controls,
    this.master = .8,
    this.speed = 1,
  }) : controls = Map.unmodifiable(controls) {
    algorithmId(sourceId);
    algorithmId(taskId);
    if (![
          inputSha256,
          manifestHash,
        ].every((s) => RegExp(r'^[a-f0-9]{64}$').hasMatch(s)) ||
        startMs < 0 ||
        durationMs < 2000 ||
        durationMs > 600000 ||
        controls.isEmpty ||
        controls.length > 16 ||
        !master.isFinite ||
        master < 0 ||
        master > 1 ||
        !speed.isFinite ||
        speed < .5 ||
        speed > 2 ||
        (speed * 100 - (speed * 100).round()).abs() > .00001) {
      throw const FormatException('伴奏方案无效');
    }
    for (final e in controls.entries) {
      algorithmId(e.key);
      StemMixControl.fromJson(e.value.toJson());
    }
  }
  final String sourceId, taskId, inputSha256, manifestHash;
  final int startMs, durationMs;
  final Map<String, StemMixControl> controls;
  final double master, speed;
  factory BackingPreset.forCandidate(
    PerformanceCandidate c,
    Iterable<String> ids,
  ) => BackingPreset(
    sourceId: c.binding.sourceId,
    taskId: c.task.id,
    inputSha256: c.binding.inputSha256,
    manifestHash: c.manifestHash,
    startMs: c.binding.startMs,
    durationMs: c.binding.durationMs,
    controls: {
      for (final id in videoStemSubset(c.result, ids).map((s) => s.id))
        id: const StemMixControl(),
    },
  );
  bool matches(PerformanceCandidate c) =>
      sourceId == c.binding.sourceId &&
      taskId == c.task.id &&
      inputSha256 == c.binding.inputSha256 &&
      manifestHash == c.manifestHash &&
      startMs == c.binding.startMs &&
      durationMs == c.binding.durationMs;
  void validateAgainst(PerformanceCandidate c) {
    if (!matches(c)) throw const FormatException('伴奏方案对应的来源或结果已变化');
    videoStemSubset(c.result, controls.keys);
  }

  BackingPreset copyWith({
    Map<String, StemMixControl>? controls,
    double? master,
    double? speed,
  }) => BackingPreset(
    sourceId: sourceId,
    taskId: taskId,
    inputSha256: inputSha256,
    manifestHash: manifestHash,
    startMs: startMs,
    durationMs: durationMs,
    controls: controls ?? this.controls,
    master: master ?? this.master,
    speed: speed ?? this.speed,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'sourceId': sourceId,
    'taskId': taskId,
    'inputSha256': inputSha256,
    'manifestHash': manifestHash,
    'startMs': startMs,
    'durationMs': durationMs,
    'controls': controls.map((id, c) => MapEntry(id, c.toJson())),
    'master': master,
    'speed': speed,
  };
  factory BackingPreset.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) throw const FormatException('伴奏方案版本不支持');
    return BackingPreset(
      sourceId: algorithmId(json['sourceId']),
      taskId: algorithmId(json['taskId']),
      inputSha256: algorithmText(json['inputSha256']),
      manifestHash: algorithmText(json['manifestHash']),
      startMs: algorithmInteger(json['startMs']),
      durationMs: algorithmInteger(json['durationMs']),
      controls: algorithmObject(json['controls']).map(
        (id, c) => MapEntry(id, StemMixControl.fromJson(algorithmObject(c))),
      ),
      master: (json['master'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
    );
  }
}

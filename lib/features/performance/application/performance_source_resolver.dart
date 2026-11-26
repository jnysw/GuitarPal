import 'dart:io';

import '../../../domain/practice_source/practice_source.dart';
import '../../../domain/practice_source/practice_source_repository.dart';
import '../../audio_tools/data/algorithm_task_repository.dart';
import '../domain/backing_preset.dart';

class PerformanceBacking {
  const PerformanceBacking(this.source, this.candidate, this.preset);
  final PracticeSource source;
  final PerformanceCandidate candidate;
  final BackingPreset preset;
}

class PerformanceSourceResolver {
  const PerformanceSourceResolver(this.sources, this.tasks);
  final PracticeSourceRepository sources;
  final AlgorithmTaskRepository tasks;
  Future<PerformanceCandidate> lookup(String sourceId, String taskId) async {
    final source = await sources.getById(sourceId),
        task = await tasks.get(taskId);
    if (source == null ||
        task == null ||
        source.canonicalUri?.scheme != 'file') {
      throw const FormatException('歌曲或分轨已不存在，请返回准备页');
    }
    final candidate = PerformanceCandidate.fromTask(
      source,
      await File(source.canonicalUri!.toFilePath()).stat(),
      task,
    );
    if (candidate == null) throw const FormatException('来源或分轨已变化，请返回准备页重新选择');
    return candidate;
  }

  Future<void> verify(PerformanceCandidate c) async {
    final latest = await lookup(c.binding.sourceId, c.task.id);
    if (latest.manifestHash != c.manifestHash ||
        latest.binding.inputSha256 != c.binding.inputSha256 ||
        latest.binding.startMs != c.binding.startMs ||
        latest.binding.durationMs != c.binding.durationMs) {
      throw const FormatException('伴奏版本或区间已变化，请返回准备页');
    }
  }

  Future<PerformanceBacking> resolve(
    String sourceId,
    BackingPreset preset,
  ) async {
    if (preset.sourceId != sourceId) throw const FormatException('伴奏方案不属于此歌曲');
    final candidate = await lookup(sourceId, preset.taskId);
    preset.validateAgainst(candidate);
    final source = await sources.getById(sourceId);
    if (source == null) throw const FormatException('歌曲已不存在');
    return PerformanceBacking(source, candidate, preset);
  }
}

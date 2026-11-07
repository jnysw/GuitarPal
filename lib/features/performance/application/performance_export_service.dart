import 'dart:convert';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../audio_tools/domain/video_stem_choice.dart';
import '../data/performance_export_platform.dart';
import '../domain/performance_take.dart';
import 'performance_source_resolver.dart';

/// Frozen saved take -> local, verified inputs. Deliberately has no download API.
class PerformanceExportService {
  const PerformanceExportService(
    this.recorder,
    this.store,
    this.resolver,
    this.platform,
  );
  final PracticeAudioRecorder recorder;
  final AlgorithmStemStore store;
  final PerformanceSourceResolver resolver;
  final PerformanceExportPlatform platform;

  Future<void> verify(
    PerformanceTake take,
    Map<String, Object?> snapshot, {
    required bool withBacking,
  }) async {
    final latest = await prepare(take, withBacking: withBacking);
    if (jsonEncode(latest) != jsonEncode(snapshot)) {
      throw const FormatException('导出期间伴奏文件已变化，请重新打开成果后重试');
    }
  }

  Future<Map<String, Object?>> prepare(
    PerformanceTake take, {
    required bool withBacking,
  }) async {
    if (take.trial || take.durationMs <= 0) {
      throw const FormatException('请先保存一条演奏成果');
    }
    if (withBacking && take.preset.speed != 1) {
      throw const FormatException('当前混音导出支持 1.00× 伴奏；此成果仍可仅导出录音');
    }
    await recorder.resolveAbsolutePath(take.filePath);
    final tracks = <Map<String, Object?>>[];
    if (withBacking) {
      final c = await resolver.lookup(take.sourceId, take.preset.taskId);
      take.verifyCandidate(c);
      final solo = take.preset.controls.values.any((s) => s.solo);
      for (final stem in videoStemSubset(c.result, take.preset.controls.keys)) {
        final file = await store.localFile(c.task.id, stem);
        if (file == null) {
          throw const FormatException('本机伴奏不完整，请返回准备页补齐音轨，或选择仅导出录音');
        }
        final control = take.preset.controls[stem.id]!;
        tracks.add({
          'path': file.path,
          'gain': control.muted || (solo && !control.solo)
              ? 0.0
              : control.volume,
          'pan': control.pan,
        });
      }
      await resolver.verify(c);
    }
    final settings = take.toJson();
    final actual = take.endSourceMs - take.preset.startMs;
    return {
      'takeId': take.id,
      'durationMs': take.durationMs,
      'speed': take.preset.speed,
      'leadMs': take.leadMs ?? 0,
      'alignmentMs': take.alignmentMs,
      'backingEndMs': actual.clamp(0, take.preset.durationMs),
      'backingDurationMs': take.preset.durationMs,
      'micGain': (settings['reviewMicVolume'] as num?)?.toDouble() ?? 1.0,
      'backingGain':
          take.preset.master *
          ((settings['reviewBackingVolume'] as num?)?.toDouble() ?? 1.0),
      'tracks': tracks,
    };
  }
}

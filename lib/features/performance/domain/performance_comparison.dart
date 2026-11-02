import 'dart:convert';
import 'dart:math' as math;

import '../../../domain/practice_recording/practice_recording.dart';
import 'performance_take.dart';

/// Original-media coordinates shared by two saved, unmodified microphone files.
/// This aligns the stored start estimates, not detected musical attacks.
class PerformanceComparison {
  PerformanceComparison(this.first, this.second) {
    final a = first.take, b = second.take;
    if (a.id == b.id || a.sourceId != b.sourceId) {
      throw const FormatException('请选择同一首歌的两条不同演奏');
    }
    for (final key in ['sourcePath', 'sourceBytes', 'modifiedMs']) {
      if (a.toJson()[key] != b.toJson()[key]) {
        throw const FormatException('两次录制的原视频版本不同，请分别回听');
      }
    }
    startMs = math.max(_start(a), _start(b)).ceil();
    endMs = math.min(_end(a), _end(b)).floor();
    if (endMs - startMs < 1000) {
      throw const FormatException('两次演奏没有至少一秒的共同区间，请分别回听');
    }
  }

  final PerformanceComparisonEntry first, second;
  late final int startMs, endMs;
  PerformanceComparisonEntry entry(int index) => index == 0 ? first : second;
  int get durationMs => endMs - startMs;
  bool get differentSpeeds =>
      first.take.preset.speed != second.take.preset.speed;

  static double _start(PerformanceTake t) => math.max(
    t.preset.startMs.toDouble(),
    t.preset.startMs + (-t.leadMs! + t.alignmentMs) * t.preset.speed,
  );
  static double _end(PerformanceTake t) => math.min(
    t.endSourceMs.toDouble(),
    t.preset.startMs +
        (t.durationMs - t.leadMs! + t.alignmentMs) * t.preset.speed,
  );

  int recordingAt(int index, int sourceMs) {
    final t = entry(index).take;
    return ((sourceMs.clamp(startMs, endMs) - t.preset.startMs) /
                t.preset.speed +
            t.leadMs! -
            t.alignmentMs)
        .round()
        .clamp(0, t.durationMs);
  }

  int sourceAt(int index, int recordingMs) {
    final t = entry(index).take;
    return (t.preset.startMs +
            (recordingMs - t.leadMs! + t.alignmentMs) * t.preset.speed)
        .round()
        .clamp(startMs, endMs);
  }
}

class PerformanceComparisonEntry {
  PerformanceComparisonEntry._(this.recording, this.take);
  final PracticeRecording recording;
  final PerformanceTake take;

  factory PerformanceComparisonEntry.fromRecording(PracticeRecording r) {
    if (r.kind != PracticeRecordingKind.performanceTake ||
        r.performanceContextJson == null) {
      throw const FormatException('请选择已保存的演奏录音');
    }
    final t = PerformanceTake.fromJson(
      jsonDecode(r.performanceContextJson!) as Map<String, Object?>,
    );
    if (t.trial ||
        t.id != r.id ||
        t.sourceId != r.sourceId ||
        t.filePath != r.filePath ||
        t.durationMs != r.duration.inMilliseconds) {
      throw const FormatException('演奏信息不一致，请分别回听');
    }
    if (t.leadMs == null || t.endSourceMs <= t.preset.startMs) {
      throw const FormatException('录音缺少起点估计，暂不能按原曲位置对比，请分别回听');
    }
    return PerformanceComparisonEntry._(r, t);
  }
}

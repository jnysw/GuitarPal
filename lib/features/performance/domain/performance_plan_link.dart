import 'dart:convert';

import '../../../domain/practice_plan/practice_plan.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../../../domain/practice_segment/practice_segment.dart';
import 'performance_take.dart';

PerformanceTake savedPerformanceTake(PracticeRecording recording) {
  if (recording.kind != PracticeRecordingKind.performanceTake ||
      recording.performanceContextJson == null) {
    throw const FormatException('请先保存正式演奏，再关联计划');
  }
  final take = PerformanceTake.fromJson(
    jsonDecode(recording.performanceContextJson!) as Map<String, Object?>,
  );
  if (take.trial ||
      take.id != recording.id ||
      take.sourceId != recording.sourceId ||
      take.filePath != recording.filePath ||
      take.durationMs != recording.duration.inMilliseconds) {
    throw const FormatException('演奏信息不一致，请重新打开录音');
  }
  return take;
}

/// Outcomes describe the actual captured interval; they never complete a goal.
String? performancePlanLinkIssue(
  PerformanceTake take,
  PracticePlan plan,
  PracticeSegment? segment,
) {
  if (plan.sourceId != take.sourceId) return '计划属于另一首曲目';
  if (take.endSourceMs <= take.preset.startMs) return '没有可确认的原曲录制区间';
  if (plan.segmentId != null) {
    if (segment == null ||
        segment.id != plan.segmentId ||
        segment.sourceId != take.sourceId) {
      return '计划片段已不存在';
    }
    if (take.preset.startMs < segment.start.inMilliseconds ||
        take.endSourceMs > segment.end.inMilliseconds) {
      return '录制区间超出此片段，可选择整曲计划';
    }
  }
  return null;
}

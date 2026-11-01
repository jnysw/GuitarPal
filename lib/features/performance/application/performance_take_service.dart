import 'dart:convert';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../../../domain/practice_recording/practice_recording_repository.dart';
import '../data/performance_audio_platform.dart';
import '../data/performance_take_store.dart';
import '../domain/performance_take.dart';

class PerformanceTakeService {
  PerformanceTakeService(this.store, this.recordings, this.audio, this.extra);
  final PerformanceTakeStore store;
  final PracticeRecordingRepository recordings;
  final PracticeAudioRecorder audio;
  final PerformanceAudioPlatform extra;
  Future<PerformanceTake> recover(String id) async {
    final saved = await recordings.getById(id);
    if (saved?.performanceContextJson != null) {
      return PerformanceTake.fromJson(
        jsonDecode(saved!.performanceContextJson!) as Map<String, Object?>,
      );
    }
    final draft = await store.load(id);
    if (draft == null) throw const FormatException('未找到演奏录音草稿');
    if (draft.durationMs > 0) {
      await audio.resolveAbsolutePath(draft.filePath);
      return draft;
    }
    final result = await extra.recover(id);
    final take = draft.update({
      'durationMs': result.duration.inMilliseconds,
      'reason': 'recovered',
    });
    await store.save(take);
    return take;
  }

  Future<void> save(PerformanceTake take, String title) async {
    if (take.trial || take.durationMs <= 0) {
      throw const FormatException('试录不作为演奏成果保存');
    }
    await audio.resolveAbsolutePath(take.filePath);
    await recordings.save(
      PracticeRecording(
        id: take.id,
        sourceId: take.sourceId,
        kind: PracticeRecordingKind.performanceTake,
        filePath: take.filePath,
        duration: Duration(milliseconds: take.durationMs),
        referenceStart: Duration(milliseconds: take.preset.startMs),
        referenceEnd: take.endSourceMs > take.preset.startMs
            ? Duration(milliseconds: take.endSourceMs)
            : null,
        referenceSpeed: take.preset.speed,
        title: title.trim(),
        recordedAt: take.createdAt,
        performanceContextJson: jsonEncode(take.toJson()),
      ),
    );
    // A failed journal cleanup cannot undo a committed recording. Reopening checks DB first.
    try {
      await store.delete(take.id);
    } on Object {
      /* Preserve the committed audio and permit a later cleanup retry. */
    }
  }

  Future<void> discard(PerformanceTake take) async {
    if (await recordings.getById(take.id) != null) {
      throw StateError('已保存录音请从历史列表删除');
    }
    await audio.deleteRecording(take.filePath);
    await store.delete(take.id);
  }
}

import 'package:flutter/services.dart';

import '../../../core/platform/practice_audio_recorder.dart';

/// Extra capture metadata. Times are command acknowledgements, not sample timestamps.
class PerformanceAudioPlatform {
  const PerformanceAudioPlatform();
  static const channel = MethodChannel(
    'com.guitarpal/practice_audio_recording',
  );
  Future<Map<String, Object?>> environment() async => (await channel
      .invokeMapMethod<String, Object?>('performanceEnvironment'))!;
  Future<Map<String, Object?>> start(String id) async =>
      (await channel.invokeMapMethod<String, Object?>('startPerformance', {
        'recordingId': id,
      }))!;
  Future<PracticeAudioRecordingResult> recover(String id) async {
    final m = (await channel.invokeMapMethod<String, Object?>(
      'recoverPerformance',
      {'recordingId': id},
    ))!;
    return PracticeAudioRecordingResult(
      relativePath: m['relativePath'] as String,
      absolutePath: m['absolutePath'] as String,
      duration: Duration(
        milliseconds: (m['durationMilliseconds'] as num).toInt(),
      ),
    );
  }

  Future<void> play(String path, int position, double volume) =>
      channel.invokeMethod('playRecording', {
        'relativePath': path,
        'positionMilliseconds': position,
        'volume': volume,
      });
  Future<void> setVolume(double volume) =>
      channel.invokeMethod('setPlaybackVolume', {'volume': volume});
}

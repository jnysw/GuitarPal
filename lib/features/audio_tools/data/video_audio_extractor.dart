import 'package:flutter/services.dart';

import 'algorithm_audio_import.dart';
import '../domain/legacy_algorithm_models.dart';

class ExtractedVideoAudio {
  const ExtractedVideoAudio(this.input, this.sha256, this.waveform);
  final AlgorithmAudioInput input;
  final String sha256;
  final List<double> waveform;
}

class VideoAudioExtractor {
  const VideoAudioExtractor();
  static const _channel = MethodChannel('com.guitarpal/algorithm_audio_import');
  Future<ExtractedVideoAudio> extract(
    String path,
    int startMs,
    int endMs,
  ) async {
    final json = (await _channel.invokeMapMethod<String, Object?>(
      'extractVideoAudio',
      {'path': path, 'startMs': startMs, 'endMs': endMs},
    ))!;
    return ExtractedVideoAudio(
      AlgorithmAudioInput(
        path: algorithmText(json['path']),
        name: 'video-audio.wav',
        sizeBytes: algorithmInteger(json['sizeBytes']),
        duration: Duration(milliseconds: algorithmInteger(json['durationMs'])),
      ),
      algorithmText(json['sha256']),
      algorithmList(json['waveform'])
          .map((v) => (v as num).toDouble())
          .toList(),
    );
  }
}

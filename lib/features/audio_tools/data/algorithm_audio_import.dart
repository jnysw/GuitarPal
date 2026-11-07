import 'package:flutter/services.dart';

import '../domain/legacy_algorithm_models.dart';

class AlgorithmAudioInput {
  const AlgorithmAudioInput({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.duration,
    this.owned = true,
    this.recordingId,
  });
  final String path;
  final String name;
  final int sizeBytes;
  final Duration duration;
  final bool owned;
  final String? recordingId;
}

abstract interface class AlgorithmAudioImport {
  Future<AlgorithmAudioInput?> pickAudio();
  Future<void> deleteInput(String path);
}

class MethodChannelAlgorithmAudioImport implements AlgorithmAudioImport {
  const MethodChannelAlgorithmAudioImport([
    this.channel = const MethodChannel('com.guitarpal/algorithm_audio_import'),
  ]);
  final MethodChannel channel;
  @override
  Future<AlgorithmAudioInput?> pickAudio() async {
    final data = await channel.invokeMapMethod<String, Object?>('pickAudio');
    if (data == null) return null;
    final size = algorithmInteger(data['sizeBytes']);
    final duration = algorithmInteger(data['durationMs']);
    if (size <= 0 ||
        size > 50 * 1024 * 1024 ||
        duration < 2000 ||
        duration > 600000) {
      throw const FormatException('音频大小或时长不符合分析限制');
    }
    return AlgorithmAudioInput(
      path: algorithmText(data['path']),
      name: algorithmText(data['name']),
      sizeBytes: size,
      duration: Duration(milliseconds: duration),
    );
  }

  @override
  Future<void> deleteInput(String path) =>
      channel.invokeMethod<void>('deleteInput', {'path': path});
}

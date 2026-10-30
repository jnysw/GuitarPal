import 'package:flutter/services.dart';

/// Build/deployment-owned configuration. End users never enter service origins.
class AlgorithmServiceConfiguration {
  const AlgorithmServiceConfiguration();
  static const _channel = MethodChannel('com.guitarpal/algorithm_audio_import');
  Future<String> load() async {
    final values = await _channel.invokeMapMethod<String, Object?>(
      'serviceConfiguration',
    );
    final value = values?['baseUrl'];
    return value is String ? value.trim() : '';
  }
}

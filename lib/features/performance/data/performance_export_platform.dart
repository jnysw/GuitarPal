import 'package:flutter/services.dart';

class PerformanceExportResult {
  const PerformanceExportResult({
    required this.id,
    required this.bytes,
    required this.durationMs,
    required this.attenuation,
  });
  final String id;
  final int bytes, durationMs;
  final double attenuation;
  factory PerformanceExportResult.fromJson(Map<String, Object?> m) =>
      PerformanceExportResult(
        id: m['id'] as String,
        bytes: (m['bytes'] as num).toInt(),
        durationMs: (m['durationMs'] as num).toInt(),
        attenuation: (m['attenuation'] as num).toDouble(),
      );
}

class PerformanceExportPlatform {
  const PerformanceExportPlatform();
  static const channel = MethodChannel('com.guitarpal/performance_export');
  Future<PerformanceExportResult> render(Map<String, Object?> snapshot) async =>
      PerformanceExportResult.fromJson(
        (await channel.invokeMapMethod<String, Object?>('render', snapshot))!,
      );
  Future<Map<String, Object?>> snapshot() async =>
      (await channel.invokeMapMethod<String, Object?>('snapshot'))!;
  Future<void> discard(String id) =>
      channel.invokeMethod('discard', {'id': id});
  Future<void> cancel() => channel.invokeMethod('cancel');
  Future<void> play(String id) => channel.invokeMethod('play', {'id': id});
  Future<void> stop() => channel.invokeMethod('stop');
  Future<void> share(String id) => channel.invokeMethod('share', {'id': id});
  Future<bool> save(String id, String title) async =>
      await channel.invokeMethod<bool>('save', {'id': id, 'title': title}) ??
      false;
}

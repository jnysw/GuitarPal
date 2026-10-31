import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/legacy_algorithm_models.dart';
import '../domain/stem_mix_settings.dart';

class AlgorithmMixPlatform {
  const AlgorithmMixPlatform();
  static const _channel = MethodChannel('com.guitarpal/algorithm_mix');
  Future<void> load(Map<String, String> paths) =>
      _channel.invokeMethod('load', {
        'tracks': paths.entries
            .map((e) => {'id': e.key, 'path': e.value})
            .toList(),
      });
  Future<void> play() => _channel.invokeMethod('play');
  Future<void> pause() => _channel.invokeMethod('pause');
  Future<void> stop() => _channel.invokeMethod('stop');
  Future<void> seek(int positionMs) =>
      _channel.invokeMethod('seek', {'positionMs': positionMs});
  Future<void> configure(
    StemMixSettings settings,
    Iterable<String> loadedIds,
  ) => _channel.invokeMethod(
    'configure',
    settings.platformConfiguration(loadedIds),
  );

  /// Dynamic manifest controls used by performance preview; never writes mix preferences.
  Future<void> configureTracks(
    Map<String, StemMixControl> controls, {
    required double master,
    required double speed,
  }) {
    if (controls.isEmpty ||
        controls.length > 16 ||
        !master.isFinite ||
        master < 0 ||
        master > 1 ||
        !speed.isFinite ||
        speed < .5 ||
        speed > 2) {
      throw const FormatException('混音设置无效');
    }
    for (final e in controls.entries) {
      algorithmId(e.key);
      StemMixControl.fromJson(e.value.toJson());
    }
    final solo = controls.values.any((c) => c.solo);
    return _channel.invokeMethod('configure', {
      'gains': controls.map(
        (id, c) => MapEntry(id, c.muted || (solo && !c.solo) ? 0.0 : c.volume),
      ),
      'pans': controls.map((id, c) => MapEntry(id, c.pan)),
      'master': master,
      'speed': speed,
      'loopStartMs': null,
      'loopEndMs': null,
    });
  }

  Future<Map<String, Object?>> snapshot() async =>
      (await _channel.invokeMapMethod<String, Object?>('snapshot'))!;
}

class StemMixPreferences {
  StemMixPreferences(this.directory);
  final Future<Directory> Function() directory;
  final Set<String> _saving = {};
  Future<File> _file(String taskId) async =>
      File('${(await directory()).path}/${algorithmId(taskId)}_mix.json');
  Future<StemMixSettings?> load(String taskId, int durationMs) async {
    final file = await _file(taskId);
    if (!await file.exists()) return null;
    if (await file.length() > 32 * 1024) {
      throw const FormatException('本机练习设置过大');
    }
    return StemMixSettings.fromJson(
      algorithmObject(jsonDecode(await file.readAsString())),
      durationMs,
    );
  }

  Future<void> save(String taskId, StemMixSettings settings) async {
    if (!_saving.add(taskId)) throw StateError('练习设置正在保存');
    File? temporary;
    try {
      final file = await _file(taskId);
      await file.parent.create(recursive: true);
      temporary = File('${file.path}.part');
      await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      _saving.remove(taskId);
    }
  }
}

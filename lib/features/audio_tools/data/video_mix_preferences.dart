import 'dart:convert';
import 'dart:io';

import '../domain/legacy_algorithm_models.dart';
import '../domain/video_mix_selection.dart';

/// Serialized atomic writes in private storage; not part of the metadata sync outbox.
class VideoMixPreferences {
  VideoMixPreferences(this.root);
  final Future<Directory> Function() root;
  final Map<String, Future<void>> _tails = {};
  final Set<String> _deleted = {};
  Future<T> _enqueue<T>(String sourceId, Future<T> Function() action) {
    algorithmId(sourceId);
    final result = (_tails[sourceId] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[sourceId] = settled;
    settled.then((_) {
      if (identical(_tails[sourceId], settled)) _tails.remove(sourceId);
    });
    return result;
  }

  Future<File> _file(String sourceId) async => File(
    '${(await root()).path}/video_workspace/${algorithmId(sourceId)}.json',
  );
  Future<VideoMixSelection?> load(String sourceId) => _enqueue(
    sourceId,
    () async {
      if (_deleted.contains(sourceId)) return null;
      final file = await _file(sourceId);
      if (!await file.exists()) return null;
      if (await file.length() > 32768) throw const FormatException('视频分轨设置过大');
      return VideoMixSelection.fromJson(
        algorithmObject(jsonDecode(await file.readAsString())),
      );
    },
  );
  Future<void> save(String sourceId, VideoMixSelection value) {
    // Capture the immutable payload before entering the write queue.
    final json = jsonEncode(
      VideoMixSelection.fromJson(value.toJson()).toJson(),
    );
    return _enqueue(sourceId, () async {
      if (_deleted.contains(sourceId)) throw StateError('曲目已删除');
      final file = await _file(sourceId);
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      try {
        await part.writeAsString(json, flush: true);
        await part.rename(file.path);
      } finally {
        if (await part.exists()) await part.delete();
      }
    });
  }

  Future<void> delete(String sourceId) {
    algorithmId(sourceId);
    _deleted.add(sourceId);
    return _enqueue(sourceId, () async {
      final file = await _file(sourceId);
      for (final entry in [file, File('${file.path}.part')]) {
        if (await entry.exists()) await entry.delete();
      }
    });
  }
}

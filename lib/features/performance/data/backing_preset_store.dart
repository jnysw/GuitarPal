import 'dart:convert';
import 'dart:io';

import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../domain/backing_preset.dart';

class BackingPresetStore {
  BackingPresetStore(this.root);
  final Future<Directory> Function() root;
  final Map<String, Future<void>> _tails = {};
  final Set<String> _deleted = {};
  Future<T> _queue<T>(String id, Future<T> Function() work) {
    algorithmId(id);
    final action = (_tails[id] ?? Future<void>.value()).then((_) => work());
    final settled = action.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[id] = settled;
    settled.then((_) {
      if (identical(_tails[id], settled)) _tails.remove(id);
    });
    return action;
  }

  Future<File> _file(String id) async => File(
    '${(await root()).path}/performance_backings/${algorithmId(id)}.json',
  );
  Future<BackingPreset?> load(String id) => _queue(id, () async {
    if (_deleted.contains(id)) return null;
    final f = await _file(id);
    if (!await f.exists()) return null;
    if (await f.length() > 65536) throw const FormatException('伴奏方案过大');
    final p = BackingPreset.fromJson(
      algorithmObject(jsonDecode(await f.readAsString())),
    );
    if (p.sourceId != id) throw const FormatException('伴奏方案不属于此歌曲');
    return p;
  });
  Future<void> save(BackingPreset p) {
    final payload = jsonEncode(BackingPreset.fromJson(p.toJson()).toJson());
    return _queue(p.sourceId, () async {
      if (_deleted.contains(p.sourceId)) throw StateError('歌曲已删除');
      final f = await _file(p.sourceId);
      await f.parent.create(recursive: true);
      final part = File('${f.path}.part');
      try {
        await part.writeAsString(payload, flush: true);
        await part.rename(f.path);
      } finally {
        if (await part.exists()) await part.delete();
      }
    });
  }

  Future<void> delete(String id) {
    algorithmId(id);
    _deleted.add(id);
    return _queue(id, () async {
      final f = await _file(id);
      for (final file in [f, File('${f.path}.part')]) {
        if (await file.exists()) await file.delete();
      }
    });
  }
}

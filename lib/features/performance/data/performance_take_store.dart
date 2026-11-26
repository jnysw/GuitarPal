import 'dart:convert';
import 'dart:io';

import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../domain/performance_take.dart';

class PerformanceTakeStore {
  PerformanceTakeStore(this.root);
  final Future<Directory> Function() root;
  Future<void> _tail = Future.value();
  final Set<String> _deleted = {};
  Future<T> _queue<T>(Future<T> Function() run) {
    final work = _tail.then((_) => run());
    _tail = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<Directory> _dir() async =>
      Directory('${(await root()).path}/performance_drafts');
  Future<File> _file(String id) async =>
      File('${(await _dir()).path}/${algorithmId(id)}.json');
  Future<void> save(PerformanceTake take) => _queue(() async {
    if (_deleted.contains(take.id)) throw StateError('录音草稿已结束');
    final payload = jsonEncode(
      PerformanceTake.fromJson(take.toJson()).toJson(),
    );
    if (payload.length > 65536) throw const FormatException('录音快照过大');
    final file = await _file(take.id);
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    try {
      await part.writeAsString(payload, flush: true);
      await part.rename(file.path);
    } finally {
      if (await part.exists()) await part.delete();
    }
  });
  Future<PerformanceTake?> load(String id) => _queue(() async {
    if (_deleted.contains(id)) return null;
    final f = await _file(id);
    if (!await f.exists()) return null;
    if (await f.length() > 65536) throw const FormatException('录音草稿过大');
    final take = PerformanceTake.fromJson(
      algorithmObject(jsonDecode(await f.readAsString())),
    );
    if (take.id != id) throw const FormatException('录音草稿身份不一致');
    return take;
  });
  Future<List<PerformanceTake>> list(String sourceId) => _queue(() async {
    algorithmId(sourceId);
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final result = <PerformanceTake>[];
    await for (final f in dir.list(followLinks: false)) {
      if (f is! File || !f.path.endsWith('.json') || await f.length() > 65536) {
        continue;
      }
      try {
        final t = PerformanceTake.fromJson(
          algorithmObject(jsonDecode(await f.readAsString())),
        );
        if (t.sourceId == sourceId &&
            f.uri.pathSegments.last == '${t.id}.json') {
          result.add(t);
        }
      } on FormatException {
        continue;
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  });
  Future<void> delete(String id) {
    algorithmId(id);
    _deleted.add(id);
    return _queue(() async {
      final f = await _file(id);
      if (await f.exists()) await f.delete();
    });
  }
}

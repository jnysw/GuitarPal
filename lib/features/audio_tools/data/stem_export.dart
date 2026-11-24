import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'algorithm_stem_store.dart';
import '../domain/legacy_algorithm_models.dart';

class StemExport {
  const StemExport();

  static const _channel = MethodChannel('com.guitarpal/performance_export');

  Future<bool> save({
    required AlgorithmStemStore store,
    required String taskId,
    required LegacySeparationResult result,
    required Set<String> trackIds,
    required String title,
    required StemDownloadCancellation cancellation,
    required void Function(StemDownloadProgress) onDownload,
    required void Function() onPreparing,
  }) async {
    final tracks = result.stems
        .where((stem) => trackIds.contains(stem.id))
        .toList();
    if (tracks.isEmpty || tracks.length != trackIds.length) {
      throw const FormatException('请选择要导出的音轨');
    }
    final bytes = tracks.fold(0, (sum, stem) => sum + stem.sizeBytes);
    if (bytes > 0xffffffff - 65536) {
      throw const FormatException('所选音轨过大，请分批导出');
    }
    final paths = <String, String>{};
    for (final track in tracks) {
      cancellation.check();
      final file = await store.localFile(taskId, track);
      if (file != null) paths[track.id] = file.path;
    }
    final missing = tracks
        .where((track) => !paths.containsKey(track.id))
        .toList();
    if (missing.isNotEmpty) {
      if (!DateTime.now().toUtc().isBefore(result.expiresAt)) {
        throw const FormatException('服务器音轨已到期，请选择已下载的音轨');
      }
      paths.addAll(
        await store.downloadBatch(
          taskId,
          missing,
          cancellation: cancellation,
          onProgress: onDownload,
        ),
      );
    }

    cancellation.check();
    onPreparing();
    final directory = await _channel.invokeMethod<String>(
      'stemExportDirectory',
    );
    if (directory == null) throw StateError('导出目录不可用');
    final id = const Uuid().v4();
    final extension = tracks.length == 1 ? tracks.single.extension : 'zip';
    final target = File('$directory/$id.$extension');
    final temporary = '${target.path}.part';
    final entries = [
      for (final (index, track) in tracks.indexed)
        (
          path: paths[track.id]!,
          name:
              '${(index + 1).toString().padLeft(2, '0')}-${track.id}.${track.extension}',
          size: track.sizeBytes,
        ),
    ];
    try {
      await Isolate.run(() => _stageExport(temporary, entries));
      cancellation.check();
      await File(temporary).rename(target.path);
      cancellation.check();
      return await _channel.invokeMethod<bool>('saveStemExport', {
            'id': id,
            'extension': extension,
            'title': tracks.length == 1
                ? '${tracks.single.displayName} - $title'
                : '$title - 分轨',
          }) ??
          false;
    } finally {
      await _deleteTemporary(temporary);
      await _deleteTemporary(target.path);
    }
  }
}

Future<void> _stageExport(
  String destination,
  List<({String path, String name, int size})> entries,
) async {
  if (entries.length == 1) {
    final entry = entries.single;
    final copy = await File(entry.path).copy(destination);
    if (await copy.length() != entry.size) {
      throw const FormatException('音轨文件不完整，请重新选择');
    }
    return;
  }
  final zip = ZipFileEncoder()..create(destination);
  try {
    for (final entry in entries) {
      final file = File(entry.path);
      if (await file.length() != entry.size) {
        throw const FormatException('音轨文件不完整，请重新选择');
      }
      await zip.addFile(file, entry.name, ZipFileEncoder.STORE);
    }
  } finally {
    await zip.close();
  }
}

Future<void> _deleteTemporary(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // The native export directory also expires abandoned temporary files.
  }
}

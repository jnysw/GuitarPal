import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LocalVideoPickOrigin { gallery, files }

class LocalVideoFileInfo {
  const LocalVideoFileInfo({
    required this.path,
    required this.displayName,
    required this.sizeBytes,
    required this.duration,
    this.width,
    this.height,
  });

  final String path;
  final String displayName;
  final int sizeBytes;
  final Duration duration;
  final int? width;
  final int? height;
}

abstract interface class LocalVideoGateway {
  Future<LocalVideoFileInfo?> pickVideo(LocalVideoPickOrigin origin);

  Future<LocalVideoFileInfo> commitDraft({
    required String draftPath,
    required String sourceId,
  });

  Future<void> discardDraft(String draftPath);

  Future<void> deleteManagedVideo(String path);
}

class MethodChannelLocalVideoGateway implements LocalVideoGateway {
  const MethodChannelLocalVideoGateway([
    this._channel = const MethodChannel('com.guitarpal/local_video_import'),
  ]);

  final MethodChannel _channel;

  @override
  Future<LocalVideoFileInfo?> pickVideo(LocalVideoPickOrigin origin) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickVideo',
      {'source': origin.name},
    );
    return result == null ? null : _decode(result);
  }

  @override
  Future<LocalVideoFileInfo> commitDraft({
    required String draftPath,
    required String sourceId,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'commitDraft',
      {'draftPath': draftPath, 'sourceId': sourceId},
    );
    if (result == null) {
      throw PlatformException(code: 'commit_failed', message: '没有收到已保存视频的信息');
    }
    return _decode(result);
  }

  @override
  Future<void> discardDraft(String draftPath) {
    return _channel.invokeMethod<void>('discardDraft', {'path': draftPath});
  }

  @override
  Future<void> deleteManagedVideo(String path) {
    return _channel.invokeMethod<void>('deleteManagedVideo', {'path': path});
  }

  LocalVideoFileInfo _decode(Map<String, Object?> value) {
    final path = value['path'];
    final displayName = value['displayName'];
    if (path is! String || path.isEmpty || displayName is! String) {
      throw const FormatException('本地视频信息不完整');
    }

    return LocalVideoFileInfo(
      path: path,
      displayName: displayName,
      sizeBytes: _toInt(value['sizeBytes']) ?? 0,
      duration: Duration(
        milliseconds: _toInt(value['durationMilliseconds']) ?? 0,
      ),
      width: _toInt(value['width']),
      height: _toInt(value['height']),
    );
  }

  int? _toInt(Object? value) => value is num ? value.toInt() : null;
}

final localVideoGatewayProvider = Provider<LocalVideoGateway>((ref) {
  return const MethodChannelLocalVideoGateway();
});

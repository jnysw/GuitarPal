import 'package:flutter/services.dart';

enum MicrophonePermissionStatus { granted, denied, permanentlyDenied }

class PracticeAudioRecordingResult {
  const PracticeAudioRecordingResult({
    required this.relativePath,
    required this.absolutePath,
    required this.duration,
  });

  final String relativePath;
  final String absolutePath;
  final Duration duration;
}

class PracticeAudioPlaybackSnapshot {
  const PracticeAudioPlaybackSnapshot({
    required this.isLoaded,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  final bool isLoaded;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
}

abstract interface class PracticeAudioRecorder {
  Future<MicrophonePermissionStatus> permissionStatus();

  Future<MicrophonePermissionStatus> requestPermission();

  Future<void> openAppSettings();

  Future<void> start({required String recordingId});

  Future<PracticeAudioRecordingResult> stop();

  Future<void> cancel();

  Future<bool> isRecording();

  Future<void> playRecording(
    String relativePath, {
    Duration position = Duration.zero,
  });

  Future<void> pausePlayback();

  Future<void> seekPlayback(Duration position);

  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot();

  Future<void> stopPlayback();

  Future<String> resolveAbsolutePath(String relativePath);

  Future<void> deleteRecording(String relativePath);
}

class MethodChannelPracticeAudioRecorder implements PracticeAudioRecorder {
  const MethodChannelPracticeAudioRecorder([
    this._channel = const MethodChannel(
      'com.guitarpal/practice_audio_recording',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<MicrophonePermissionStatus> permissionStatus() async {
    final value = await _channel.invokeMethod<String>('permissionStatus');
    return _decodePermission(value);
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    final value = await _channel.invokeMethod<String>('requestPermission');
    return _decodePermission(value);
  }

  @override
  Future<void> openAppSettings() {
    return _channel.invokeMethod<void>('openAppSettings');
  }

  @override
  Future<void> start({required String recordingId}) {
    return _channel.invokeMethod<void>('start', {'recordingId': recordingId});
  }

  @override
  Future<PracticeAudioRecordingResult> stop() async {
    final value = await _channel.invokeMapMethod<String, Object?>('stop');
    if (value == null) {
      throw const FormatException('没有收到录音文件信息');
    }
    final relativePath = value['relativePath'];
    final absolutePath = value['absolutePath'];
    final durationMilliseconds = value['durationMilliseconds'];
    if (relativePath is! String ||
        relativePath.isEmpty ||
        absolutePath is! String ||
        absolutePath.isEmpty ||
        durationMilliseconds is! num ||
        durationMilliseconds <= 0) {
      throw const FormatException('录音文件信息不完整');
    }
    return PracticeAudioRecordingResult(
      relativePath: relativePath,
      absolutePath: absolutePath,
      duration: Duration(milliseconds: durationMilliseconds.toInt()),
    );
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  @override
  Future<bool> isRecording() async {
    return await _channel.invokeMethod<bool>('isRecording') ?? false;
  }

  @override
  Future<void> playRecording(
    String relativePath, {
    Duration position = Duration.zero,
  }) {
    return _channel.invokeMethod<void>('playRecording', {
      'relativePath': relativePath,
      'positionMilliseconds': position.inMilliseconds,
    });
  }

  @override
  Future<void> pausePlayback() {
    return _channel.invokeMethod<void>('pausePlayback');
  }

  @override
  Future<void> seekPlayback(Duration position) {
    return _channel.invokeMethod<void>('seekPlayback', {
      'positionMilliseconds': position.inMilliseconds,
    });
  }

  @override
  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'playbackSnapshot',
    );
    if (value == null) {
      throw const FormatException('没有收到录音播放状态');
    }
    final isLoaded = value['isLoaded'];
    final isPlaying = value['isPlaying'];
    final positionMilliseconds = value['positionMilliseconds'];
    final durationMilliseconds = value['durationMilliseconds'];
    if (isLoaded is! bool ||
        isPlaying is! bool ||
        positionMilliseconds is! num ||
        durationMilliseconds is! num) {
      throw const FormatException('录音播放状态不完整');
    }
    return PracticeAudioPlaybackSnapshot(
      isLoaded: isLoaded,
      isPlaying: isPlaying,
      position: Duration(milliseconds: positionMilliseconds.toInt()),
      duration: Duration(milliseconds: durationMilliseconds.toInt()),
    );
  }

  @override
  Future<void> stopPlayback() {
    return _channel.invokeMethod<void>('stopPlayback');
  }

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    final path = await _channel.invokeMethod<String>('resolveAbsolutePath', {
      'relativePath': relativePath,
    });
    if (path == null || path.isEmpty) {
      throw const FormatException('无法解析录音文件路径');
    }
    return path;
  }

  @override
  Future<void> deleteRecording(String relativePath) {
    return _channel.invokeMethod<void>('deleteRecording', {
      'relativePath': relativePath,
    });
  }

  MicrophonePermissionStatus _decodePermission(String? value) {
    return switch (value) {
      'granted' => MicrophonePermissionStatus.granted,
      'denied' => MicrophonePermissionStatus.denied,
      'permanentlyDenied' => MicrophonePermissionStatus.permanentlyDenied,
      _ => throw FormatException('未知的麦克风权限状态：$value'),
    };
  }
}

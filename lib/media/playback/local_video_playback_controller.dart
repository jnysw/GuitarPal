import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'loop_controller.dart';
import 'playback_speed.dart';
import 'playback_volume.dart';

typedef LocalVideoStateListener = void Function(Map<String, Object?> state);

abstract interface class LocalVideoPlayerBridge {
  void setStateListener(LocalVideoStateListener? listener);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> setVolume(double volume);

  Future<void> requestSnapshot();

  Future<void> dispose();
}

class MethodChannelLocalVideoPlayerBridge implements LocalVideoPlayerBridge {
  MethodChannelLocalVideoPlayerBridge(int viewId)
    : _channel = MethodChannel('com.guitarpal/local_video_player/$viewId') {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;
  LocalVideoStateListener? _listener;

  @override
  void setStateListener(LocalVideoStateListener? listener) {
    _listener = listener;
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method != 'state') return null;
    final arguments = call.arguments;
    if (arguments is! Map) return null;
    _listener?.call(
      arguments.map((key, value) => MapEntry(key.toString(), value)),
    );
    return null;
  }

  @override
  Future<void> play() => _channel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> seek(Duration position) => _channel.invokeMethod<void>(
    'seekTo',
    {'milliseconds': position.inMilliseconds},
  );

  @override
  Future<void> setSpeed(double speed) =>
      _channel.invokeMethod<void>('setSpeed', {'speed': speed});

  @override
  Future<void> setVolume(double volume) =>
      _channel.invokeMethod<void>('setVolume', {'volume': volume});

  @override
  Future<void> requestSnapshot() async {
    final state = await _channel.invokeMapMethod<String, Object?>('snapshot');
    if (state != null) _listener?.call(state);
  }

  @override
  Future<void> dispose() async {
    _listener = null;
    _channel.setMethodCallHandler(null);
  }
}

class LocalVideoPlaybackController extends ChangeNotifier {
  LocalVideoPlaybackController(this._bridge, {LoopController? loopController})
    : loopController = loopController ?? LoopController() {
    _bridge.setStateListener(onNativeState);
  }

  final LocalVideoPlayerBridge _bridge;
  final LoopController loopController;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1;
  double volume = 1;
  bool isPlaying = false;
  bool isReady = false;
  bool hasVideoFrame = false;
  int videoWidth = 0;
  int videoHeight = 0;
  String? playerError;

  bool _loopSeekInProgress = false;
  bool _disposed = false;

  void onNativeState(Map<String, Object?> state) {
    if (_disposed) return;
    isReady = state['ready'] == true;
    isPlaying = state['playing'] == true;
    final reportedVideoFrame = state['hasVideoFrame'];
    if (reportedVideoFrame is bool) hasVideoFrame = reportedVideoFrame;
    final reportedVideoWidth = state['videoWidth'];
    if (reportedVideoWidth is num && reportedVideoWidth.isFinite) {
      videoWidth = reportedVideoWidth.round().clamp(0, 100000).toInt();
    }
    final reportedVideoHeight = state['videoHeight'];
    if (reportedVideoHeight is num && reportedVideoHeight.isFinite) {
      videoHeight = reportedVideoHeight.round().clamp(0, 100000).toInt();
    }
    position =
        _durationFromMilliseconds(state['positionMilliseconds']) ?? position;
    duration =
        _durationFromMilliseconds(state['durationMilliseconds']) ?? duration;
    final reportedSpeed = state['speed'];
    if (reportedSpeed is num && reportedSpeed.isFinite) {
      speed = normalizePlaybackSpeed(reportedSpeed.toDouble());
    }
    final reportedVolume = state['volume'];
    if (reportedVolume is num && reportedVolume.isFinite) {
      volume = normalizePlaybackVolume(reportedVolume.toDouble());
    }
    final error = state['error'];
    playerError = error is String && error.isNotEmpty ? error : null;
    _applyLoopIfNeeded();
    _notify();
  }

  Future<void> requestSnapshot() => _run(_bridge.requestSnapshot);

  Future<void> play() => _run(_bridge.play);

  Future<void> pause() => _run(_bridge.pause);

  void previewPosition(Duration value) {
    position = _clampPosition(value);
    _notify();
  }

  Future<void> seek(Duration value) async {
    final target = _clampPosition(value);
    position = target;
    _notify();
    await _run(() => _bridge.seek(target));
  }

  Future<void> seekRelative(Duration offset) => seek(position + offset);

  Future<void> setSpeed(double value) async {
    if (!value.isFinite) {
      playerError = '播放速度无效';
      _notify();
      return;
    }
    final target = normalizePlaybackSpeed(value);
    speed = target;
    _notify();
    await _run(() => _bridge.setSpeed(target));
  }

  void previewVolume(double value) {
    if (!value.isFinite) return;
    volume = normalizePlaybackVolume(value);
    _notify();
  }

  Future<void> setVolume(double value) async {
    if (!value.isFinite) {
      playerError = '媒体音量无效';
      _notify();
      return;
    }
    final target = normalizePlaybackVolume(value);
    volume = target;
    _notify();
    await _run(() => _bridge.setVolume(target));
  }

  void setLoopStart() {
    loopController.setStart(position);
    _notify();
  }

  bool setLoopEnd() {
    final success = loopController.setEnd(position, duration: duration);
    _notify();
    return success;
  }

  bool setLoopEnabled(bool value) {
    final success = loopController.setEnabled(value);
    _notify();
    return success;
  }

  void clearLoop() {
    loopController.clear();
    _notify();
  }

  Future<void> activateLoopRange(LoopRange range) async {
    loopController.setRange(range);
    _notify();
    await seek(range.start);
  }

  void _applyLoopIfNeeded() {
    if (_loopSeekInProgress) return;
    final target = loopController.seekTargetFor(position);
    if (target == null) return;
    _loopSeekInProgress = true;
    unawaited(_seekForLoop(target, resume: isPlaying));
  }

  Future<void> _seekForLoop(Duration target, {required bool resume}) async {
    try {
      if (_disposed) return;
      await seek(target);
      if (resume && !_disposed) await play();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      _loopSeekInProgress = false;
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_disposed) return;
    try {
      await operation();
    } on Object catch (error) {
      if (_disposed) return;
      playerError = '播放器操作失败：$error';
      _notify();
    }
  }

  Duration _clampPosition(Duration value) {
    if (value.isNegative) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  Duration? _durationFromMilliseconds(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return Duration(milliseconds: value.round());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bridge.setStateListener(null);
    unawaited(_bridge.dispose());
    super.dispose();
  }
}

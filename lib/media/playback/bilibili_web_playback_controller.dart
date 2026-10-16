import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'loop_controller.dart';
import 'playback_speed.dart';
import 'playback_volume.dart';

abstract interface class JavaScriptExecutor {
  Future<void> runJavaScript(String javaScript);
}

class BilibiliWebPlaybackController extends ChangeNotifier {
  BilibiliWebPlaybackController(
    this._executor, {
    LoopController? loopController,
  }) : loopController = loopController ?? LoopController();

  final JavaScriptExecutor _executor;
  final LoopController loopController;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1;
  double volume = 1;
  bool isPlaying = false;
  bool bridgeReady = false;
  String? playerError;

  bool _loopSeekInProgress = false;
  bool _disposed = false;

  static const String bridgeScript = r'''
(() => {
  if (window.__guitarPalBridgeInstalled) {
    window.__guitarPalBindVideo?.();
    return;
  }
  window.__guitarPalBridgeInstalled = true;

  const post = (event, video, error) => {
    const payload = {
      event,
      position: video && Number.isFinite(video.currentTime) ? video.currentTime : 0,
      duration: video && Number.isFinite(video.duration) ? video.duration : 0,
      speed: video && Number.isFinite(video.playbackRate) ? video.playbackRate : 1,
      volume: video && Number.isFinite(video.volume)
        ? (video.muted ? 0 : video.volume)
        : 1,
      playing: !!video && !video.paused && !video.ended,
      error: error || null,
    };
    window.GuitarPalPlayer?.postMessage(JSON.stringify(payload));
  };

  const findVideo = () => document.querySelector('video');
  let boundVideo = null;
  let lastPositionPost = 0;

  const bindVideo = () => {
    const video = findVideo();
    if (!video) return false;
    if (video === boundVideo) return true;
    boundVideo = video;

    const emit = (event) => post(event, video, null);
    ['loadedmetadata', 'durationchange', 'play', 'pause', 'ratechange', 'volumechange', 'ended']
      .forEach((event) => video.addEventListener(event, () => emit(event)));
    video.addEventListener('timeupdate', () => {
      const now = Date.now();
      if (now - lastPositionPost >= 200) {
        lastPositionPost = now;
        emit('timeupdate');
      }
    });
    video.addEventListener('error', () => {
      post('error', video, video.error ? `Media error ${video.error.code}` : 'Media error');
    });
    emit('ready');
    return true;
  };

  window.__guitarPalBindVideo = bindVideo;
  window.GuitarPalControl = {
    probe: () => bindVideo(),
    play: () => {
      const video = findVideo();
      if (!video) return false;
      video.play().catch((error) => post('error', video, String(error)));
      return true;
    },
    pause: () => {
      const video = findVideo();
      if (!video) return false;
      video.pause();
      return true;
    },
    seek: (seconds) => {
      const video = findVideo();
      if (!video || !Number.isFinite(seconds)) return false;
      const maximum = Number.isFinite(video.duration) ? video.duration : seconds;
      video.currentTime = Math.max(0, Math.min(seconds, maximum));
      post('seek', video, null);
      return true;
    },
    setSpeed: (rate) => {
      const video = findVideo();
      if (!video || !Number.isFinite(rate)) return false;
      video.playbackRate = Math.max(0.5, Math.min(rate, 2));
      post('ratechange', video, null);
      return true;
    },
    setVolume: (volume) => {
      const video = findVideo();
      if (!video || !Number.isFinite(volume)) return false;
      video.volume = Math.max(0, Math.min(volume, 1));
      if (volume > 0) video.muted = false;
      post('volumechange', video, null);
      return true;
    },
    snapshot: () => {
      const video = findVideo();
      post(video ? 'snapshot' : 'notReady', video, null);
      return !!video;
    },
  };

  const observer = new MutationObserver(() => bindVideo());
  observer.observe(document.documentElement, {childList: true, subtree: true});
  setInterval(() => bindVideo(), 1000);
  bindVideo();
})();
''';

  Future<void> installBridge() async {
    try {
      await _executor.runJavaScript(bridgeScript);
      await _executor.runJavaScript('window.GuitarPalControl?.snapshot();');
    } on Object catch (error) {
      playerError = '无法连接网页播放器：$error';
      _notify();
    }
  }

  void onJavaScriptMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;
      final event = decoded['event'];
      if (event == 'notReady') return;

      bridgeReady = true;
      position = _durationFromSeconds(decoded['position']) ?? position;
      duration = _durationFromSeconds(decoded['duration']) ?? duration;
      final reportedSpeed = decoded['speed'];
      if (reportedSpeed is num && reportedSpeed.isFinite) {
        speed = normalizePlaybackSpeed(reportedSpeed.toDouble());
      }
      final reportedVolume = decoded['volume'];
      if (reportedVolume is num && reportedVolume.isFinite) {
        volume = normalizePlaybackVolume(reportedVolume.toDouble());
      }
      isPlaying = decoded['playing'] == true;
      final error = decoded['error'];
      playerError = error is String && error.isNotEmpty ? error : null;
      _applyLoopIfNeeded();
      _notify();
    } on FormatException {
      // Ignore malformed messages from the untrusted web page.
    }
  }

  Future<void> play() async {
    await _executor.runJavaScript('window.GuitarPalControl?.play();');
  }

  Future<void> pause() async {
    await _executor.runJavaScript('window.GuitarPalControl?.pause();');
  }

  void previewPosition(Duration value) {
    position = _clampPosition(value);
    _notify();
  }

  Future<void> seek(Duration value) async {
    final target = _clampPosition(value);
    position = target;
    _notify();
    await _executor.runJavaScript(
      'window.GuitarPalControl?.seek(${target.inMilliseconds / 1000});',
    );
  }

  Future<void> setSpeed(double value) async {
    if (!value.isFinite) {
      playerError = '播放速度无效';
      _notify();
      return;
    }
    final target = normalizePlaybackSpeed(value);
    speed = target;
    _notify();
    await _executor.runJavaScript(
      'window.GuitarPalControl?.setSpeed($target);',
    );
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
    await _executor.runJavaScript(
      'window.GuitarPalControl?.setVolume($target);',
    );
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
    unawaited(_seekForLoop(target));
  }

  Future<void> _seekForLoop(Duration target) async {
    try {
      await seek(target);
      if (isPlaying) await play();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } on Object catch (error) {
      if (!_disposed) {
        playerError = '循环播放操作失败：$error';
        _notify();
      }
    } finally {
      _loopSeekInProgress = false;
    }
  }

  Duration _clampPosition(Duration value) {
    if (value.isNegative) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  Duration? _durationFromSeconds(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return Duration(milliseconds: (value.toDouble() * 1000).round());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

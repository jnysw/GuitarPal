import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'loop_controller.dart';
import 'playback_speed.dart';

class YouTubePlaybackController extends ChangeNotifier {
  YouTubePlaybackController(this._execute);

  final Future<void> Function(String script) _execute;
  final loop = LoopController(tolerance: Duration.zero);

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1;
  List<double> rates = const [1];
  bool ready = false;
  bool isPlaying = false;
  String? error;
  bool _closed = false;

  bool get canSeek => ready && duration > Duration.zero;

  void reset() {
    ready = isPlaying = false;
    position = duration = Duration.zero;
    speed = 1;
    rates = const [1];
    error = null;
    notifyListeners();
  }

  void fail(String reason) {
    if (_closed) return;
    ready = isPlaying = false;
    error = reason;
    notifyListeners();
  }

  void onMessage(String message) {
    if (_closed || error != null) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    if (decoded['type'] == 'error') {
      fail(switch (decoded['code']) {
        100 => '此视频已删除或设为私密',
        101 || 150 => '作者关闭了嵌入播放',
        153 => 'YouTube 未接受当前播放器配置',
        _ => '暂时无法加载 YouTube 视频',
      });
      return;
    }
    if (decoded['type'] != 'snapshot') return;
    final state = decoded['state'];
    ready = true;
    isPlaying = state == 1;
    duration = _time(decoded['duration']);
    position = _time(decoded['position']);
    speed = _rate(decoded['rate']) ?? 1;
    final offeredRates = decoded['rates'];
    if (offeredRates is List) {
      final valid = offeredRates.map(_rate).nonNulls.toSet().toList()..sort();
      rates = valid.isEmpty ? const [1] : valid;
    }
    final ended = state == 0;
    if (canSeek && loop.enabled && (isPlaying || ended)) {
      final target = loop.seekTargetFor(ended ? duration : position);
      if (target != null) {
        unawaited(_command('seek(${target.inMilliseconds / 1000}, $ended)'));
      }
    }
    notifyListeners();
  }

  Future<void> playPause() => _command(isPlaying ? 'pause()' : 'play()');

  Future<void> pause() => _command('pause()');

  Future<void> seek(Duration target) async {
    if (!canSeek) return;
    final ms = target.inMilliseconds.clamp(0, duration.inMilliseconds);
    await _command('seek(${ms / 1000}, false)');
  }

  Future<void> setSpeed(double preferred) {
    final closest = nearestPlaybackRate(preferred, rates);
    return closest == speed ? Future.value() : _command('speed($closest)');
  }

  void setA() {
    if (!canSeek) return;
    loop.setStart(position);
    notifyListeners();
  }

  bool setB() {
    if (!canSeek || !loop.setEnd(position, duration: duration)) return false;
    loop.setEnabled(true);
    notifyListeners();
    return true;
  }

  void toggleLoop(bool enabled) {
    if (!loop.setEnabled(enabled)) return;
    notifyListeners();
  }

  void clearLoop() {
    loop.clear();
    notifyListeners();
  }

  Future<bool> activateRange(LoopRange range) async {
    if (!canSeek || range.end > duration) return false;
    loop.setRange(range);
    await seek(range.start);
    if (!_closed) notifyListeners();
    return true;
  }

  Future<void> _command(String call) async {
    if (_closed || !ready) return;
    try {
      await _execute('window.melpalYouTube?.$call');
    } on Object {
      fail('YouTube 播放器连接中断');
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

Duration _time(Object? value) =>
    value is num && value.isFinite && value >= 0 && value < 1e9
    ? Duration(milliseconds: (value * 1000).round())
    : Duration.zero;

double? _rate(Object? value) =>
    value is num && value.isFinite && value > 0 ? value.toDouble() : null;

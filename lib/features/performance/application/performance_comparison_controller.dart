import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../data/performance_audio_platform.dart';
import '../domain/performance_comparison.dart';

/// A single native microphone player; A and B never play simultaneously.
class PerformanceComparisonController extends ChangeNotifier {
  PerformanceComparisonController(this.comparison, this.audio, this.extra) {
    sourceMs = comparison.startMs;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_poll()),
    );
  }

  final PerformanceComparison comparison;
  final PracticeAudioRecorder audio;
  final PerformanceAudioPlatform extra;
  late final Timer _timer;
  late int sourceMs;
  int active = 0;
  double volume = 1;
  bool busy = true, playing = false;
  String? error;
  bool _disposed = false, _foreground = true, _closed = false, _polling = false;
  int _revision = 0;
  Future<void> _tail = Future.value();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _queue(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> initialize() => _queue(() async {
    try {
      for (final entry in [comparison.first, comparison.second]) {
        await audio.resolveAbsolutePath(entry.take.filePath);
      }
    } on Object {
      error = '部分原始录音已丢失或无法读取，请返回列表分别检查';
    } finally {
      busy = false;
      _notify();
    }
  });

  bool _current(int token) =>
      !_closed && !_disposed && _foreground && token == _revision;

  Future<void> _start(int token) async {
    await extra.play(
      comparison.entry(active).take.filePath,
      comparison.recordingAt(active, sourceMs),
      volume,
    );
    if (!_current(token)) {
      await audio.stopPlayback();
    } else {
      playing = true;
    }
  }

  Future<void> _change(Future<void> Function(int token) action) async {
    if (busy || _closed || !_foreground || error != null) return;
    busy = true;
    final token = ++_revision;
    _notify();
    await _queue(() async {
      try {
        if (_current(token)) await action(token);
      } on Object {
        playing = false;
        error = '对比回听已中断，请返回后重新打开';
        await audio.stopPlayback().catchError((Object _) {});
      } finally {
        busy = false;
        _notify();
      }
    });
  }

  Future<void> _capturePosition() async {
    if (!playing) return;
    final s = await audio.playbackSnapshot();
    if (s.isLoaded) {
      sourceMs = comparison.sourceAt(active, s.position.inMilliseconds);
    }
    if (!s.isPlaying) playing = false;
  }

  Future<void> toggle() => _change((token) async {
    if (playing) {
      await _capturePosition();
      await audio.pausePlayback();
      playing = false;
    } else {
      if (sourceMs >= comparison.endMs) sourceMs = comparison.startMs;
      await _start(token);
    }
  });

  Future<void> select(int index) async {
    if (index < 0 || index > 1 || index == active) return;
    await _change((token) async {
      await _capturePosition();
      final resume = playing && sourceMs < comparison.endMs;
      await audio.stopPlayback();
      playing = false;
      if (!_current(token)) return;
      active = index;
      if (resume) await _start(token);
    });
  }

  Future<void> seek(int source) => _change((token) async {
    final resume = playing;
    await audio.stopPlayback();
    playing = false;
    if (!_current(token)) return;
    sourceMs = source.clamp(comparison.startMs, comparison.endMs);
    if (resume && sourceMs < comparison.endMs) await _start(token);
  });

  Future<void> setVolume(double value) => _change((_) async {
    if (!value.isFinite) return;
    volume = value.clamp(0, 1);
    await extra.setVolume(volume);
  });

  Future<void> _poll() async {
    if (_polling || busy || !playing || !_foreground || _closed) return;
    _polling = true;
    await _queue(() async {
      try {
        if (busy || !playing || !_foreground || _closed) return;
        await _capturePosition();
        if (sourceMs >= comparison.endMs || !playing) {
          await audio.pausePlayback();
          playing = false;
        }
        _notify();
      } on Object {
        playing = false;
        error = '对比回听已中断，请返回后重新打开';
        await audio.stopPlayback().catchError((Object _) {});
        _notify();
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> suspend() {
    _foreground = false;
    ++_revision;
    playing = false;
    return _queue(() async {
      await audio.stopPlayback().catchError((Object _) {});
      _notify();
    });
  }

  void resume() {
    if (_closed) return;
    _foreground = true;
    _notify();
  }

  Future<void> close() {
    _closed = true;
    _timer.cancel();
    return suspend();
  }

  @override
  void dispose() {
    if (!_closed) unawaited(close());
    _disposed = true;
    super.dispose();
  }
}

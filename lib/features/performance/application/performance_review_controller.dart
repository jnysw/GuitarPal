import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../audio_tools/data/algorithm_mix_platform.dart';
import '../../audio_tools/data/algorithm_stem_store.dart';
import '../data/performance_audio_platform.dart';
import '../domain/performance_take.dart';
import 'performance_preview.dart';
import 'performance_source_resolver.dart';

/// Local two-player audition with manual alignment and coarse drift correction.
/// This is not a sample-locked render/export; microphone file remains untouched.
class PerformanceReviewController extends ChangeNotifier {
  PerformanceReviewController(
    this.take,
    this.audio,
    this.extra,
    this.mix,
    AlgorithmStemStore store,
    this.resolver,
  ) {
    micVolume = (take.toJson()['reviewMicVolume'] as num?)?.toDouble() ?? 1;
    backingVolume =
        (take.toJson()['reviewBackingVolume'] as num?)?.toDouble() ?? 1;
    _preview = PerformancePreview(
      mix,
      store,
      verify: (c) async {
        take.verifyCandidate(c);
        await resolver.verify(c);
      },
    );
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_poll()),
    );
  }
  PerformanceTake take;
  final PracticeAudioRecorder audio;
  final PerformanceAudioPlatform extra;
  final AlgorithmMixPlatform mix;
  final PerformanceSourceResolver resolver;
  late final PerformancePreview _preview;
  late final Timer _timer;
  bool busy = true, playing = false, backingReady = false, useBacking = true;
  bool _closed = false, _foreground = true, _polling = false;
  int _revision = 0;
  int positionMs = 0;
  double micVolume = 1, backingVolume = 1;
  String? error, backingError;
  bool _current(int token) => !_closed && _foreground && token == _revision;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      await audio.resolveAbsolutePath(take.filePath);
      if (_closed) return;
      if (!take.trial) {
        try {
          final candidate = await resolver.lookup(
            take.sourceId,
            take.preset.taskId,
          );
          take.verifyCandidate(candidate);
          if (_closed || !_foreground) return;
          await _preview.prepare(candidate, take.preset, allowDownload: false);
          backingReady = _preview.ready;
          if (backingReady) {
            await _preview.configure(
              take.preset.copyWith(master: take.preset.master * backingVolume),
            );
          }
          if (!backingReady) backingError = _preview.error;
        } on Object {
          backingError = '伴奏或原视频已不可用，仍可回听原始录音';
        }
      }
    } on Object {
      error = '录音文件不存在或无法读取';
    } finally {
      busy = false;
      _notify();
    }
  }

  int get _backingEnd {
    final actual = take.endSourceMs - take.preset.startMs;
    return (actual > 0 ? actual : (take.durationMs * take.preset.speed).round())
        .clamp(0, take.preset.durationMs);
  }

  int _backingAt(int micMs) =>
      ((micMs - (take.leadMs ?? 0) + take.alignmentMs) * take.preset.speed)
          .round();
  Future<void> _alignBacking(int micMs, {bool force = false}) async {
    if (!backingReady || !useBacking || !_foreground || _closed) return;
    final expected = _backingAt(micMs);
    if (expected < 0 || expected >= _backingEnd) {
      if (_preview.playing) await _preview.toggle();
      return;
    }
    if (force || (expected - _preview.positionMs).abs() > 200) {
      await _preview.seek(expected);
    }
    if (!_preview.playing && playing) await _preview.toggle();
  }

  Future<void> toggle() async {
    if (busy || _closed || !_foreground) return;
    if (playing) {
      await pause();
      return;
    }
    final token = ++_revision;
    busy = true;
    error = null;
    _notify();
    try {
      if (positionMs >= take.durationMs - 50) positionMs = 0;
      await extra.play(take.filePath, positionMs, micVolume);
      if (!_current(token)) {
        await audio.stopPlayback();
        return;
      }
      playing = true;
      await _alignBacking(positionMs, force: true);
    } on Object {
      error = '回听未能开始，请重新打开录音';
      playing = false;
      await _pauseNative();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _pauseNative() async {
    await audio.pausePlayback().catchError((Object _) {});
    if (_preview.playing) await _preview.toggle();
  }

  Future<void> pause() async {
    ++_revision;
    playing = false;
    await _pauseNative();
    _notify();
  }

  Future<void> _poll() async {
    if (_polling || !playing || busy || _closed || !_foreground) return;
    _polling = true;
    final token = _revision;
    try {
      final s = await audio.playbackSnapshot();
      if (!_current(token)) return;
      positionMs = s.position.inMilliseconds.clamp(0, take.durationMs);
      if (!s.isPlaying) {
        await pause();
      } else {
        await _alignBacking(positionMs);
      }
      if (_preview.error != null) {
        backingReady = false;
        backingError = _preview.error;
        await _preview.invalidate();
      }
      _notify();
    } on Object {
      await pause();
      error = '回听已中断，请重试';
      _notify();
    } finally {
      _polling = false;
    }
  }

  Future<void> seek(int value) async {
    if (busy || _closed || !_foreground) return;
    final resume = playing;
    busy = true;
    _notify();
    try {
      final stopping = pause();
      final token = _revision;
      await stopping;
      if (!_current(token)) return;
      positionMs = value.clamp(0, take.durationMs);
      busy = false;
      _notify();
      if (resume) await toggle();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> setVolumes({double? mic, double? backing}) async {
    micVolume = (mic ?? micVolume).clamp(0, 1);
    backingVolume = (backing ?? backingVolume).clamp(0, 1);
    take = take.update({
      'reviewMicVolume': micVolume,
      'reviewBackingVolume': backingVolume,
    });
    try {
      await extra.setVolume(micVolume);
      if (backingReady) {
        await _preview.configure(
          take.preset.copyWith(master: take.preset.master * backingVolume),
        );
      }
    } on Object {
      error = '音量调整失败，请暂停后重试';
    }
    _notify();
  }

  Future<void> setAlignment(int ms) async {
    take = take.update({'alignmentMs': ms.clamp(-2000, 2000)});
    if (playing) await _alignBacking(positionMs, force: true);
    _notify();
  }

  Future<void> setBacking(bool enabled) async {
    useBacking = enabled;
    if (!enabled && _preview.playing) {
      await _preview.toggle();
    } else if (enabled && playing) {
      await _alignBacking(positionMs, force: true);
    }
    _notify();
  }

  Future<void> suspend() async {
    _foreground = false;
    await pause();
  }

  void resume() {
    _foreground = true;
    _notify();
  }

  Future<void> close() async {
    await pause();
    await audio.stopPlayback();
    await _preview.invalidate();
  }

  @override
  void dispose() {
    _closed = true;
    ++_revision;
    _timer.cancel();
    _preview.dispose();
    unawaited(audio.stopPlayback().catchError((Object _) {}));
    super.dispose();
  }
}

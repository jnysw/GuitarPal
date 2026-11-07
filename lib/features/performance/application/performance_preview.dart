import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../audio_tools/data/algorithm_mix_platform.dart';
import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_stem_choice.dart';
import '../domain/backing_preset.dart';

/// Preparation-only preview. Owns one native mix; never creates a practice session.
class PerformancePreview extends ChangeNotifier {
  PerformancePreview(this.platform, this.store, {required this.verify}) {
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_poll()),
    );
  }
  final AlgorithmMixPlatform platform;
  final AlgorithmStemStore store;
  final Future<void> Function(PerformanceCandidate) verify;
  late final Timer _ticker;
  int _generation = 0;
  bool _closed = false,
      _foreground = true,
      _polling = false,
      _ownsEngine = false;
  bool busy = false, ready = false, playing = false;
  int positionMs = 0, durationMs = 1;
  String? error;
  String stage = '';
  StemDownloadProgress? progress;
  BackingPreset? applied;
  PerformanceCandidate? _candidate;
  StemDownloadCancellation? _cancel;
  Future<void> _configuration = Future.value();
  Future<void>? _pendingPreparation;
  bool _current(int token) => !_closed && _foreground && token == _generation;
  void _changed() {
    if (!_closed) notifyListeners();
  }

  String _message(Object e) => e is FormatException
      ? e.message
      : e is AlgorithmApiError
      ? e.message
      : e is PlatformException
      ? e.message ?? '本机音频载入失败'
      : e is StemDownloadPaused
      ? e.toString()
      : '伴奏准备失败，已下载文件保留，请重试';
  void pauseDownload() => _cancel?.cancel();
  Future<void> prepare(
    PerformanceCandidate candidate,
    BackingPreset preset, {
    bool allowDownload = true,
  }) async {
    if (busy || !_foreground || _closed) return;
    final request = _generation;
    final pending = _pendingPreparation;
    if (pending != null) await pending;
    if (busy || !_foreground || _closed || request != _generation) return;
    final work = _prepare(candidate, preset, allowDownload: allowDownload);
    _pendingPreparation = work;
    try {
      await work;
    } finally {
      if (identical(_pendingPreparation, work)) _pendingPreparation = null;
    }
  }

  Future<void> _prepare(
    PerformanceCandidate candidate,
    BackingPreset preset, {
    required bool allowDownload,
  }) async {
    if (busy || !_foreground || _closed) return;
    final token = ++_generation;
    final cancel = StemDownloadCancellation();
    _cancel = cancel;
    busy = true;
    ready = playing = false;
    error = null;
    progress = null;
    stage = '正在检查伴奏文件…';
    applied = null;
    _changed();
    try {
      if (_ownsEngine) await platform.stop();
      _ownsEngine = false;
      preset.validateAgainst(candidate);
      await verify(candidate);
      final stems = videoStemSubset(candidate.result, preset.controls.keys);
      final paths = <String, String>{};
      for (final stem in stems) {
        final cached = await store.localFile(candidate.task.id, stem);
        if (!_current(token)) return;
        if (cached != null) paths[stem.id] = cached.path;
      }
      if (paths.length != stems.length) {
        if (!allowDownload) throw const FormatException('舞台需要完整伴奏，请返回准备页补齐音轨');
        if (!DateTime.now().toUtc().isBefore(candidate.result.expiresAt)) {
          throw const FormatException('服务器结果已到期，请只选本机完整音轨，或返回练习页重新分轨');
        }
        stage = '正在下载所选伴奏…';
        _changed();
        paths.addAll(
          await store.downloadBatch(
            candidate.task.id,
            stems,
            cancellation: cancel,
            onProgress: (p) {
              if (_current(token)) {
                progress = p;
                _changed();
              }
            },
          ),
        );
      }
      if (!_current(token)) return;
      cancel.check();
      await verify(candidate);
      if (!_current(token)) return;
      stage = '正在本机解码并载入伴奏…';
      progress = null;
      _changed();
      _ownsEngine = true;
      await platform.load(paths);
      if (!_current(token)) return;
      cancel.check();
      final snapshot = await platform.snapshot();
      if (!_current(token)) return;
      final actual = algorithmInteger(snapshot['durationMs']);
      if (snapshot['isLoaded'] != true ||
          (actual - candidate.binding.durationMs).abs() > 100) {
        throw const FormatException('伴奏实际时长与分析区间不一致');
      }
      await platform.configureTracks(
        preset.controls,
        master: preset.master,
        speed: preset.speed,
      );
      await platform.seek(0);
      if (!_current(token)) return;
      durationMs = actual;
      positionMs = 0;
      ready = true;
      applied = preset;
      _candidate = candidate;
      stage = '伴奏已就绪';
    } on Object catch (e) {
      if (_current(token)) {
        error = _message(e);
        ready = false;
      }
      if (token == _generation && _ownsEngine) {
        await platform.stop().catchError((Object _) {});
        _ownsEngine = false;
      }
    } finally {
      if (token == _generation) {
        busy = false;
        _cancel = null;
        _changed();
      }
    }
  }

  Future<void> configure(BackingPreset preset) {
    final token = _generation;
    final work = _configuration.then((_) async {
      if (!_current(token) || !ready) return;
      try {
        preset.validateAgainst(_candidate!);
        await platform.configureTracks(
          preset.controls,
          master: preset.master,
          speed: preset.speed,
        );
        if (_current(token)) {
          applied = preset;
          _changed();
        }
      } on Object catch (e) {
        if (_current(token)) {
          error = _message(e);
          ready = false;
          playing = false;
          await platform.pause().catchError((Object _) {});
          _changed();
        }
      }
    });
    _configuration = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return work;
  }

  Future<void> toggle() async {
    if (!ready || busy || !_foreground || _closed) return;
    final token = _generation;
    try {
      await _configuration;
      if (!_current(token) || !ready) return;
      await verify(_candidate!);
      if (!_current(token)) return;
      if (playing) {
        await platform.pause();
      } else {
        if (positionMs >= durationMs - 20) await platform.seek(0);
        await platform.play();
      }
      if (_current(token)) await _poll(force: true);
    } on Object catch (e) {
      if (_current(token)) {
        error = _message(e);
        ready = false;
        playing = false;
        await platform.pause().catchError((Object _) {});
        _changed();
      }
    }
  }

  Future<void> seek(int ms) async {
    if (!ready || busy || _closed) return;
    final token = _generation;
    try {
      await platform.seek(ms.clamp(0, durationMs));
      if (_current(token)) {
        positionMs = ms.clamp(0, durationMs);
        _changed();
      }
    } on Object catch (e) {
      if (_current(token)) {
        error = _message(e);
        _changed();
      }
    }
  }

  Future<void> _poll({bool force = false}) async {
    if (_polling || !ready || !_foreground || _closed || (!playing && !force)) {
      return;
    }
    final token = _generation;
    _polling = true;
    try {
      final s = await platform.snapshot();
      if (!_current(token)) return;
      if (s['error'] is String && (s['error'] as String).isNotEmpty) {
        throw PlatformException(code: 'preview', message: s['error'] as String);
      }
      playing = s['isPlaying'] == true;
      positionMs = algorithmInteger(s['positionMs']).clamp(0, durationMs);
      _changed();
    } on Object catch (e) {
      if (_current(token)) {
        error = _message(e);
        playing = false;
        ready = false;
        await platform.pause().catchError((Object _) {});
        _changed();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> invalidate() async {
    ++_generation;
    _cancel?.cancel();
    _cancel = null;
    busy = ready = playing = false;
    applied = null;
    progress = null;
    error = null;
    if (_ownsEngine) {
      _ownsEngine = false;
      await platform.stop().catchError((Object _) {});
    }
    _changed();
  }

  Future<void> suspend() async {
    _foreground = false;
    await invalidate();
  }

  Future<void> flush() => _configuration;
  void resume() {
    _foreground = true;
    _changed();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _cancel?.cancel();
    _ticker.cancel();
    if (_ownsEngine) unawaited(platform.stop().catchError((Object _) {}));
    super.dispose();
  }
}

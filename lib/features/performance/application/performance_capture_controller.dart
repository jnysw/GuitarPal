import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../data/performance_audio_platform.dart';
import '../domain/performance_take.dart';
import 'performance_stage_controller.dart';
import 'performance_take_service.dart';

enum PerformanceCapturePhase {
  idle,
  checking,
  countdown,
  recording,
  finalizing,
}

class PerformanceCaptureController extends ChangeNotifier {
  PerformanceCaptureController(
    this.stage,
    this.audio,
    this.extra,
    this.service, {
    this.countdownStep = const Duration(seconds: 1),
    this.trialDuration = const Duration(seconds: 3),
  }) {
    stage.addListener(_stageChanged);
  }
  final PerformanceStageController stage;
  final PracticeAudioRecorder audio;
  final PerformanceAudioPlatform extra;
  final PerformanceTakeService service;
  final Duration countdownStep, trialDuration;
  PerformanceCapturePhase phase = PerformanceCapturePhase.idle;
  PerformanceTake? draft;
  bool loading = true, permanentlyDenied = false;
  String? error;
  int countdown = 0, elapsedMs = 0;
  int _revision = 0;
  bool _closed = false, _foreground = true, _polling = false;
  Timer? _ticker;
  Stopwatch? _watch;
  Future<void>? _stopping;
  bool get active => phase != PerformanceCapturePhase.idle;
  bool get recording => phase == PerformanceCapturePhase.recording;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      for (final take in await service.store.list(
        stage.candidate.binding.sourceId,
      )) {
        if (await service.recordings.getById(take.id) != null) {
          await service.store.delete(take.id);
        } else {
          draft = take;
          break;
        }
      }
    } on Object {
      error = '未能读取录音草稿，请稍后重试';
    } finally {
      loading = false;
      _notify();
    }
  }

  bool _current(int token) => !_closed && _foreground && token == _revision;
  Future<void> begin({required bool trial}) async {
    if (_closed || !_foreground || active || loading || draft != null) return;
    final token = ++_revision;
    phase = PerformanceCapturePhase.checking;
    error = null;
    permanentlyDenied = false;
    _notify();
    try {
      await stage.pause();
      var permission = await audio.permissionStatus();
      if (permission != MicrophonePermissionStatus.granted) {
        permission = await audio.requestPermission();
      }
      if (!_current(token)) return;
      if (permission != MicrophonePermissionStatus.granted) {
        permanentlyDenied =
            permission == MicrophonePermissionStatus.permanentlyDenied;
        throw FormatException(
          permanentlyDenied ? '请到系统设置允许麦克风权限' : '需要麦克风权限才能录音',
        );
      }
      final environment = await extra.environment();
      _outputs = environment['availableOutputDevices'].toString();
      if (!_current(token)) return;
      if ((environment['freeBytes'] as num? ?? 0) < 64 * 1024 * 1024) {
        throw const FormatException('剩余空间不足，请至少保留 64 MB 后重试');
      }
      if (!trial) {
        await stage.preparePaused();
        if (!_current(token)) return;
        if (!stage.ready) throw FormatException(stage.error ?? '请先准备完整伴奏');
        await stage.seek(0);
      }
      if (!_current(token)) return;
      phase = PerformanceCapturePhase.countdown;
      for (var i = 3; i > 0; i--) {
        if (!_current(token)) return;
        countdown = i;
        _notify();
        await Future<void>.delayed(countdownStep);
      }
      if (!_current(token)) return;
      final take = PerformanceTake.begin(
        const Uuid().v4(),
        stage.candidate,
        stage.appliedPreset,
        trial: trial,
      ).update({'environment': environment});
      await service.store.save(take);
      draft = take;
      if (!_current(token)) return;
      final start = await extra.start(take.id);
      draft = take.update({
        'captureStart': start,
        'headphonesRecommended': true,
      });
      await service.store.save(draft!);
      if (!_current(token)) {
        await stop(reason: 'interrupted');
        return;
      }
      if (!trial) {
        await stage.play();
        if (!stage.playing) {
          throw FormatException(stage.error ?? '伴奏未能开始，录音已保留');
        }
      }
      if (!_current(token)) {
        await stop(reason: 'interrupted');
        return;
      }
      _watch = Stopwatch()..start();
      elapsedMs = 0;
      phase = PerformanceCapturePhase.recording;
      _ticker = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => unawaited(_tick()),
      );
      if (!trial) await _sampleStart(start);
      _notify();
    } on Object catch (e) {
      error = e is FormatException ? e.message : '录音未能开始，请检查麦克风与设备空间';
      if (draft != null) await stop(reason: 'startInterrupted');
    } finally {
      if (token == _revision &&
          (phase == PerformanceCapturePhase.checking ||
              phase == PerformanceCapturePhase.countdown)) {
        phase = PerformanceCapturePhase.idle;
      }
      _notify();
    }
  }

  Future<void> _sampleStart(Map<String, Object?> start) async {
    // Retain an estimate, with explicit unknown device/encoder latency. No sample-sync claim.
    for (var i = 0; i < 20 && recording && _foreground && !_closed; i++) {
      final mix = await stage.platform.snapshot();
      if (!recording || _closed || !_foreground) return;
      if ((mix['positionMs'] as num? ?? 0) > 0 &&
          mix['elapsedRealtimeMs'] is num &&
          start['startedAtElapsedMs'] is num) {
        final lead =
            ((mix['elapsedRealtimeMs'] as num) -
                    (mix['positionMs'] as num) / stage.appliedPreset.speed -
                    (start['startedAtElapsedMs'] as num))
                .round();
        if (lead.abs() <= 10000 && draft != null) {
          draft = draft!.update({'leadMs': lead, 'mixStartObservation': mix});
          await service.store.save(draft!);
        }
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  String? _outputs;
  Future<void> _tick() async {
    if (_polling || !recording || _closed) return;
    _polling = true;
    try {
      elapsedMs = _watch?.elapsedMilliseconds ?? 0;
      if (draft?.trial == true && elapsedMs >= trialDuration.inMilliseconds) {
        await stop(reason: 'trial');
        return;
      }
      if (!await audio.isRecording()) {
        await stop(reason: 'interrupted');
        return;
      }
      final env = await extra.environment();
      final outputs = env['availableOutputDevices'].toString();
      if (_outputs != null && _outputs != outputs) {
        await stop(reason: 'routeChanged');
        return;
      }
      _outputs = outputs;
      _notify();
    } on Object {
      await stop(reason: 'inputError');
    } finally {
      _polling = false;
    }
  }

  void _stageChanged() {
    if (recording && draft?.trial == false && !stage.playing) {
      unawaited(
        stop(reason: stage.error == null ? 'backingStopped' : 'backingError'),
      );
    }
  }

  Future<void> stop({String reason = 'stopped'}) {
    if (_stopping != null) return _stopping!;
    final work = _stop(reason);
    _stopping = work;
    return work.whenComplete(() => _stopping = null);
  }

  Future<void> _stop(String reason) async {
    ++_revision;
    _ticker?.cancel();
    _ticker = null;
    _watch?.stop();
    _outputs = null;
    final take = draft;
    if (take == null) {
      phase = PerformanceCapturePhase.idle;
      _notify();
      return;
    }
    phase = PerformanceCapturePhase.finalizing;
    _notify();
    try {
      await stage.pause();
      PracticeAudioRecordingResult result;
      try {
        result = await audio.stop();
      } on Object {
        result = await extra.recover(take.id);
      }
      final end = (take.preset.startMs + stage.positionMs).clamp(
        take.preset.startMs,
        take.preset.startMs + take.preset.durationMs,
      );
      draft = (draft ?? take).update({
        'durationMs': result.duration.inMilliseconds,
        'endSourceMs': end,
        'reason': reason,
      });
      await service.store.save(draft!);
    } on Object {
      // Keep journal + committed audio for an explicit recovery attempt; never silently discard.
      error = '录音已中断。若文件已完整写入，可从草稿恢复回听；过短或未完整写入的录音可能无法恢复。';
    } finally {
      phase = PerformanceCapturePhase.idle;
      _notify();
    }
  }

  Future<void> interrupt() async {
    _foreground = false;
    ++_revision;
    if (active) await stop(reason: 'background');
  }

  void resume() {
    _foreground = true;
    _notify();
  }

  Future<void> refreshDraft() async {
    if (draft == null || _closed) return;
    try {
      if (await service.recordings.getById(draft!.id) != null ||
          await service.store.load(draft!.id) == null) {
        draft = null;
      }
      if (draft == null) error = null;
    } on Object {
      error = '暂时无法更新草稿状态，录音仍保留，可从演奏录音列表重试';
    }
    _notify();
  }

  @override
  void dispose() {
    if (active) unawaited(interrupt());
    _closed = true;
    ++_revision;
    _ticker?.cancel();
    stage.removeListener(_stageChanged);
    super.dispose();
  }
}

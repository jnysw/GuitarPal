import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../practice_recording_providers.dart';

class PracticeRecordingReference {
  const PracticeRecordingReference({
    required this.start,
    required this.speed,
    this.end,
    this.segmentId,
    this.segmentTitle,
  });

  final Duration start;
  final Duration? end;
  final double speed;
  final String? segmentId;
  final String? segmentTitle;
}

class PracticeRecordingPanel extends ConsumerStatefulWidget {
  const PracticeRecordingPanel({
    required this.sourceId,
    required this.captureReference,
    required this.referencePosition,
    required this.referenceIsPlaying,
    required this.seekReference,
    required this.playReference,
    required this.pauseReference,
    this.planId,
    this.enabled = true,
    this.onWorkflowActiveChanged,
    super.key,
  });

  final String sourceId;
  final String? planId;
  final bool enabled;
  final PracticeRecordingReference Function() captureReference;
  final Duration Function() referencePosition;
  final bool Function() referenceIsPlaying;
  final Future<void> Function(Duration position) seekReference;
  final Future<void> Function() playReference;
  final Future<void> Function() pauseReference;
  final ValueChanged<bool>? onWorkflowActiveChanged;

  @override
  ConsumerState<PracticeRecordingPanel> createState() =>
      _PracticeRecordingPanelState();
}

enum _RecordingPhase { idle, countdown, recording, preview, saving }

enum _PreviewTrack { original, take }

class _PracticeRecordingPanelState extends ConsumerState<PracticeRecordingPanel>
    with WidgetsBindingObserver {
  late final PracticeAudioRecorder _recorder;
  _RecordingPhase _phase = _RecordingPhase.idle;
  _PreviewTrack _previewTrack = _PreviewTrack.original;
  PracticeRecordingReference? _reference;
  PracticeAudioRecordingResult? _draft;
  Timer? _recordingTicker;
  Timer? _previewTicker;
  Stopwatch? _recordingStopwatch;
  Duration _recordingElapsed = Duration.zero;
  Duration _previewPosition = Duration.zero;
  bool _previewPlaying = false;
  bool _pollingPreview = false;
  bool _permissionPermanentlyDenied = false;
  int _workflowRevision = 0;
  String? _message;
  String _title = '';
  String _note = '';

  bool get _workflowActive => _phase != _RecordingPhase.idle;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(practiceAudioRecorderProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _phase == _RecordingPhase.recording) {
      unawaited(_verifyNativeRecording());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workflowRevision += 1;
    _recordingTicker?.cancel();
    _previewTicker?.cancel();
    final draft = _draft;
    unawaited(_disposeNativeResources(draft));
    super.dispose();
  }

  Future<void> _disposeNativeResources(
    PracticeAudioRecordingResult? draft,
  ) async {
    try {
      if (_phase == _RecordingPhase.recording) await _recorder.cancel();
      await _recorder.stopPlayback();
      if (draft != null) {
        await _recorder.deleteRecording(draft.relativePath);
      }
    } on Object {
      // The Android channel may already be detached during route teardown.
    }
  }

  Future<void> _verifyNativeRecording() async {
    try {
      if (await _recorder.isRecording() || !mounted) return;
      _stopRecordingTicker();
      await widget.pauseReference();
      if (!mounted) return;
      _setPhase(_RecordingPhase.idle);
      setState(() => _message = '录音已因应用离开前台而取消，请重新录制。');
    } on Object {
      // Keep the visible state when a transient platform check fails.
    }
  }

  void _setPhase(_RecordingPhase value) {
    final wasActive = _workflowActive;
    if (mounted) setState(() => _phase = value);
    final isActive = value != _RecordingPhase.idle;
    if (wasActive != isActive) widget.onWorkflowActiveChanged?.call(isActive);
  }

  Future<void> _beginRecording() async {
    if (!widget.enabled || _workflowActive) return;
    setState(() {
      _message = null;
      _permissionPermanentlyDenied = false;
    });
    try {
      var permission = await _recorder.permissionStatus();
      if (permission != MicrophonePermissionStatus.granted) {
        permission = await _recorder.requestPermission();
      }
      if (!mounted) return;
      if (permission != MicrophonePermissionStatus.granted) {
        setState(() {
          _permissionPermanentlyDenied =
              permission == MicrophonePermissionStatus.permanentlyDenied;
          _message = _permissionPermanentlyDenied
              ? '麦克风权限已关闭，请到系统设置中允许后再录音。'
              : '需要麦克风权限才能录制练习。';
        });
        return;
      }

      final reference = widget.captureReference();
      _reference = reference;
      await widget.pauseReference();
      await widget.seekReference(reference.start);
      if (!mounted) return;

      final revision = ++_workflowRevision;
      _setPhase(_RecordingPhase.countdown);
      for (var seconds = 3; seconds >= 1; seconds -= 1) {
        if (!mounted || revision != _workflowRevision) return;
        setState(() => _recordingElapsed = Duration(seconds: seconds));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted || revision != _workflowRevision) return;

      final recordingId = const Uuid().v4();
      await _recorder.start(recordingId: recordingId);
      if (!mounted || revision != _workflowRevision) {
        await _recorder.cancel();
        return;
      }
      _recordingStopwatch = Stopwatch()..start();
      _recordingElapsed = Duration.zero;
      _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() {
            _recordingElapsed = _recordingStopwatch?.elapsed ?? Duration.zero;
          });
        }
      });
      _setPhase(_RecordingPhase.recording);
      await widget.playReference();
    } on Object {
      await _safeCancelNativeRecording();
      if (!mounted) return;
      _setPhase(_RecordingPhase.idle);
      setState(() => _message = '无法开始录音，请检查麦克风权限后重试。');
    }
  }

  Future<void> _stopRecording() async {
    if (_phase != _RecordingPhase.recording) return;
    _stopRecordingTicker();
    try {
      await widget.pauseReference();
      final result = await _recorder.stop();
      if (!mounted) {
        await _recorder.deleteRecording(result.relativePath);
        return;
      }
      _draft = result;
      _previewTrack = _PreviewTrack.original;
      _previewPosition = Duration.zero;
      _previewPlaying = false;
      final now = DateTime.now();
      final segmentTitle = _reference?.segmentTitle?.trim();
      _title = segmentTitle == null || segmentTitle.isEmpty
          ? '练习录音 ${_twoDigits(now.month)}-${_twoDigits(now.day)} '
                '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}'
          : '$segmentTitle · ${_twoDigits(now.month)}-${_twoDigits(now.day)} '
                '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';
      _note = '';
      _setPhase(_RecordingPhase.preview);
      _startPreviewTicker();
    } on Object {
      await _safeCancelNativeRecording();
      if (!mounted) return;
      _setPhase(_RecordingPhase.idle);
      setState(() => _message = '录音没有成功保存，请重新录制。');
    }
  }

  Future<void> _cancelWorkflow() async {
    _workflowRevision += 1;
    _stopRecordingTicker();
    _previewTicker?.cancel();
    try {
      await widget.pauseReference();
      await _recorder.stopPlayback();
      if (await _recorder.isRecording()) await _recorder.cancel();
      final draft = _draft;
      _draft = null;
      if (draft != null) {
        await _recorder.deleteRecording(draft.relativePath);
      }
    } on Object {
      // The local UI can still be safely reset after best-effort cleanup.
    }
    if (!mounted) return;
    _reference = null;
    _previewPosition = Duration.zero;
    _previewPlaying = false;
    _setPhase(_RecordingPhase.idle);
  }

  Future<void> _saveRecording({bool asPlanOutcome = false}) async {
    final draft = _draft;
    final reference = _reference;
    final title = _title.trim();
    if (draft == null ||
        reference == null ||
        title.isEmpty ||
        (asPlanOutcome && widget.planId == null)) {
      setState(() => _message = '请先填写录音名称。');
      return;
    }
    _setPhase(_RecordingPhase.saving);
    try {
      await widget.pauseReference();
      await _recorder.stopPlayback();
      await ref
          .read(practiceRecordingRepositoryProvider)
          .save(
            PracticeRecording(
              id: const Uuid().v4(),
              sourceId: widget.sourceId,
              segmentId: reference.segmentId,
              planId: widget.planId,
              kind: asPlanOutcome
                  ? PracticeRecordingKind.planOutcome
                  : PracticeRecordingKind.segmentTake,
              filePath: draft.relativePath,
              duration: draft.duration,
              referenceStart: reference.start,
              referenceEnd: reference.end,
              referenceSpeed: reference.speed,
              title: title,
              note: _note.trim().isEmpty ? null : _note.trim(),
              recordedAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      _draft = null;
      _reference = null;
      _previewTicker?.cancel();
      _setPhase(_RecordingPhase.idle);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(asPlanOutcome ? '已保存为计划成果' : '练习录音已保存')),
        );
    } on Object {
      if (!mounted) return;
      _setPhase(_RecordingPhase.preview);
      setState(() => _message = '保存录音失败，文件仍保留在当前预览中。');
    }
  }

  Future<void> _safeCancelNativeRecording() async {
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
      await widget.pauseReference();
    } on Object {
      // Best-effort cleanup after a platform failure.
    }
  }

  void _stopRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    _recordingStopwatch?.stop();
    _recordingStopwatch = null;
  }

  void _startPreviewTicker() {
    _previewTicker?.cancel();
    _previewTicker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_pollPreview()),
    );
  }

  Future<void> _pollPreview() async {
    if (!mounted || _phase != _RecordingPhase.preview || _pollingPreview) {
      return;
    }
    _pollingPreview = true;
    try {
      if (_previewTrack == _PreviewTrack.original) {
        final reference = _reference;
        if (reference == null) return;
        final sourceDelta = widget.referencePosition() - reference.start;
        final wallMilliseconds = sourceDelta.inMilliseconds / reference.speed;
        final value = Duration(
          milliseconds: wallMilliseconds.round().clamp(
            0,
            _previewDuration.inMilliseconds,
          ),
        );
        if (mounted) {
          setState(() {
            _previewPosition = value;
            _previewPlaying = widget.referenceIsPlaying();
          });
        }
      } else {
        final snapshot = await _recorder.playbackSnapshot();
        if (mounted) {
          setState(() {
            _previewPosition = _clampPreviewPosition(snapshot.position);
            _previewPlaying = snapshot.isPlaying;
          });
        }
      }
    } on Object {
      if (mounted) setState(() => _previewPlaying = false);
    } finally {
      _pollingPreview = false;
    }
  }

  Duration get _previewDuration => _draft?.duration ?? Duration.zero;

  Duration _clampPreviewPosition(Duration value) {
    if (value.isNegative) return Duration.zero;
    final duration = _previewDuration;
    return duration > Duration.zero && value > duration ? duration : value;
  }

  Duration _sourcePositionForPreview(Duration relativePosition) {
    final reference = _reference!;
    var target =
        reference.start +
        Duration(
          milliseconds: (relativePosition.inMilliseconds * reference.speed)
              .round(),
        );
    final end = reference.end;
    if (end != null && target > end) target = end;
    return target;
  }

  Future<void> _togglePreviewPlayback() async {
    if (_phase != _RecordingPhase.preview || _draft == null) return;
    try {
      if (_previewPlaying) {
        if (_previewTrack == _PreviewTrack.original) {
          await widget.pauseReference();
        } else {
          await _recorder.pausePlayback();
        }
        if (mounted) setState(() => _previewPlaying = false);
        return;
      }
      if (_previewPosition >= _previewDuration) {
        _previewPosition = Duration.zero;
      }
      if (_previewTrack == _PreviewTrack.original) {
        await _recorder.stopPlayback();
        await widget.seekReference(_sourcePositionForPreview(_previewPosition));
        await widget.playReference();
      } else {
        await widget.pauseReference();
        await _recorder.playRecording(
          _draft!.relativePath,
          position: _previewPosition,
        );
      }
      if (mounted) setState(() => _previewPlaying = true);
    } on Object {
      if (mounted) setState(() => _message = '无法播放当前音轨，请重试。');
    }
  }

  Future<void> _selectPreviewTrack(_PreviewTrack track) async {
    if (track == _previewTrack || _phase != _RecordingPhase.preview) return;
    await _pollPreview();
    final shouldResume = _previewPlaying;
    try {
      if (_previewTrack == _PreviewTrack.original) {
        await widget.pauseReference();
      } else {
        await _recorder.pausePlayback();
      }
      if (!mounted) return;
      setState(() {
        _previewTrack = track;
        _previewPlaying = false;
      });
      if (shouldResume) await _togglePreviewPlayback();
    } on Object {
      if (mounted) setState(() => _message = '切换音轨失败，请重试。');
    }
  }

  Future<void> _seekPreview(Duration position) async {
    final value = _clampPreviewPosition(position);
    setState(() => _previewPosition = value);
    try {
      if (_previewTrack == _PreviewTrack.original) {
        await widget.seekReference(_sourcePositionForPreview(value));
      } else {
        final snapshot = await _recorder.playbackSnapshot();
        if (snapshot.isLoaded) await _recorder.seekPlayback(value);
      }
    } on Object {
      if (mounted) setState(() => _message = '无法跳转到这个位置。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      key: const Key('practice_recording_panel'),
      margin: EdgeInsets.zero,
      color: colors.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_phase) {
            _RecordingPhase.idle => _buildIdle(context),
            _RecordingPhase.countdown => _buildCountdown(context),
            _RecordingPhase.recording => _buildRecording(context),
            _RecordingPhase.preview ||
            _RecordingPhase.saving => _buildPreview(context),
          },
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('recording_idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.mic_none_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '录下这次练习',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '录音会保存当前 A-B 区间、位置与倍速。建议佩戴耳机，减少原曲被麦克风再次录入。',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
        ),
        if (_message case final message?) ...[
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 12),
        if (_permissionPermanentlyDenied)
          OutlinedButton.icon(
            key: const Key('practice_recording_open_settings'),
            onPressed: _recorder.openAppSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('打开系统设置'),
          )
        else
          FilledButton.icon(
            key: const Key('practice_recording_start'),
            onPressed: widget.enabled ? _beginRecording : null,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('3 秒倒计时后开始录音'),
          ),
      ],
    );
  }

  Widget _buildCountdown(BuildContext context) {
    return Column(
      key: const ValueKey('recording_countdown'),
      children: [
        Text('准备演奏', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '${_recordingElapsed.inSeconds}',
          style: Theme.of(context).textTheme.displayMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        TextButton(onPressed: _cancelWorkflow, child: const Text('取消')),
      ],
    );
  }

  Widget _buildRecording(BuildContext context) {
    return Column(
      key: const ValueKey('recording_active'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fiber_manual_record,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              '正在录音  ${_formatDuration(_recordingElapsed)}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _cancelWorkflow,
                child: const Text('取消并删除'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('practice_recording_stop'),
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('停止录音'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final durationMilliseconds = _previewDuration.inMilliseconds;
    return Column(
      key: const ValueKey('recording_preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '对比并保存',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_PreviewTrack>(
          segments: const [
            ButtonSegment(
              value: _PreviewTrack.original,
              icon: Icon(Icons.music_note_rounded),
              label: Text('原曲'),
            ),
            ButtonSegment(
              value: _PreviewTrack.take,
              icon: Icon(Icons.mic_rounded),
              label: Text('我的录音'),
            ),
          ],
          selected: {_previewTrack},
          onSelectionChanged: (value) =>
              unawaited(_selectPreviewTrack(value.first)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.filledTonal(
              key: const Key('practice_recording_preview_play_pause'),
              onPressed: _togglePreviewPlayback,
              icon: Icon(
                _previewPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            Expanded(
              child: Slider(
                value: _previewPosition.inMilliseconds
                    .clamp(0, durationMilliseconds)
                    .toDouble(),
                min: 0,
                max: durationMilliseconds > 0
                    ? durationMilliseconds.toDouble()
                    : 1,
                onChanged: durationMilliseconds > 0
                    ? (value) => setState(
                        () => _previewPosition = Duration(
                          milliseconds: value.round(),
                        ),
                      )
                    : null,
                onChangeEnd: durationMilliseconds > 0
                    ? (value) => unawaited(
                        _seekPreview(Duration(milliseconds: value.round())),
                      )
                    : null,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Text(
            '${_formatDuration(_previewPosition)} / '
            '${_formatDuration(_previewDuration)} · '
            '${_reference?.speed.toStringAsFixed(2) ?? '1.00'}x',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _title,
          enabled: _phase != _RecordingPhase.saving,
          decoration: const InputDecoration(
            labelText: '录音名称',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _title = value,
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _note,
          enabled: _phase != _RecordingPhase.saving,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '练习感受（可选）',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _note = value,
        ),
        if (_message case final message?) ...[
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _phase == _RecordingPhase.saving
                    ? null
                    : _cancelWorkflow,
                child: const Text('删除重录'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('practice_recording_save'),
                onPressed: _phase == _RecordingPhase.saving
                    ? null
                    : () => _saveRecording(),
                icon: _phase == _RecordingPhase.saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存录音'),
              ),
            ),
          ],
        ),
        if (widget.planId != null) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('practice_recording_save_outcome'),
            onPressed: _phase == _RecordingPhase.saving
                ? null
                : () => _saveRecording(asPlanOutcome: true),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('保存为本计划成果'),
          ),
          const SizedBox(height: 6),
          Text(
            '成果会进入这个计划的时间线，便于和以后录制的版本对比。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

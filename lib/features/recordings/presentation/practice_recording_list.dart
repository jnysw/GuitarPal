import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../../../domain/practice_segment/practice_segment.dart';
import '../practice_recording_providers.dart';
import 'practice_audio_analysis_sheet.dart';

class PracticeRecordingList extends ConsumerStatefulWidget {
  const PracticeRecordingList({
    required this.sourceId,
    required this.segments,
    required this.canStartPractice,
    this.onStartPractice,
    super.key,
  });

  final String sourceId;
  final List<PracticeSegment> segments;
  final bool canStartPractice;
  final VoidCallback? onStartPractice;

  @override
  ConsumerState<PracticeRecordingList> createState() =>
      _PracticeRecordingListState();
}

class _PracticeRecordingListState extends ConsumerState<PracticeRecordingList>
    with WidgetsBindingObserver {
  late final PracticeAudioRecorder _recorder;
  Timer? _ticker;
  String? _activeRecordingId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(practiceAudioRecorderProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_stopPlaybackSilently());
    super.dispose();
  }

  Future<void> _stopPlaybackSilently() async {
    try {
      await _recorder.stopPlayback();
    } on Object {
      // The platform channel may already be detached during route teardown.
    }
  }

  Future<void> _toggle(PracticeRecording recording) async {
    try {
      if (_activeRecordingId == recording.id && _isPlaying) {
        await _pause();
        return;
      }
      final resumeAt = _activeRecordingId == recording.id
          ? _position
          : Duration.zero;
      await _recorder.playRecording(recording.filePath, position: resumeAt);
      if (!mounted) return;
      setState(() {
        _activeRecordingId = recording.id;
        _position = resumeAt;
        _duration = recording.duration;
        _isPlaying = true;
      });
      _ticker ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_poll()),
      );
    } on Object {
      if (mounted) _showMessage('无法播放这条录音');
    }
  }

  Future<void> _pause() async {
    try {
      await _recorder.pausePlayback();
    } on Object {
      // The player may already have been released by Android lifecycle cleanup.
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _poll() async {
    if (_polling || _activeRecordingId == null || !mounted) return;
    _polling = true;
    try {
      final snapshot = await _recorder.playbackSnapshot();
      if (!mounted) return;
      setState(() {
        _position = snapshot.position;
        if (snapshot.duration > Duration.zero) _duration = snapshot.duration;
        _isPlaying = snapshot.isPlaying;
      });
    } on Object {
      if (mounted) setState(() => _isPlaying = false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await _recorder.seekPlayback(position);
      if (mounted) setState(() => _position = position);
    } on Object {
      if (mounted) _showMessage('无法跳转录音进度');
    }
  }

  Future<void> _edit(PracticeRecording recording) async {
    await _pause();
    if (!mounted) return;
    final result = await showDialog<_RecordingEditResult>(
      context: context,
      builder: (context) => _RecordingEditDialog(recording: recording),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(practiceRecordingRepositoryProvider)
          .save(
            recording.copyWith(
              title: result.title,
              note: result.note.trim().isEmpty ? null : result.note.trim(),
            ),
          );
      if (mounted) _showMessage('录音信息已更新');
    } on Object {
      if (mounted) _showMessage('更新录音失败，请稍后重试');
    }
  }

  Future<void> _promoteToOutcome(PracticeRecording recording) async {
    if (recording.planId == null) return;
    await _pause();
    try {
      await ref
          .read(practiceRecordingRepositoryProvider)
          .save(recording.copyWith(kind: PracticeRecordingKind.planOutcome));
      if (mounted) _showMessage('已保存为计划成果');
    } on Object {
      if (mounted) _showMessage('保存计划成果失败，请稍后重试');
    }
  }

  Future<void> _analyze(PracticeRecording recording) async {
    await _pause();
    if (!mounted) return;
    await showPracticeAudioAnalysis(context, recording);
  }

  Future<void> _delete(PracticeRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除练习录音？'),
        content: Text('「${recording.title}」及其本地音频文件将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_practice_recording'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (_activeRecordingId == recording.id) {
        await _recorder.stopPlayback();
        if (mounted) {
          setState(() {
            _activeRecordingId = null;
            _position = Duration.zero;
            _duration = Duration.zero;
            _isPlaying = false;
          });
        }
      }
      await ref.read(practiceRecordingRepositoryProvider).delete(recording.id);
      try {
        await _recorder.deleteRecording(recording.filePath);
      } on Object {
        // Metadata is removed first. An unreachable private file can be
        // reclaimed later without making the deleted item reappear.
      }
      if (mounted) _showMessage('录音已删除');
    } on Object {
      if (mounted) _showMessage('删除录音失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final recordings = ref.watch(
      practiceRecordingsForSourceProvider(widget.sourceId),
    );
    final segmentNames = {
      for (final segment in widget.segments) segment.id: segment.title,
    };
    return recordings.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) =>
          const _RecordingMessageCard(message: '暂时无法读取练习录音，请稍后重试。'),
      data: (items) {
        final takes = items
            .where((item) => item.kind == PracticeRecordingKind.segmentTake)
            .toList(growable: false);
        if (takes.isEmpty) {
          return _RecordingEmptyCard(
            canStartPractice: widget.canStartPractice,
            onStartPractice: widget.onStartPractice,
          );
        }
        return Column(
          children: takes
              .map(
                (recording) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PracticeRecordingCard(
                    recording: recording,
                    segmentTitle: recording.segmentId == null
                        ? null
                        : segmentNames[recording.segmentId],
                    isActive: _activeRecordingId == recording.id,
                    isPlaying: _activeRecordingId == recording.id && _isPlaying,
                    position: _activeRecordingId == recording.id
                        ? _position
                        : Duration.zero,
                    playbackDuration: _activeRecordingId == recording.id
                        ? _duration
                        : recording.duration,
                    onPlayPause: () => _toggle(recording),
                    onSeek: _activeRecordingId == recording.id ? _seek : null,
                    onEdit: () => _edit(recording),
                    onAnalyze: () => _analyze(recording),
                    onPromote: recording.planId == null
                        ? null
                        : () => _promoteToOutcome(recording),
                    onDelete: () => _delete(recording),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _PracticeRecordingCard extends StatelessWidget {
  const _PracticeRecordingCard({
    required this.recording,
    required this.segmentTitle,
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.playbackDuration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onEdit,
    required this.onAnalyze,
    required this.onPromote,
    required this.onDelete,
  });

  final PracticeRecording recording;
  final String? segmentTitle;
  final bool isActive;
  final bool isPlaying;
  final Duration position;
  final Duration playbackDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback onEdit;
  final VoidCallback onAnalyze;
  final VoidCallback? onPromote;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final durationMs = playbackDuration.inMilliseconds;
    return Card(
      key: ValueKey('practice_recording_${recording.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filledTonal(
                  key: ValueKey('play_recording_${recording.id}'),
                  tooltip: isPlaying ? '暂停录音' : '播放录音',
                  onPressed: onPlayPause,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording.title,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _formatDateTime(recording.recordedAt),
                          _formatDuration(recording.duration),
                          '${recording.referenceSpeed.toStringAsFixed(2)}x',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_RecordingAction>(
                  key: ValueKey('recording_menu_${recording.id}'),
                  tooltip: '录音操作',
                  onSelected: (action) => switch (action) {
                    _RecordingAction.edit => onEdit(),
                    _RecordingAction.analyze => onAnalyze(),
                    _RecordingAction.promote => onPromote?.call(),
                    _RecordingAction.delete => onDelete(),
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _RecordingAction.edit,
                      child: Text('编辑名称与复盘'),
                    ),
                    const PopupMenuItem(
                      value: _RecordingAction.analyze,
                      child: Text('音频分析（实验）'),
                    ),
                    if (onPromote != null)
                      const PopupMenuItem(
                        value: _RecordingAction.promote,
                        child: Text('保存为计划成果'),
                      ),
                    const PopupMenuItem(
                      value: _RecordingAction.delete,
                      child: Text('删除录音'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _RecordingChip(
                  icon: Icons.repeat_rounded,
                  text: _formatReferenceRange(recording),
                ),
                if (segmentTitle != null)
                  _RecordingChip(
                    icon: Icons.bookmark_outline_rounded,
                    text: segmentTitle!,
                  ),
              ],
            ),
            if (recording.note case final note?) ...[
              const SizedBox(height: 10),
              Text(note),
            ],
            if (isActive) ...[
              const SizedBox(height: 4),
              Slider(
                value: position.inMilliseconds.clamp(0, durationMs).toDouble(),
                min: 0,
                max: durationMs > 0 ? durationMs.toDouble() : 1,
                onChanged: onSeek == null || durationMs <= 0
                    ? null
                    : (value) => onSeek!(Duration(milliseconds: value.round())),
                onChangeEnd: onSeek == null || durationMs <= 0
                    ? null
                    : (value) => onSeek!(Duration(milliseconds: value.round())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${_formatDuration(position)} / '
                  '${_formatDuration(playbackDuration)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordingChip extends StatelessWidget {
  const _RecordingChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _RecordingEmptyCard extends StatelessWidget {
  const _RecordingEmptyCard({
    required this.canStartPractice,
    required this.onStartPractice,
  });

  final bool canStartPractice;
  final VoidCallback? onStartPractice;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              canStartPractice
                  ? '还没有练习录音。进入播放器后，可以录下整曲或当前 A-B 片段并与原曲切换回听。'
                  : '此来源还没有练习录音。',
            ),
            if (canStartPractice && onStartPractice != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onStartPractice,
                icon: const Icon(Icons.mic_none_rounded),
                label: const Text('开始练习并录音'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordingMessageCard extends StatelessWidget {
  const _RecordingMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

class _RecordingEditDialog extends StatefulWidget {
  const _RecordingEditDialog({required this.recording});

  final PracticeRecording recording;

  @override
  State<_RecordingEditDialog> createState() => _RecordingEditDialogState();
}

class _RecordingEditDialogState extends State<_RecordingEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recording.title);
    _noteController = TextEditingController(text: widget.recording.note ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _RecordingEditResult(title: title, note: _noteController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('编辑练习录音'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('practice_recording_title_field'),
              controller: _titleController,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: '录音名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('practice_recording_note_field'),
              controller: _noteController,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: '练习复盘（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

class _RecordingEditResult {
  const _RecordingEditResult({required this.title, required this.note});

  final String title;
  final String note;
}

enum _RecordingAction { edit, analyze, promote, delete }

String _formatReferenceRange(PracticeRecording recording) {
  final start = _formatDuration(recording.referenceStart);
  final end = recording.referenceEnd;
  return end == null ? '从 $start 开始' : '$start–${_formatDuration(end)}';
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month}月${local.day}日 '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

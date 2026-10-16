import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/practice_audio_recorder.dart';
import '../../../domain/practice_plan/practice_plan.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../../library/practice_source_providers.dart';
import '../../plans/practice_plan_providers.dart';
import '../practice_recording_providers.dart';
import 'practice_audio_analysis_sheet.dart';

class PlanOutcomeRecordingsScreen extends ConsumerStatefulWidget {
  const PlanOutcomeRecordingsScreen({required this.planId, super.key});

  final String planId;

  @override
  ConsumerState<PlanOutcomeRecordingsScreen> createState() =>
      _PlanOutcomeRecordingsScreenState();
}

class _PlanOutcomeRecordingsScreenState
    extends ConsumerState<PlanOutcomeRecordingsScreen>
    with WidgetsBindingObserver {
  late final PracticeAudioRecorder _recorder;
  Timer? _ticker;
  List<PracticeRecording> _outcomes = const [];
  final Set<String> _comparisonIds = {};
  String? _activeRecordingId;
  String? _sequenceNextId;
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
    unawaited(_stopSilently());
    super.dispose();
  }

  Future<void> _stopSilently() async {
    try {
      await _recorder.stopPlayback();
    } on Object {
      // The Android channel may already be detached during route teardown.
    }
  }

  PracticeRecording? _recordingById(String? id) {
    if (id == null) return null;
    for (final recording in _outcomes) {
      if (recording.id == id) return recording;
    }
    return null;
  }

  Future<void> _play(
    PracticeRecording recording, {
    Duration? position,
    bool preserveSequence = false,
  }) async {
    final requested =
        position ??
        (_activeRecordingId == recording.id ? _position : Duration.zero);
    final target = requested >= recording.duration ? Duration.zero : requested;
    if (!preserveSequence) _sequenceNextId = null;
    try {
      await _recorder.playRecording(recording.filePath, position: target);
      if (!mounted) return;
      setState(() {
        _activeRecordingId = recording.id;
        _position = target;
        _duration = recording.duration;
        _isPlaying = true;
      });
      _ticker ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => unawaited(_poll()),
      );
    } on Object {
      if (mounted) _showMessage('无法播放这条成果录音');
    }
  }

  Future<void> _toggle(PracticeRecording recording) async {
    if (_activeRecordingId == recording.id && _isPlaying) {
      await _pause();
    } else {
      await _play(recording);
    }
  }

  Future<void> _pause() async {
    _sequenceNextId = null;
    try {
      await _recorder.pausePlayback();
    } on Object {
      // Playback may already have been released by Android lifecycle cleanup.
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _poll() async {
    if (_polling || _activeRecordingId == null || !mounted) return;
    _polling = true;
    try {
      final snapshot = await _recorder.playbackSnapshot();
      if (!mounted) return;
      final completed =
          snapshot.isLoaded &&
          !snapshot.isPlaying &&
          snapshot.duration > Duration.zero &&
          snapshot.position >=
              snapshot.duration - const Duration(milliseconds: 200);
      setState(() {
        _position = snapshot.position;
        if (snapshot.duration > Duration.zero) _duration = snapshot.duration;
        _isPlaying = snapshot.isPlaying;
      });
      final next = completed ? _recordingById(_sequenceNextId) : null;
      if (next != null) {
        _sequenceNextId = null;
        await _play(next, position: Duration.zero, preserveSequence: true);
      }
    } on Object {
      if (mounted) setState(() => _isPlaying = false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _seek(Duration position) async {
    final active = _recordingById(_activeRecordingId);
    final maximum = active?.duration ?? _duration;
    var target = position;
    if (target.isNegative) target = Duration.zero;
    if (maximum > Duration.zero && target > maximum) target = maximum;
    if (mounted) setState(() => _position = target);
    try {
      final snapshot = await _recorder.playbackSnapshot();
      if (snapshot.isLoaded) await _recorder.seekPlayback(target);
    } on Object {
      // The selected track may not be loaded yet; play starts at this position.
    }
  }

  void _toggleComparisonSelection(PracticeRecording recording) {
    if (_comparisonIds.contains(recording.id)) {
      setState(() => _comparisonIds.remove(recording.id));
      return;
    }
    if (_comparisonIds.length >= 2) {
      _showMessage('最多选择两条成果进行对比');
      return;
    }
    setState(() => _comparisonIds.add(recording.id));
  }

  Future<void> _switchComparisonTrack(PracticeRecording recording) async {
    final shouldResume = _isPlaying;
    final sharedPosition = _position;
    try {
      await _recorder.stopPlayback();
      if (!mounted) return;
      setState(() {
        _activeRecordingId = recording.id;
        _position = sharedPosition > recording.duration
            ? recording.duration
            : sharedPosition;
        _duration = recording.duration;
        _isPlaying = false;
        _sequenceNextId = null;
      });
      if (shouldResume) await _play(recording, position: _position);
    } on Object {
      if (mounted) _showMessage('切换成果录音失败');
    }
  }

  Future<void> _playSequence(List<PracticeRecording> recordings) async {
    if (recordings.length != 2) return;
    final ordered = [...recordings]
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    _sequenceNextId = ordered.last.id;
    await _play(ordered.first, position: Duration.zero, preserveSequence: true);
  }

  Future<void> _delete(PracticeRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除计划成果？'),
        content: Text('「${recording.title}」及其本地音频文件将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_plan_outcome'),
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
        _activeRecordingId = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
      }
      _comparisonIds.remove(recording.id);
      await ref.read(practiceRecordingRepositoryProvider).delete(recording.id);
      try {
        await _recorder.deleteRecording(recording.filePath);
      } on Object {
        // Keep the deleted metadata removed even if private-file cleanup fails.
      }
      if (mounted) _showMessage('计划成果已删除');
    } on Object {
      if (mounted) _showMessage('删除计划成果失败，请稍后重试');
    }
  }

  Future<void> _analyze(PracticeRecording recording) async {
    await _pause();
    if (!mounted) return;
    await showPracticeAudioAnalysis(context, recording);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(practicePlanByIdProvider(widget.planId));
    return Scaffold(
      appBar: AppBar(title: const Text('成果录音')),
      body: SafeArea(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _CenteredMessage(message: '暂时无法读取这个计划。'),
          data: (value) => value == null
              ? const _CenteredMessage(message: '这个练习计划已不存在。')
              : _buildPlan(context, value),
        ),
      ),
    );
  }

  Widget _buildPlan(BuildContext context, PracticePlan plan) {
    final recordings = ref.watch(practiceRecordingsForPlanProvider(plan.id));
    final source = ref.watch(practiceSourceByIdProvider(plan.sourceId));
    final sourceExists = source.asData?.value != null;
    final sourceTitle = source.asData?.value?.title ?? '练习内容';
    return recordings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _CenteredMessage(message: '暂时无法读取成果录音。'),
      data: (items) {
        final outcomes =
            items
                .where((item) => item.kind == PracticeRecordingKind.planOutcome)
                .toList(growable: false)
              ..sort(
                (left, right) => right.recordedAt.compareTo(left.recordedAt),
              );
        _outcomes = outcomes;
        final comparison = outcomes
            .where((item) => _comparisonIds.contains(item.id))
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _PlanOutcomeHeader(
              plan: plan,
              sourceTitle: sourceTitle,
              outcomeCount: outcomes.length,
              canRecord: sourceExists,
              onRecord: () => _startPractice(context, plan),
            ),
            if (comparison.length == 2) ...[
              const SizedBox(height: 16),
              _ComparisonPanel(
                recordings: comparison,
                activeRecordingId: _activeRecordingId,
                isPlaying: _isPlaying,
                position: _position,
                onSwitch: _switchComparisonTrack,
                onPlayPause: (recording) => _toggle(recording),
                onSeek: _seek,
                onPlaySequence: () => _playSequence(comparison),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '成果时间线',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${outcomes.length} 条'),
              ],
            ),
            const SizedBox(height: 10),
            if (outcomes.isEmpty)
              _EmptyOutcomeCard(
                canRecord: sourceExists,
                onRecord: () => _startPractice(context, plan),
              )
            else
              for (final recording in outcomes) ...[
                _OutcomeTimelineCard(
                  recording: recording,
                  selected: _comparisonIds.contains(recording.id),
                  isActive: _activeRecordingId == recording.id,
                  isPlaying: _activeRecordingId == recording.id && _isPlaying,
                  position: _activeRecordingId == recording.id
                      ? _position
                      : Duration.zero,
                  onSelect: () => _toggleComparisonSelection(recording),
                  onPlayPause: () => _toggle(recording),
                  onSeek: _activeRecordingId == recording.id ? _seek : null,
                  onAnalyze: () => _analyze(recording),
                  onDelete: () => _delete(recording),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }

  void _startPractice(BuildContext context, PracticePlan plan) {
    final sourceId = Uri.encodeComponent(plan.sourceId);
    final planId = Uri.encodeQueryComponent(plan.id);
    final segmentId = plan.segmentId;
    final query = segmentId == null
        ? 'planId=$planId'
        : 'planId=$planId&segmentId=${Uri.encodeQueryComponent(segmentId)}';
    context.push('/practice/$sourceId?$query');
  }
}

class _PlanOutcomeHeader extends StatelessWidget {
  const _PlanOutcomeHeader({
    required this.plan,
    required this.sourceTitle,
    required this.outcomeCount,
    required this.canRecord,
    required this.onRecord,
  });

  final PracticePlan plan;
  final String sourceTitle;
  final int outcomeCount;
  final bool canRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('$sourceTitle · 已保存 $outcomeCount 次阶段成果'),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('plan_outcomes_record_new'),
              onPressed: canRecord ? onRecord : null,
              icon: const Icon(Icons.mic_rounded),
              label: const Text('录制新的计划成果'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.recordings,
    required this.activeRecordingId,
    required this.isPlaying,
    required this.position,
    required this.onSwitch,
    required this.onPlayPause,
    required this.onSeek,
    required this.onPlaySequence,
  });

  final List<PracticeRecording> recordings;
  final String? activeRecordingId;
  final bool isPlaying;
  final Duration position;
  final ValueChanged<PracticeRecording> onSwitch;
  final ValueChanged<PracticeRecording> onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlaySequence;

  @override
  Widget build(BuildContext context) {
    final ordered = [...recordings]
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    final older = ordered.first;
    final newer = ordered.last;
    final active = ordered.firstWhere(
      (item) => item.id == activeRecordingId,
      orElse: () => older,
    );
    final maximum = older.duration < newer.duration
        ? older.duration
        : newer.duration;
    final mismatched =
        older.segmentId != newer.segmentId ||
        older.referenceStart != newer.referenceStart ||
        older.referenceEnd != newer.referenceEnd;
    return Card(
      key: const Key('plan_outcome_comparison'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '两次成果对比',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: older.id,
                  label: Text('较早 · ${_shortDate(older.recordedAt)}'),
                ),
                ButtonSegment(
                  value: newer.id,
                  label: Text('较新 · ${_shortDate(newer.recordedAt)}'),
                ),
              ],
              selected: {active.id},
              onSelectionChanged: (ids) {
                final selected = ids.first;
                onSwitch(selected == older.id ? older : newer);
              },
            ),
            if (mismatched) ...[
              const SizedBox(height: 10),
              const Text('两次录音的片段区间不同，请结合各自区间信息谨慎比较。'),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('plan_outcome_compare_play_pause'),
                  onPressed: () => onPlayPause(active),
                  icon: Icon(
                    isPlaying && activeRecordingId == active.id
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('plan_outcome_compare_slider'),
                    value: position.inMilliseconds
                        .clamp(0, maximum.inMilliseconds)
                        .toDouble(),
                    min: 0,
                    max: maximum > Duration.zero
                        ? maximum.inMilliseconds.toDouble()
                        : 1,
                    onChanged: maximum > Duration.zero
                        ? (value) =>
                              onSeek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                ),
              ],
            ),
            Text(
              '${_formatDuration(position)} / ${_formatDuration(maximum)}',
              textAlign: TextAlign.end,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('plan_outcome_play_sequence'),
              onPressed: onPlaySequence,
              icon: const Icon(Icons.queue_music_rounded),
              label: const Text('较早录音 → 较新录音顺序回听'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutcomeTimelineCard extends StatelessWidget {
  const _OutcomeTimelineCard({
    required this.recording,
    required this.selected,
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.onSelect,
    required this.onPlayPause,
    required this.onSeek,
    required this.onAnalyze,
    required this.onDelete,
  });

  final PracticeRecording recording;
  final bool selected;
  final bool isActive;
  final bool isPlaying;
  final Duration position;
  final VoidCallback onSelect;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback onAnalyze;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('plan_outcome_${recording.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  key: ValueKey('play_plan_outcome_${recording.id}'),
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
                      Text(
                        '${_formatDateTime(recording.recordedAt)} · '
                        '${_formatDuration(recording.duration)} · '
                        '${recording.referenceSpeed.toStringAsFixed(2)}x',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('delete_plan_outcome_${recording.id}'),
                  tooltip: '删除成果',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_formatReferenceRange(recording)),
            if (recording.note case final note?) ...[
              const SizedBox(height: 8),
              Text(note),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  key: ValueKey('select_plan_outcome_${recording.id}'),
                  selected: selected,
                  onSelected: (_) => onSelect(),
                  avatar: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: Text(selected ? '已加入对比' : '选择对比'),
                ),
                ActionChip(
                  key: ValueKey('analyze_plan_outcome_${recording.id}'),
                  onPressed: onAnalyze,
                  avatar: const Icon(Icons.graphic_eq_rounded, size: 18),
                  label: const Text('音频分析（实验）'),
                ),
              ],
            ),
            if (isActive) ...[
              Slider(
                value: position.inMilliseconds
                    .clamp(0, recording.duration.inMilliseconds)
                    .toDouble(),
                min: 0,
                max: recording.duration > Duration.zero
                    ? recording.duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: onSeek == null
                    ? null
                    : (value) => onSeek!(Duration(milliseconds: value.round())),
              ),
              Text(
                '${_formatDuration(position)} / '
                '${_formatDuration(recording.duration)}',
                textAlign: TextAlign.end,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyOutcomeCard extends StatelessWidget {
  const _EmptyOutcomeCard({required this.canRecord, required this.onRecord});

  final bool canRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('还没有计划成果。从本计划进入练习，录音预览时选择“保存为本计划成果”。'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: canRecord ? onRecord : null,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('去录制第一个成果'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String _formatReferenceRange(PracticeRecording recording) {
  final start = _formatDuration(recording.referenceStart);
  final end = recording.referenceEnd;
  return end == null
      ? '参考原曲：从 $start 开始'
      : '参考原曲：$start–${_formatDuration(end)}';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}年${local.month}月${local.day}日 '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

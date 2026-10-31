import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import '../../../media/playback/local_video_playback_controller.dart';
import '../../segments/presentation/practice_segment_card.dart';
import '../../segments/presentation/practice_segment_progress_slider.dart';
import '../../segments/presentation/practice_segment_timecode.dart';
import 'playback_volume_control.dart';
import 'precise_playback_speed_control.dart';

/// One transport and persistent in-page tools; switching tools never replaces a player.
class PracticeWorkspace extends StatefulWidget {
  const PracticeWorkspace({
    super.key,
    required this.controller,
    required this.segments,
    required this.selectedSection,
    required this.onSelectSection,
    required this.recordingPanel,
    required this.onSaveSegment,
    required this.onActivateSegment,
    required this.onEditSegment,
    required this.onDeleteSegment,
    this.analysisPanel,
    this.chordStrip,
    this.recordingActive = false,
    this.keyboardVisible = false,
  });
  final LocalVideoPlaybackController controller;
  final AsyncValue<List<PracticeSegment>> segments;
  final int selectedSection;
  final ValueChanged<int> onSelectSection;
  final Widget recordingPanel;
  final Widget? analysisPanel, chordStrip;
  final bool recordingActive, keyboardVisible;
  final VoidCallback onSaveSegment;
  final ValueChanged<PracticeSegment> onActivateSegment,
      onEditSegment,
      onDeleteSegment;

  @override
  State<PracticeWorkspace> createState() => _PracticeWorkspaceState();
}

class _PracticeWorkspaceState extends State<PracticeWorkspace> {
  // Keep each panel's position in its own mounted ScrollPosition. Avoid sharing
  // PageStorage identifiers with ExpansionTiles inside analysis and recording.
  final _scrollControllers = List.generate(
    4,
    (_) => ScrollController(keepScrollOffset: false),
  );
  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller, segments = widget.segments;
    final selectedSection = widget.selectedSection,
        onSelectSection = widget.onSelectSection;
    final recordingPanel = widget.recordingPanel,
        analysisPanel = widget.analysisPanel,
        chordStrip = widget.chordStrip;
    final recordingActive = widget.recordingActive,
        onSaveSegment = widget.onSaveSegment;
    final onActivateSegment = widget.onActivateSegment,
        onEditSegment = widget.onEditSegment,
        onDeleteSegment = widget.onDeleteSegment;
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 340 || widget.keyboardVisible;
        final colors = Theme.of(context).colorScheme;
        Widget scroll(int index, String key, Widget child) =>
            SingleChildScrollView(
              key: ValueKey(key),
              controller: _scrollControllers[index],
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: child,
                ),
              ),
            );
        return Column(
          children: [
            if (!(constraints.maxHeight < 220 && widget.keyboardVisible))
              _PracticeTransport(
                controller: controller,
                segments: segments.asData?.value ?? const [],
                onActivateSegment: onActivateSegment,
              ),
            if (chordStrip != null && !short) chordStrip,
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  for (final entry in [
                    (0, '循环', Icons.repeat_rounded),
                    if (analysisPanel != null)
                      (1, '音频', Icons.graphic_eq_rounded),
                    (2, '录音', Icons.mic_none_rounded),
                    (3, '片段', Icons.bookmarks_outlined),
                  ])
                    Expanded(
                      child: Semantics(
                        selected: selectedSection == entry.$1,
                        button: true,
                        child: Tooltip(
                          message: entry.$2 == '音频' ? '和弦与分轨' : entry.$2,
                          child: InkWell(
                            key: Key('practice_section_${entry.$1}'),
                            onTap: recordingActive && entry.$1 != 2
                                ? null
                                : () => onSelectSection(entry.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selectedSection == entry.$1
                                    ? colors.primaryContainer.withValues(
                                        alpha: .45,
                                      )
                                    : null,
                                border: Border(
                                  bottom: BorderSide(
                                    width: 2,
                                    color: selectedSection == entry.$1
                                        ? colors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    entry.$3,
                                    size: 18,
                                    color: selectedSection == entry.$1
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      entry.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: selectedSection == entry.$1
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: selectedSection,
                sizing: StackFit.expand,
                children: [
                  scroll(
                    0,
                    'practice_loop_scroll',
                    _PracticeLoopCard(
                      controller: controller,
                      onSave: onSaveSegment,
                    ),
                  ),
                  scroll(
                    1,
                    'practice_audio_scroll',
                    analysisPanel ?? const SizedBox.shrink(),
                  ),
                  scroll(2, 'practice_recording_scroll', recordingPanel),
                  scroll(
                    3,
                    'practice_segments_scroll',
                    _PracticeSegments(
                      segments: segments,
                      canSave: controller.loopController.range != null,
                      onSave: onSaveSegment,
                      onActivate: onActivateSegment,
                      onEdit: onEditSegment,
                      onDelete: onDeleteSegment,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PracticeTransport extends StatelessWidget {
  const _PracticeTransport({
    required this.controller,
    required this.segments,
    required this.onActivateSegment,
  });
  final LocalVideoPlaybackController controller;
  final List<PracticeSegment> segments;
  final ValueChanged<PracticeSegment> onActivateSegment;
  Future<void> _settings(BuildContext context, {required bool speed}) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            speed ? '调节练习倍速' : '调节音量',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭播放设置',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (speed)
                      PrecisePlaybackSpeedControl(
                        value: controller.speed,
                        enabled: controller.isReady,
                        onChanged: (_) {},
                        onChangeEnd: (value) =>
                            unawaited(controller.setSpeed(value)),
                      )
                    else
                      PlaybackVolumeControl(
                        value: controller.volume,
                        enabled: controller.isReady,
                        onChanged: controller.previewVolume,
                        onChangeEnd: (value) =>
                            unawaited(controller.setVolume(value)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = controller.isReady && controller.duration > Duration.zero;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.playerError case final error?)
              Text(error, maxLines: 2, style: TextStyle(color: colors.error))
            else if (!controller.isReady || !controller.hasVideoFrame)
              Text(
                controller.isReady ? '正在渲染视频画面…' : '正在读取视频…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            PracticeSegmentProgressSlider(
              duration: controller.duration,
              position: controller.position,
              segments: segments,
              enabled: ready,
              sliderKey: const Key('local_video_position_slider'),
              onChanged: (v) =>
                  controller.previewPosition(Duration(milliseconds: v.round())),
              onChangeEnd: (v) =>
                  controller.seek(Duration(milliseconds: v.round())),
              onSegmentTap: onActivateSegment,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _time(controller.position),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _time(controller.duration),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 64,
                  child: TextButton(
                    key: const Key('practice_speed_settings'),
                    onPressed: ready
                        ? () => _settings(context, speed: true)
                        : null,
                    child: FittedBox(
                      child: Text('${controller.speed.toStringAsFixed(2)}×'),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '后退 5 秒',
                  onPressed: ready
                      ? () =>
                            controller.seekRelative(const Duration(seconds: -5))
                      : null,
                  icon: const Icon(Icons.replay_5_rounded),
                ),
                IconButton.filled(
                  key: const Key('local_video_play_pause'),
                  tooltip: controller.isPlaying ? '暂停' : '播放',
                  iconSize: 30,
                  constraints: const BoxConstraints(
                    minWidth: 52,
                    minHeight: 48,
                  ),
                  onPressed: ready
                      ? () => controller.isPlaying
                            ? controller.pause()
                            : controller.play()
                      : null,
                  icon: Icon(
                    controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: '前进 5 秒',
                  onPressed: ready
                      ? () =>
                            controller.seekRelative(const Duration(seconds: 5))
                      : null,
                  icon: const Icon(Icons.forward_5_rounded),
                ),
                SizedBox(
                  width: 64,
                  child: IconButton(
                    key: const Key('practice_volume_settings'),
                    tooltip: '调节音量',
                    onPressed: ready
                        ? () => _settings(context, speed: false)
                        : null,
                    icon: Icon(
                      controller.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeLoopCard extends StatelessWidget {
  const _PracticeLoopCard({required this.controller, required this.onSave});
  final LocalVideoPlaybackController controller;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) {
    final loop = controller.loopController;
    final ready = controller.isReady && controller.duration > Duration.zero;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '反复练好这一段',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('播放到目标位置设定 A、B 点，即可循环练习。'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('local_video_set_loop_a'),
                    onPressed: ready ? controller.setLoopStart : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          const Text('设为 A'),
                          FittedBox(
                            child: Text(
                              loop.start == null
                                  ? '起点'
                                  : formatPracticeTimecode(loop.start!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('local_video_set_loop_b'),
                    onPressed: ready
                        ? () {
                            if (!controller.setLoopEnd()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('B 点必须晚于 A 点')),
                              );
                            }
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          const Text('设为 B'),
                          FittedBox(
                            child: Text(
                              loop.end == null
                                  ? '终点'
                                  : formatPracticeTimecode(loop.end!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('循环播放区间'),
              subtitle: Text('已完成 ${loop.completedLoops} 次'),
              value: loop.enabled,
              onChanged: ready && loop.range != null
                  ? controller.setLoopEnabled
                  : null,
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: loop.range == null ? null : controller.clearLoop,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('清除区间'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('local_video_save_loop_segment'),
                  onPressed: loop.range == null ? null : onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('保存为片段'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeSegments extends StatelessWidget {
  const _PracticeSegments({
    required this.segments,
    required this.canSave,
    required this.onSave,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });
  final AsyncValue<List<PracticeSegment>> segments;
  final bool canSave;
  final VoidCallback onSave;
  final ValueChanged<PracticeSegment> onActivate, onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '我的练习片段',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        key: const Key('local_video_save_loop_segment'),
        onPressed: canSave ? onSave : null,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('保存当前区间'),
      ),
      const SizedBox(height: 12),
      segments.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('暂时无法读取已保存片段'),
        data: (items) => items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.bookmarks_outlined, size: 36),
                    SizedBox(height: 12),
                    Text('还没有练习片段'),
                    SizedBox(height: 4),
                    Text(
                      '在「循环」中设置 A、B 点并保存，下次可直接回到这一段。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  for (final segment in items)
                    PracticeSegmentCard(
                      cardKey: ValueKey('local_segment_${segment.id}'),
                      segment: segment,
                      onOpen: () => onActivate(segment),
                      onEdit: () => onEdit(segment),
                      onDelete: () => onDelete(segment),
                    ),
                ],
              ),
      ),
    ],
  );
}

String _time(Duration value) =>
    '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

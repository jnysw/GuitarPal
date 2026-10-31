import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/playback/local_video_playback_controller.dart';
import '../../chords/chord_providers.dart';
import 'chord_practice_sheet.dart';
import 'scrolling_chord_lane.dart';
import '../../audio_tools/algorithm_providers.dart';
import '../../audio_tools/domain/algorithm_task.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_analysis_binding.dart';
import '../../audio_tools/domain/video_chord_playback.dart';

/// Always visible beside the video; independent of the analysis panel's expansion.
class VideoChordPlaybackStrip extends ConsumerStatefulWidget {
  const VideoChordPlaybackStrip({
    super.key,
    required this.sourceId,
    required this.path,
    required this.controller,
    required this.onCalibrate,
    this.compact = false,
    this.showTimeline = true,
    this.enabled = true,
  });
  final String sourceId, path;
  final LocalVideoPlaybackController controller;
  final VoidCallback onCalibrate;
  final bool compact, enabled, showTimeline;
  @override
  ConsumerState<VideoChordPlaybackStrip> createState() =>
      _VideoChordPlaybackStripState();
}

class _VideoChordPlaybackStripState
    extends ConsumerState<VideoChordPlaybackStrip> {
  List<AlgorithmTaskRecord>? _cachedTasks;
  VideoChordPlayback? _playback;
  String? _cachedPath, _cachedSource;

  @override
  Widget build(BuildContext context) {
    final tasks =
        ref.watch(algorithmTasksProvider).asData?.value ??
        const <AlgorithmTaskRecord>[];
    if (!identical(tasks, _cachedTasks) ||
        _cachedPath != widget.path ||
        _cachedSource != widget.sourceId) {
      _cachedTasks = tasks;
      _cachedPath = widget.path;
      _cachedSource = widget.sourceId;
      _playback = null;
      // Newest valid result for this file. Failed/pending tasks do not hide usable results.
      for (final task in tasks) {
        if (task.linkedSourceId != widget.sourceId ||
            task.operation != AlgorithmOperation.chords ||
            task.resultJson == null ||
            task.mediaBindingJson == null) {
          continue;
        }
        try {
          final binding = VideoAnalysisBinding.fromJson(
            algorithmObject(jsonDecode(task.mediaBindingJson!)),
          );
          if (!binding.matches(
            widget.sourceId,
            widget.path,
            File(widget.path).statSync(),
          )) {
            continue;
          }
          final result = LegacyChordResult.fromJson(
            algorithmObject(jsonDecode(task.resultJson!)),
          );
          if (binding.manualChordZeroMs != null &&
              binding.manualChordZeroMs! + result.duration.inMilliseconds >
                  binding.endMs + 20) {
            continue;
          }
          _playback = VideoChordPlayback(result, binding);
          break;
        } on Object {
          continue;
        }
      }
    }
    final playback = _playback;
    if (playback == null) return const SizedBox.shrink();
    final showDiagrams =
        ref.watch(chordPreferencesProvider).asData?.value.showDiagrams ?? false;
    final data = playback;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final position = widget.controller.position.inMilliseconds;
        final current = data.current(position);
        final label = current?.displayLabel ?? '—';
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: colors.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前和弦 $label',
                            key: const Key('video_current_chord'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: widget.compact ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          Text(
                            '下一和弦 ${data.next(position)?.displayLabel ?? '—'} · 调性 ${data.result.keyEstimate.isEmpty ? '未知' : data.result.keyEstimate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            data.calibrated ? '已人工校准' : '按分析区间起点显示 · 静音偏移待校准',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (showDiagrams)
                      ChordVoicingCard(
                        rawLabel: current?.rawLabel,
                        displayLabel: label,
                        thumbnail: true,
                        compact: widget.compact,
                      ),
                    if (showDiagrams &&
                        !widget.compact &&
                        MediaQuery.sizeOf(context).width >= 600)
                      ChordVoicingCard(
                        rawLabel: data.next(position)?.rawLabel,
                        displayLabel: data.next(position)?.displayLabel ?? '—',
                        thumbnail: true,
                      ),
                    IconButton(
                      key: const Key('video_chord_settings'),
                      tooltip: '指法设置',
                      onPressed: widget.enabled
                          ? () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => ChordPracticeSheet(
                                playback: data,
                                controller: widget.controller,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.back_hand_outlined),
                    ),
                    TextButton(
                      onPressed: widget.enabled ? widget.onCalibrate : null,
                      child: const Text('校准'),
                    ),
                  ],
                ),
                if (widget.showTimeline)
                  ScrollingChordLane(
                    playback: data,
                    positionMs: position,
                    playing: widget.controller.isPlaying,
                    compact: widget.compact,
                    enabled: widget.enabled,
                    onSeek: (target) async {
                      if (!data.binding.matches(
                            widget.sourceId,
                            widget.path,
                            await File(widget.path).stat(),
                          ) ||
                          !mounted) {
                        return;
                      }
                      await widget.controller.seek(
                        Duration(milliseconds: target),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

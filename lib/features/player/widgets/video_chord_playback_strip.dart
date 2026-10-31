import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/playback/local_video_playback_controller.dart';
import '../../chords/chord_providers.dart';
import 'chord_practice_sheet.dart';
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
    this.enabled = true,
  });
  final String sourceId, path;
  final LocalVideoPlaybackController controller;
  final VoidCallback onCalibrate;
  final bool compact, enabled;
  @override
  ConsumerState<VideoChordPlaybackStrip> createState() =>
      _VideoChordPlaybackStripState();
}

class _VideoChordPlaybackStripState
    extends ConsumerState<VideoChordPlaybackStrip> {
  final _scroll = ScrollController();
  int? _lastIndex;
  String? _taskId;
  bool _follow = true;
  List<AlgorithmTaskRecord>? _cachedTasks;
  VideoChordPlayback? _playback;
  AlgorithmTaskRecord? _selected;
  String? _cachedPath, _cachedSource;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
      _selected = null;
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
          _selected = task;
          break;
        } on Object {
          continue;
        }
      }
    }
    final playback = _playback;
    final selected = _selected;
    if (playback == null) return const SizedBox.shrink();
    final showDiagrams =
        ref.watch(chordPreferencesProvider).asData?.value.showDiagrams ?? false;
    final data = playback;
    if (_taskId != selected!.id) {
      _taskId = selected.id;
      _lastIndex = null;
      _follow = true;
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final position = widget.controller.position.inMilliseconds;
        final index = data.currentIndex(position);
        if (index != _lastIndex) {
          _lastIndex = index;
          if (_follow && index != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scroll.hasClients && _follow) {
                unawaited(
                  _scroll.animateTo(
                    (index * 88.0 - _scroll.position.viewportDimension / 2 + 44)
                        .clamp(0.0, _scroll.position.maxScrollExtent),
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                  ),
                );
              }
            });
          }
        }
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
                if (!widget.compact)
                  Row(
                    children: [
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollStartNotification &&
                                n.dragDetails != null &&
                                _follow) {
                              setState(() => _follow = false);
                            }
                            return false;
                          },
                          child: SizedBox(
                            height: 55,
                            child: ListView.builder(
                              controller: _scroll,
                              scrollDirection: Axis.horizontal,
                              itemExtent: 88,
                              itemCount: data.result.segments.length,
                              itemBuilder: (context, i) {
                                final s = data.result.segments[i];
                                final target = data.sourceStart(s);
                                final active = index == i;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Material(
                                    color: active
                                        ? colors.primaryContainer
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap:
                                          !widget.enabled ||
                                              target < data.binding.startMs ||
                                              target >= data.binding.endMs
                                          ? null
                                          : () async {
                                              if (!data.binding.matches(
                                                    widget.sourceId,
                                                    widget.path,
                                                    await File(widget.path)
                                                        .stat(),
                                                  ) ||
                                                  !mounted) {
                                                return;
                                              }
                                              await widget.controller.seek(
                                                Duration(milliseconds: target),
                                              );
                                            },
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              s.displayLabel,
                                              style: TextStyle(
                                                fontWeight: active
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            Text(
                                              '${target ~/ 60000}:${(target ~/ 1000 % 60).toString().padLeft(2, '0')}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '跟随播放',
                        isSelected: _follow,
                        onPressed: () => setState(() {
                          _follow = true;
                          _lastIndex = null;
                        }),
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

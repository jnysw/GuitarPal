import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio_tools/domain/video_chord_playback.dart';

/// A virtualized source-time lane. One second has one width at every speed.
class ScrollingChordLane extends StatefulWidget {
  const ScrollingChordLane({
    super.key,
    required this.playback,
    required this.positionMs,
    required this.playing,
    required this.onSeek,
    this.enabled = true,
    this.compact = false,
  });
  final VideoChordPlayback playback;
  final int positionMs;
  final bool playing, enabled, compact;
  final ValueChanged<int> onSeek;
  @override
  State<ScrollingChordLane> createState() => _ScrollingChordLaneState();
}

class _ScrollingChordLaneState extends State<ScrollingChordLane> {
  final _scroll = ScrollController(keepScrollOffset: false);
  bool _follow = true, _queued = false, _jumpNext = true;
  double _width = 0;
  double get _pixelsPerMs => _width / 8000;
  double get _anchor => _width / 3;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_scrolled);
  }

  void _scrolled() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ScrollingChordLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback.result.jobId != widget.playback.result.jobId ||
        oldWidget.playback.zeroMs != widget.playback.zeroMs ||
        oldWidget.playback.binding.inputSha256 !=
            widget.playback.binding.inputSha256) {
      _follow = true;
      _jumpNext = true;
    }
    if (oldWidget.positionMs != widget.positionMs ||
        oldWidget.playing != widget.playing ||
        _jumpNext) {
      _queueFollow();
    }
  }

  void _queueFollow() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || !_follow || !_scroll.hasClients || _width <= 0) return;
      final start = widget.playback.binding.startMs;
      final target = ((widget.positionMs - start) * _pixelsPerMs).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      final delta = target - _scroll.offset;
      final smooth =
          !_jumpNext &&
          widget.playing &&
          delta > 0 &&
          delta < _pixelsPerMs * 1500 &&
          !MediaQuery.disableAnimationsOf(context);
      _jumpNext = false;
      if (delta.abs() < .1) return;
      if (smooth) {
        unawaited(
          _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.linear,
          ),
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_scrolled);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (!width.isFinite || width <= 0) return const SizedBox.shrink();
      if (_width != width) {
        _width = width;
        _jumpNext = true;
        _queueFollow();
      }
      final data = widget.playback;
      final start = data.binding.startMs, end = data.binding.endMs;
      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
      final leftMs = start + ((offset - _anchor) / _pixelsPerMs).floor();
      final rightMs =
          start + ((offset + width - _anchor) / _pixelsPerMs).ceil();
      final segments = data.result.segments;
      // Binary search by end time; only visible cells are laid out, including gaps.
      var lo = 0, hi = segments.length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        if (data.zeroMs + segments[mid].end.inMilliseconds < leftMs) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      final visible = <int>[];
      for (
        var i = lo;
        i < segments.length && data.sourceStart(segments[i]) <= rightMs;
        i++
      ) {
        if (data.sourceStart(segments[i]) < end &&
            data.zeroMs + segments[i].end.inMilliseconds > start) {
          visible.add(i);
        }
      }
      final colors = Theme.of(context).colorScheme;
      final active = data.currentIndex(widget.positionMs);
      final height = widget.compact ? 46.0 : 58.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _follow ? '和弦跟练 · 随播放滚动' : '正在浏览和弦',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TextButton(
                key: const Key('chord_lane_follow'),
                onPressed: () => setState(() {
                  _follow = true;
                  _jumpNext = true;
                  _queueFollow();
                }),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(_follow ? '跟随中' : '回到当前'),
              ),
            ],
          ),
          SizedBox(
            height: height,
            child: Stack(
              children: [
                NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null && _follow) {
                      setState(() => _follow = false);
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    key: const Key('chord_follow_scroll'),
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: width + (end - start) * _pixelsPerMs,
                      height: height,
                      child: Stack(
                        children: [
                          for (final i in visible)
                            Positioned(
                              left:
                                  _anchor +
                                  (math.max(
                                            start,
                                            data.sourceStart(segments[i]),
                                          ) -
                                          start) *
                                      _pixelsPerMs,
                              width: math.max(
                                1.0,
                                (math.min(
                                          end,
                                          data.zeroMs +
                                              segments[i].end.inMilliseconds,
                                        ) -
                                        math.max(
                                          start,
                                          data.sourceStart(segments[i]),
                                        )) *
                                    _pixelsPerMs,
                              ),
                              top: 0,
                              bottom: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Material(
                                  key: Key('chord_follow_cell_$i'),
                                  color: i == active
                                      ? colors.primaryContainer
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  child: InkWell(
                                    onTap:
                                        !widget.enabled ||
                                            data.sourceStart(segments[i]) <
                                                start
                                        ? null
                                        : () => widget.onSeek(
                                            data.sourceStart(segments[i]),
                                          ),
                                    child: Semantics(
                                      selected: i == active,
                                      label:
                                          '${segments[i].displayLabel}，视频 ${data.sourceStart(segments[i]) / 1000} 秒',
                                      child: Center(
                                        child: ClipRect(
                                          child: Text(
                                            segments[i].displayLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: i == active
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                              color: i == active
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_follow)
                  Positioned(
                    left: _anchor - 1,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        key: const Key('chord_follow_cursor'),
                        width: 2,
                        color: colors.primary,
                      ),
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

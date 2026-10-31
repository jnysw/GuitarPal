import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../media/playback/loop_controller.dart';

/// All coordinates are original-video milliseconds, including calibrated chords.
class VideoTimelineChord {
  const VideoTimelineChord({
    required this.startMs,
    required this.endMs,
    required this.label,
  });
  final int startMs, endMs;
  final String label;
}

class VideoAnalysisTimeline extends StatefulWidget {
  const VideoAnalysisTimeline({
    required this.startMs,
    required this.endMs,
    required this.positionMs,
    required this.waveform,
    required this.onSeek,
    required this.onLoop,
    this.chords = const [],
    this.loop,
    this.loopEnabled = false,
    this.enabled = true,
    this.onSaveLoop,
    super.key,
  }) : assert(endMs > startMs);
  final int startMs, endMs, positionMs;
  final List<double> waveform;
  final List<VideoTimelineChord> chords;
  final LoopRange? loop;
  final bool loopEnabled, enabled;
  final ValueChanged<int> onSeek;
  final ValueChanged<LoopRange> onLoop;
  final VoidCallback? onSaveLoop;

  @override
  State<VideoAnalysisTimeline> createState() => _VideoAnalysisTimelineState();
}

class _VideoAnalysisTimelineState extends State<VideoAnalysisTimeline> {
  final _scroll = ScrollController();
  int _zoom = 1;
  bool _follow = true, _frameScheduled = false;
  int? _anchor, _selectedEnd, _draftA, _draftB;
  double _viewport = 0;
  int get _duration => widget.endMs - widget.startMs;
  double get _width => _viewport * _zoom;
  int? get _a => _draftA ?? widget.loop?.start.inMilliseconds;
  int? get _b => _draftB ?? widget.loop?.end.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) setState(() {}); // Only visible chord blocks are materialized.
  }

  @override
  void didUpdateWidget(covariant VideoAnalysisTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startMs != widget.startMs ||
        oldWidget.endMs != widget.endMs ||
        oldWidget.chords.length != widget.chords.length ||
        (widget.chords.isNotEmpty &&
            oldWidget.chords.isNotEmpty &&
            oldWidget.chords.first.startMs != widget.chords.first.startMs)) {
      _anchor = _selectedEnd = null;
      _draftA = _draftB = null;
    }
    if (oldWidget.positionMs != widget.positionMs) _scheduleFollow();
  }

  void _scheduleFollow() {
    if (!_follow || _frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted ||
          !_follow ||
          !_scroll.hasClients ||
          _viewport <= 0 ||
          widget.positionMs < widget.startMs ||
          widget.positionMs > widget.endMs) {
        return;
      }
      final x = _x(widget.positionMs);
      final offset = _scroll.offset;
      if (x < offset + _viewport * .15 || x > offset + _viewport * .85) {
        _scroll.jumpTo(
          (x - _viewport / 2).clamp(0.0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  double _x(int ms) => (ms - widget.startMs) / _duration * _width;
  int _timeAt(double x) => (widget.startMs + x / _width * _duration)
      .round()
      .clamp(widget.startMs, widget.endMs);

  void _changeZoom(int value) {
    final center = _scroll.hasClients
        ? _timeAt(_scroll.offset + _viewport / 2)
        : widget.positionMs;
    setState(() => _zoom = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final ms = _follow ? widget.positionMs : center;
      _scroll.jumpTo(
        (_x(ms) - _viewport / 2).clamp(0.0, _scroll.position.maxScrollExtent),
      );
    });
  }

  void _select(int index, {bool extend = false}) {
    setState(() {
      if (!extend || _anchor == null) _anchor = index;
      _selectedEnd = index;
    });
    if (!extend) {
      widget.onSeek(
        widget.chords[index].startMs.clamp(widget.startMs, widget.endMs),
      );
    }
  }

  LoopRange? get _selection {
    final anchor = _anchor, end = _selectedEnd;
    if (anchor == null ||
        end == null ||
        anchor >= widget.chords.length ||
        end >= widget.chords.length) {
      return null;
    }
    final first = widget.chords[math.min(anchor, end)].startMs.clamp(
      widget.startMs,
      widget.endMs,
    );
    final last = widget.chords[math.max(anchor, end)].endMs.clamp(
      widget.startMs,
      widget.endMs,
    );
    return last > first
        ? LoopRange(
            start: Duration(milliseconds: first),
            end: Duration(milliseconds: last),
          )
        : null;
  }

  void _drag(bool a, double delta) {
    final start = _a, end = _b;
    if (start == null || end == null) return;
    final change = (delta / _width * _duration).round();
    setState(() {
      _follow = false;
      _draftA = a ? (start + change).clamp(widget.startMs, end - 1) : start;
      _draftB = a ? end : (end + change).clamp(start + 1, widget.endMs);
    });
  }

  void _commitDrag() {
    if (_draftA != null && _draftB != null && widget.enabled) {
      widget.onLoop(
        LoopRange(
          start: Duration(milliseconds: _draftA!),
          end: Duration(milliseconds: _draftB!),
        ),
      );
    }
    setState(() => _draftA = _draftB = null);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selection = _selection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            IconButton(
              tooltip: '缩小时间轴',
              onPressed: _zoom > 1 ? () => _changeZoom(_zoom ~/ 2) : null,
              icon: const Icon(Icons.zoom_out),
            ),
            Text('$_zoom×'),
            IconButton(
              tooltip: '放大时间轴',
              onPressed: _zoom < 16 ? () => _changeZoom(_zoom * 2) : null,
              icon: const Icon(Icons.zoom_in),
            ),
            FilterChip(
              label: const Text('跟随播放'),
              selected: _follow,
              onSelected: (v) {
                setState(() => _follow = v);
                _scheduleFollow();
              },
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (_viewport != constraints.maxWidth) {
              _viewport = constraints.maxWidth;
              _scheduleFollow();
            }
            final left = _scroll.hasClients
                ? _scroll.offset - _viewport
                : -_viewport;
            final right = left + _viewport * 3;
            final a = _a, b = _b;
            final hasLoop = a != null && b != null;
            return NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle && _follow) {
                  setState(() => _follow = false);
                }
                return false;
              },
              child: SingleChildScrollView(
                key: const Key('video_analysis_timeline_scroll'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _width,
                  height: 144,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          key: const Key('video_analysis_waveform'),
                          onTapUp: widget.enabled
                              ? (d) =>
                                    widget.onSeek(_timeAt(d.localPosition.dx))
                              : null,
                          child: CustomPaint(
                            painter: _TimelinePainter(
                              startMs: widget.startMs,
                              endMs: widget.endMs,
                              peaks: widget.waveform,
                              color: colors.primary,
                              textColor: colors.onSurfaceVariant,
                              loopStart: a,
                              loopEnd: b,
                              loopEnabled: widget.loopEnabled,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < widget.chords.length; i++)
                        if (_x(widget.chords[i].endMs) >= left &&
                            _x(widget.chords[i].startMs) <= right)
                          Positioned(
                            left: _x(
                              widget.chords[i].startMs.clamp(
                                widget.startMs,
                                widget.endMs,
                              ),
                            ),
                            top: 24,
                            width: math.max(
                              1,
                              _x(
                                    widget.chords[i].endMs.clamp(
                                      widget.startMs,
                                      widget.endMs,
                                    ),
                                  ) -
                                  _x(
                                    widget.chords[i].startMs.clamp(
                                      widget.startMs,
                                      widget.endMs,
                                    ),
                                  ),
                            ),
                            height: 40,
                            child: Semantics(
                              label:
                                  '${widget.chords[i].label}，${_timeLabel(widget.chords[i].startMs)} 至 ${_timeLabel(widget.chords[i].endMs)}',
                              button: true,
                              child: Material(
                                color:
                                    _anchor != null &&
                                        i >=
                                            math.min(_anchor!, _selectedEnd!) &&
                                        i <= math.max(_anchor!, _selectedEnd!)
                                    ? colors.tertiaryContainer
                                    : widget.positionMs >=
                                              widget.chords[i].startMs &&
                                          widget.positionMs <
                                              widget.chords[i].endMs
                                    ? colors.primaryContainer
                                    : colors.surfaceContainerHighest,
                                child: InkWell(
                                  key: Key(
                                    'video_analysis_chord_${widget.chords[i].startMs}',
                                  ),
                                  onTap: widget.enabled
                                      ? () => _select(i)
                                      : null,
                                  onLongPress: widget.enabled
                                      ? () => _select(i, extend: true)
                                      : null,
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.chords[i].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CursorPainter(
                              widget.startMs,
                              widget.endMs,
                              widget.positionMs,
                            ),
                          ),
                        ),
                      ),
                      if (hasLoop)
                        for (final isA in [true, false])
                          if ((isA ? a : b) >= widget.startMs &&
                              (isA ? a : b) <= widget.endMs)
                            Positioned(
                              left: (_x(isA ? a : b) - 14).clamp(
                                0.0,
                                math.max(0.0, _width - 28),
                              ),
                              bottom: 0,
                              child: Semantics(
                                label:
                                    '${isA ? 'A' : 'B'} 点，${_timeLabel(isA ? a : b)}，左右拖动调整',
                                child: GestureDetector(
                                  key: Key(
                                    'video_analysis_handle_${isA ? 'a' : 'b'}',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate:
                                      widget.enabled &&
                                          a >= widget.startMs &&
                                          b <= widget.endMs
                                      ? (d) => _drag(isA, d.delta.dx)
                                      : null,
                                  onHorizontalDragEnd: (_) => _commitDrag(),
                                  onHorizontalDragCancel: () =>
                                      setState(() => _draftA = _draftB = null),
                                  child: Container(
                                    width: 28,
                                    height: 32,
                                    alignment: Alignment.center,
                                    color: colors.tertiaryContainer,
                                    child: Text(isA ? 'A' : 'B'),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.chords.isNotEmpty) ...[
          const Text('点选和弦定位；长按另一和弦可扩展选区。'),
          if (selection != null)
            TextButton.icon(
              key: const Key('video_analysis_selection_loop'),
              onPressed: widget.enabled ? () => widget.onLoop(selection) : null,
              icon: const Icon(Icons.repeat),
              label: Text(
                '选区设为 A-B  ${_timeLabel(selection.start.inMilliseconds)}–${_timeLabel(selection.end.inMilliseconds)}',
              ),
            ),
        ],
        if (widget.loop != null)
          Text(
            'A ${_timeLabel(widget.loop!.start.inMilliseconds)} → B ${_timeLabel(widget.loop!.end.inMilliseconds)} · ${widget.loopEnabled ? '循环已开启' : '循环未开启'}',
          ),
        if (widget.onSaveLoop != null && widget.loop != null)
          TextButton.icon(
            key: const Key('video_analysis_save_loop'),
            onPressed: widget.enabled ? widget.onSaveLoop : null,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('保存 A-B 为练习片段'),
          ),
      ],
    );
  }
}

String _timeLabel(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.startMs,
    required this.endMs,
    required this.peaks,
    required this.color,
    required this.textColor,
    required this.loopStart,
    required this.loopEnd,
    required this.loopEnabled,
  });
  final int startMs, endMs;
  final int? loopStart, loopEnd;
  final List<double> peaks;
  final Color color, textColor;
  final bool loopEnabled;
  @override
  void paint(Canvas canvas, Size size) {
    final duration = endMs - startMs;
    double x(int ms) => (ms - startMs) / duration * size.width;
    final a = loopStart, b = loopEnd;
    if (a != null && b != null && b > startMs && a < endMs) {
      canvas.drawRect(
        Rect.fromLTRB(
          x(a.clamp(startMs, endMs)),
          20,
          x(b.clamp(startMs, endMs)),
          size.height,
        ),
        Paint()..color = color.withValues(alpha: loopEnabled ? .15 : .06),
      );
      for (final ms in [a, b]) {
        if (ms >= startMs && ms <= endMs) {
          canvas.drawLine(
            Offset(x(ms), 20),
            Offset(x(ms), size.height),
            Paint()
              ..color = color
              ..strokeWidth = 2,
          );
        }
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (var i = 0; i < peaks.length; i++) {
      final px = (i + .5) / peaks.length * size.width;
      final half = 22 * peaks[i];
      canvas.drawLine(Offset(px, 88 - half), Offset(px, 88 + half), paint);
    }
    final minStep = duration / size.width * 70;
    final step = [
      100,
      250,
      500,
      1000,
      2000,
      5000,
      10000,
      30000,
      60000,
      120000,
      300000,
      600000,
    ].firstWhere((v) => v >= minStep, orElse: () => 600000);
    for (
      var ms = ((startMs + step - 1) ~/ step) * step;
      ms <= endMs;
      ms += step
    ) {
      final text = TextPainter(
        text: TextSpan(
          text: _timeLabel(ms),
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(x(ms).clamp(0.0, math.max(0.0, size.width - text.width)), 0),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => true;
}

class _CursorPainter extends CustomPainter {
  const _CursorPainter(this.startMs, this.endMs, this.positionMs);
  final int startMs, endMs, positionMs;
  @override
  void paint(Canvas canvas, Size size) {
    if (positionMs < startMs || positionMs > endMs) return;
    final x = (positionMs - startMs) / (endMs - startMs) * size.width;
    canvas.drawLine(
      Offset(x, 20),
      Offset(x, size.height),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CursorPainter oldDelegate) =>
      oldDelegate.startMs != startMs ||
      oldDelegate.endMs != endMs ||
      oldDelegate.positionMs != positionMs;
}

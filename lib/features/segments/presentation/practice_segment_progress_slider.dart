import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import 'practice_segment_timecode.dart';

/// A playback slider with saved practice ranges painted over its track.
///
/// Slider callback values are expressed in milliseconds, matching [Slider]'s
/// `double` API and the player controllers that consume them.
class PracticeSegmentProgressSlider extends StatefulWidget {
  const PracticeSegmentProgressSlider({
    required this.duration,
    required this.position,
    required this.segments,
    required this.enabled,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.onSegmentTap,
    this.sliderKey,
    this.semanticLabel = '播放进度',
    super.key,
  });

  static const markerLayerKey = Key('practice_segment_progress_markers');

  final Duration duration;
  final Duration position;
  final List<PracticeSegment> segments;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final ValueChanged<PracticeSegment>? onSegmentTap;
  final Key? sliderKey;
  final String semanticLabel;

  static const _sliderPadding = EdgeInsets.symmetric(horizontal: 24);

  @override
  State<PracticeSegmentProgressSlider> createState() =>
      _PracticeSegmentProgressSliderState();
}

class _PracticeSegmentProgressSliderState
    extends State<PracticeSegmentProgressSlider> {
  static const _markerHitRadius = 22.0;

  int? _pointer;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;
  double? _dragValue;
  double? _pendingEndValue;
  int _gestureSequence = 0;
  int? _activatedGestureSequence;

  void _handlePointerDown(PointerDownEvent event) {
    _pointer = event.pointer;
    _pointerDownPosition = event.localPosition;
    _pointerMoved = false;
    _pendingEndValue = null;
    _gestureSequence++;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    final origin = _pointerDownPosition;
    if (origin != null &&
        (event.localPosition - origin).distance > kTouchSlop) {
      _pointerMoved = true;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pointer != event.pointer) return;
    _resetPointer();
    _clearDragValue();
  }

  void _handlePointerUp(
    PointerUpEvent event, {
    required List<_SegmentRange> ranges,
    required double width,
    required TextDirection textDirection,
  }) {
    if (_pointer != event.pointer) return;
    final trackWidth =
        width - PracticeSegmentProgressSlider._sliderPadding.horizontal;
    final canActivate =
        !_pointerMoved &&
        widget.enabled &&
        widget.onSegmentTap != null &&
        trackWidth.isFinite &&
        trackWidth > 0;
    _SegmentRange? selectedRange;
    if (canActivate) {
      final pointerX = event.localPosition.dx;
      final candidates =
          ranges
              .map((range) {
                final fraction = textDirection == TextDirection.ltr
                    ? range.startFraction
                    : 1 - range.startFraction;
                final markerX =
                    PracticeSegmentProgressSlider._sliderPadding.left +
                    trackWidth * fraction;
                return (range: range, distance: (markerX - pointerX).abs());
              })
              .where((candidate) => candidate.distance <= _markerHitRadius)
              .toList(growable: false)
            ..sort((left, right) {
              final byDistance = left.distance.compareTo(right.distance);
              if (byDistance != 0) return byDistance;
              final leftLength =
                  left.range.endFraction - left.range.startFraction;
              final rightLength =
                  right.range.endFraction - right.range.startFraction;
              return leftLength.compareTo(rightLength);
            });
      selectedRange = candidates.isEmpty ? null : candidates.first.range;
    }

    _resetPointer();
    _clearDragValue();
    if (selectedRange == null) return;
    _pendingEndValue = null;
    _activatedGestureSequence = _gestureSequence;
    widget.onSegmentTap!(selectedRange.segment);
  }

  void _resetPointer() {
    _pointer = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
  }

  void _handleChangeStart(double value) {
    setState(() => _dragValue = value);
    widget.onChangeStart?.call(value);
  }

  void _handleChanged(double value) {
    setState(() => _dragValue = value);
    widget.onChanged?.call(value);
  }

  void _handleChangeEnd(double value) {
    final gestureSequence = _gestureSequence;
    _pendingEndValue = value;
    Timer.run(() {
      if (!mounted || _pendingEndValue != value) return;
      _pendingEndValue = null;
      if (_activatedGestureSequence == gestureSequence) {
        _activatedGestureSequence = null;
        _clearDragValue();
        return;
      }
      widget.onChangeEnd?.call(value);
      _clearDragValue();
    });
  }

  void _clearDragValue() {
    if (_dragValue == null || !mounted) return;
    setState(() => _dragValue = null);
  }

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = widget.duration.inMilliseconds;
    final hasValidDuration = durationMilliseconds > 0;
    final maximum = hasValidDuration ? durationMilliseconds.toDouble() : 1.0;
    final externalValue = hasValidDuration
        ? widget.position.inMilliseconds
              .clamp(0, durationMilliseconds)
              .toDouble()
        : 0.0;
    final value = (_dragValue ?? externalValue).clamp(0.0, maximum).toDouble();
    final interactive =
        widget.enabled && hasValidDuration && widget.onChanged != null;
    final ranges = hasValidDuration
        ? _normalizedRanges(widget.segments, widget.duration)
        : const <_SegmentRange>[];
    final theme = Theme.of(context);
    final sliderTheme = SliderTheme.of(context);
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final colors = theme.colorScheme;
    final onSegmentTap = widget.enabled && hasValidDuration
        ? widget.onSegmentTap
        : null;

    final painter = _SegmentProgressPainter(
      ranges: ranges,
      progress: hasValidDuration ? value / maximum : 0,
      textDirection: Directionality.of(context),
      trackHeight: trackHeight,
      activeTrackColor: interactive
          ? colors.primary
          : colors.onSurface.withValues(alpha: 0.32),
      inactiveTrackColor: interactive
          ? colors.primary.withValues(alpha: 0.24)
          : colors.onSurface.withValues(alpha: 0.12),
      markerColor: interactive
          ? colors.tertiary
          : colors.onSurface.withValues(alpha: 0.28),
      onSegmentTap: onSegmentTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerCancel: _handlePointerCancel,
          onPointerUp: (event) => _handlePointerUp(
            event,
            ranges: ranges,
            width: constraints.maxWidth,
            textDirection: Directionality.of(context),
          ),
          child: SliderTheme(
            data: sliderTheme.copyWith(
              trackHeight: trackHeight,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              secondaryActiveTrackColor: Colors.transparent,
              disabledActiveTrackColor: Colors.transparent,
              disabledInactiveTrackColor: Colors.transparent,
              disabledSecondaryActiveTrackColor: Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: PracticeSegmentProgressSlider._sliderPadding,
                    child: CustomPaint(
                      key: PracticeSegmentProgressSlider.markerLayerKey,
                      painter: painter,
                    ),
                  ),
                ),
                Slider(
                  key: widget.sliderKey,
                  value: value,
                  min: 0,
                  max: maximum,
                  padding: PracticeSegmentProgressSlider._sliderPadding,
                  label: widget.semanticLabel,
                  semanticFormatterCallback: (rawValue) {
                    final safeValue = rawValue.clamp(0, maximum).round();
                    final current = hasValidDuration
                        ? Duration(milliseconds: safeValue)
                        : Duration.zero;
                    final total = hasValidDuration
                        ? widget.duration
                        : Duration.zero;
                    return '${formatPracticeTimecode(current)} / '
                        '${formatPracticeTimecode(total)}';
                  },
                  onChanged: interactive ? _handleChanged : null,
                  onChangeStart: interactive ? _handleChangeStart : null,
                  onChangeEnd: interactive ? _handleChangeEnd : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<_SegmentRange> _normalizedRanges(
  List<PracticeSegment> segments,
  Duration duration,
) {
  final durationMicroseconds = duration.inMicroseconds;
  if (durationMicroseconds <= 0) return const [];

  final ranges = <_SegmentRange>[];
  for (final segment in segments) {
    final start = segment.start.inMicroseconds.clamp(0, durationMicroseconds);
    final end = segment.end.inMicroseconds.clamp(0, durationMicroseconds);
    if (end <= start) continue;
    ranges.add(
      _SegmentRange(
        segment: segment,
        semanticsKey: ValueKey('practice_segment_marker_${segment.id}'),
        title: segment.title,
        start: Duration(microseconds: start),
        end: Duration(microseconds: end),
        startFraction: start / durationMicroseconds,
        endFraction: end / durationMicroseconds,
      ),
    );
  }
  return ranges;
}

@immutable
final class _SegmentRange {
  const _SegmentRange({
    required this.segment,
    required this.semanticsKey,
    required this.title,
    required this.start,
    required this.end,
    required this.startFraction,
    required this.endFraction,
  });

  final Key semanticsKey;
  final PracticeSegment segment;
  final String title;
  final Duration start;
  final Duration end;
  final double startFraction;
  final double endFraction;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SegmentRange &&
            other.semanticsKey == semanticsKey &&
            other.title == title &&
            other.start == start &&
            other.end == end &&
            other.startFraction == startFraction &&
            other.endFraction == endFraction;
  }

  @override
  int get hashCode =>
      Object.hash(semanticsKey, title, start, end, startFraction, endFraction);
}

final class _SegmentProgressPainter extends CustomPainter {
  const _SegmentProgressPainter({
    required this.ranges,
    required this.progress,
    required this.textDirection,
    required this.trackHeight,
    required this.activeTrackColor,
    required this.inactiveTrackColor,
    required this.markerColor,
    required this.onSegmentTap,
  });

  final List<_SegmentRange> ranges;
  final double progress;
  final TextDirection textDirection;
  final double trackHeight;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color markerColor;
  final ValueChanged<PracticeSegment>? onSegmentTap;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    final safeTrackHeight = trackHeight.clamp(0.0, size.height).toDouble();
    final trackRect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: size.width,
      height: safeTrackHeight,
    );
    final trackRadius = Radius.circular(safeTrackHeight / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      Paint()..color = inactiveTrackColor,
    );

    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    final activeRect = switch (textDirection) {
      TextDirection.ltr => Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        trackRect.left + trackRect.width * safeProgress,
        trackRect.bottom,
      ),
      TextDirection.rtl => Rect.fromLTRB(
        trackRect.right - trackRect.width * safeProgress,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      ),
    };
    if (activeRect.width > 0 && activeRect.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, trackRadius),
        Paint()..color = activeTrackColor,
      );
    }

    final markerHeight = (safeTrackHeight + 4).clamp(6.0, size.height);
    final markerPaint = Paint()..color = markerColor;
    for (final range in ranges) {
      final markerRect = _rangeRect(range, size, markerHeight);
      if (markerRect.width <= 0 || markerRect.height <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          markerRect,
          Radius.circular(markerRect.height / 2),
        ),
        markerPaint,
      );
      canvas.drawCircle(
        Offset(_startX(range, size), centerY),
        5,
        Paint()..color = markerColor,
      );
    }
  }

  double _startX(_SegmentRange range, Size size) {
    return switch (textDirection) {
      TextDirection.ltr => size.width * range.startFraction,
      TextDirection.rtl => size.width * (1 - range.startFraction),
    };
  }

  Rect _rangeRect(_SegmentRange range, Size size, double height) {
    final double leftFraction;
    final double rightFraction;
    switch (textDirection) {
      case TextDirection.ltr:
        leftFraction = range.startFraction;
        rightFraction = range.endFraction;
      case TextDirection.rtl:
        leftFraction = 1 - range.endFraction;
        rightFraction = 1 - range.startFraction;
    }
    return Rect.fromLTRB(
      size.width * leftFraction,
      (size.height - height) / 2,
      size.width * rightFraction,
      (size.height + height) / 2,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder {
    return (size) {
      return ranges
          .map((range) {
            final rect = Rect.fromCenter(
              center: Offset(_startX(range, size), size.height / 2),
              width: 44,
              height: 44,
            ).intersect(Offset.zero & size);
            return CustomPainterSemantics(
              key: range.semanticsKey,
              rect: rect,
              properties: SemanticsProperties(
                label:
                    '练习片段：${range.title}，'
                    '${formatPracticeTimecode(range.start)} 到 '
                    '${formatPracticeTimecode(range.end)}',
                textDirection: textDirection,
                button: onSegmentTap != null,
                enabled: onSegmentTap != null,
                readOnly: onSegmentTap == null,
                hint: onSegmentTap == null ? null : '双击切换到该片段',
                onTap: onSegmentTap == null
                    ? null
                    : () => onSegmentTap!(range.segment),
              ),
            );
          })
          .toList(growable: false);
    };
  }

  @override
  bool shouldRepaint(_SegmentProgressPainter oldDelegate) {
    return !listEquals(oldDelegate.ranges, ranges) ||
        oldDelegate.progress != progress ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.trackHeight != trackHeight ||
        oldDelegate.activeTrackColor != activeTrackColor ||
        oldDelegate.inactiveTrackColor != inactiveTrackColor ||
        oldDelegate.markerColor != markerColor;
  }

  @override
  bool shouldRebuildSemantics(_SegmentProgressPainter oldDelegate) {
    return !listEquals(oldDelegate.ranges, ranges) ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.onSegmentTap != onSegmentTap;
  }

  @override
  bool hitTest(Offset position) => false;
}

import 'legacy_algorithm_models.dart';
import 'video_analysis_binding.dart';

/// Video clock -> analysis clock, once only. Speed never scales source times.
class VideoChordPlayback {
  const VideoChordPlayback(this.result, this.binding);
  final LegacyChordResult result;
  final VideoAnalysisBinding binding;
  bool get automaticAvailable {
    final t = result.timeline;
    return t != null &&
        (t.inputDuration.inMicroseconds - binding.durationMs * 1000).abs() <=
            20000 &&
        t.offset.inMicroseconds + t.analysisDuration.inMicroseconds <=
            binding.durationMs * 1000 + 20000;
  }

  bool get manual => binding.manualChordZeroMs != null;
  bool get automatic => !manual && automaticAvailable;
  int get zeroMs =>
      binding.manualChordZeroMs ??
      (automaticAvailable
          ? binding.startMs + result.timeline!.offsetMs
          : binding.startMs);
  bool get calibrated => manual || automatic;
  String get alignmentLabel => manual
      ? '人工校准'
      : automatic
      ? '自动对齐原音频'
      : '静音偏移待校准';
  int? currentIndex(int sourceMs) {
    if (sourceMs < binding.startMs || sourceMs >= binding.endMs) return null;
    final position = sourceMs - zeroMs;
    var lo = 0, hi = result.segments.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (result.segments[mid].start.inMilliseconds <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final index = lo - 1;
    return index >= 0 && position < result.segments[index].end.inMilliseconds
        ? index
        : null;
  }

  LegacyChordSegment? current(int sourceMs) {
    final index = currentIndex(sourceMs);
    return index == null ? null : result.segments[index];
  }

  LegacyChordSegment? next(int sourceMs) => sourceMs >= binding.endMs
      ? null
      : result.segments
            .where((s) => zeroMs + s.start.inMilliseconds > sourceMs)
            .firstOrNull;
  int sourceStart(LegacyChordSegment segment) =>
      zeroMs + segment.start.inMilliseconds;
}

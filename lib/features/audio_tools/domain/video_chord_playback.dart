import 'legacy_algorithm_models.dart';
import 'video_analysis_binding.dart';

/// Video clock -> analysis clock, once only. Speed never scales source times.
class VideoChordPlayback {
  const VideoChordPlayback(this.result, this.binding);
  final LegacyChordResult result;
  final VideoAnalysisBinding binding;
  int get zeroMs => binding.manualChordZeroMs ?? binding.startMs;
  bool get calibrated => binding.manualChordZeroMs != null;
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

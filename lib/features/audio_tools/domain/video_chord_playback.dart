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

/// Standard open-position voicings, low E to high E. -1 = muted, 0 = open.
/// Unsupported qualities/inversions deliberately have no invented diagram.
const openChordFrets = <String, List<int>>{
  'C': [-1, 3, 2, 0, 1, 0],
  'D': [-1, -1, 0, 2, 3, 2],
  'E': [0, 2, 2, 1, 0, 0],
  'G': [3, 2, 0, 0, 0, 3],
  'A': [-1, 0, 2, 2, 2, 0],
  'Am': [-1, 0, 2, 2, 1, 0],
  'Dm': [-1, -1, 0, 2, 3, 1],
  'Em': [0, 2, 2, 0, 0, 0],
  'A7': [-1, 0, 2, 0, 2, 0],
  'D7': [-1, -1, 0, 2, 1, 2],
  'E7': [0, 2, 0, 1, 0, 0],
  'G7': [3, 2, 0, 0, 0, 1],
  'Cmaj7': [-1, 3, 2, 0, 0, 0],
  'Am7': [-1, 0, 2, 0, 1, 0],
  'Em7': [0, 2, 0, 0, 0, 0],
  'Dsus2': [-1, -1, 0, 2, 3, 0],
  'Dsus4': [-1, -1, 0, 2, 3, 3],
  'Asus2': [-1, 0, 2, 2, 0, 0],
};

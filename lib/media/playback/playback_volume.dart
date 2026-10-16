const double minPlaybackVolume = 0;
const double maxPlaybackVolume = 1;
const double playbackVolumeStep = 0.01;
const int playbackVolumeDivisions = 100;

/// Clamps a finite media volume and rounds it to one percentage point.
double normalizePlaybackVolume(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'must be finite');
  }
  final clamped = value.clamp(minPlaybackVolume, maxPlaybackVolume);
  return (clamped * 100).round() / 100;
}

String formatPlaybackVolume(double value) {
  return '${(normalizePlaybackVolume(value) * 100).round()}%';
}

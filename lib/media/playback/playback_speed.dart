const double minPlaybackSpeed = 0.5;
const double maxPlaybackSpeed = 2.0;
const double minimumPlaybackSpeed = minPlaybackSpeed;
const double maximumPlaybackSpeed = maxPlaybackSpeed;
const double playbackSpeedStep = 0.01;
const int playbackSpeedDivisions = 150;

/// Clamps a finite playback speed and rounds it to the supported 0.01 step.
double normalizePlaybackSpeed(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'must be finite');
  }
  final clamped = value.clamp(minimumPlaybackSpeed, maximumPlaybackSpeed);
  return (clamped * 100).round() / 100;
}

String formatPlaybackSpeed(double value) {
  return '${normalizePlaybackSpeed(value).toStringAsFixed(2)}x';
}

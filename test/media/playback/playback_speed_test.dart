import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/playback_speed.dart';

void main() {
  test('normalizes playback speed to a bounded 0.01 step', () {
    expect(normalizePlaybackSpeed(1.234), 1.23);
    expect(normalizePlaybackSpeed(1.235), 1.24);
    expect(normalizePlaybackSpeed(0.1), minimumPlaybackSpeed);
    expect(normalizePlaybackSpeed(3), maximumPlaybackSpeed);
    expect(() => normalizePlaybackSpeed(double.nan), throwsArgumentError);
  });

  test('formats two decimal places so the precision is visible', () {
    expect(formatPlaybackSpeed(1), '1.00x');
    expect(formatPlaybackSpeed(1.2), '1.20x');
    expect(formatPlaybackSpeed(1.27), '1.27x');
  });
}

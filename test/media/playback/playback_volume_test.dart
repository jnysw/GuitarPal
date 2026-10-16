import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/playback_volume.dart';

void main() {
  test('normalizes volume to one-percent steps inside 0–1', () {
    expect(normalizePlaybackVolume(-1), 0);
    expect(normalizePlaybackVolume(0.236), 0.24);
    expect(normalizePlaybackVolume(2), 1);
  });

  test('rejects non-finite volume and formats percentages', () {
    expect(() => normalizePlaybackVolume(double.nan), throwsArgumentError);
    expect(formatPlaybackVolume(0.42), '42%');
  });
}

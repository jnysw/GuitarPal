import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_chord_playback.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

void main() {
  final raw = jsonDecode(
    File('contracts/legacy_algorithm/fixtures/chords_result.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  final result = LegacyChordResult.fromJson({
    ...raw,
    'duration_seconds': 8,
    'segments': [
      {'chord': 'C:maj', 'roman': 'I', 'start': 0, 'end': 2},
      {'chord': 'E:min', 'roman': 'iii', 'start': 2, 'end': 4},
      {'chord': 'N', 'roman': '', 'start': 5, 'end': 6},
      {'chord': 'X', 'roman': '', 'start': 6, 'end': 8},
    ],
  });
  VideoAnalysisBinding binding({int? zero}) => VideoAnalysisBinding(
    sourceId: 's',
    path: '/test',
    sourceBytes: 1,
    modifiedMs: 1,
    sourceDurationMs: 20000,
    startMs: 3000,
    durationMs: 10000,
    inputSha256: 'a' * 64,
    waveform: [],
    manualChordZeroMs: zero,
  );
  test('video clock follows seek, exact boundaries and loop-back without scaling by playback speed', () {
    final playback = VideoChordPlayback(result, binding());
    expect(playback.calibrated, isFalse);
    for (final ms in [3000, 4999, 3000]) {
      expect(playback.current(ms)?.displayLabel, 'C');
    }
    expect(playback.current(5000)?.displayLabel, 'Em');
    expect(playback.current(7000), isNull); // Gap does not carry a stale chord.
    expect(playback.next(7000)?.displayLabel, '无和弦');
    expect(playback.current(8000)?.displayLabel, '无和弦');
    expect(playback.current(9000)?.displayLabel, '未知');
    expect(playback.current(2999), isNull);
    expect(playback.current(11000), isNull);
    expect(playback.current(13000), isNull);
    expect(playback.next(13000), isNull);
  });
  test('manual offset is applied once and survives serialization', () {
    final b = VideoAnalysisBinding.fromJson(binding(zero: 4000).toJson());
    final p = VideoChordPlayback(result, b);
    expect(p.calibrated, isTrue);
    expect(p.current(5999)?.displayLabel, 'C');
    expect(p.current(6000)?.displayLabel, 'Em');
    expect(p.sourceStart(result.segments[1]), 6000);
  });
  test(
    'common diagrams contain chord tones only and never invent an inversion',
    () {
      const openNotes = [4, 9, 2, 7, 11, 4];
      const tones = {
        'C': {0, 4, 7},
        'D': {2, 6, 9},
        'Em': {4, 7, 11},
        'Am': {9, 0, 4},
        'G': {7, 11, 2},
      };
      for (final entry in tones.entries) {
        final frets = openChordFrets[entry.key]!;
        for (var i = 0; i < 6; i++) {
          if (frets[i] >= 0) {
            expect(
              entry.value.contains((openNotes[i] + frets[i]) % 12),
              isTrue,
              reason: entry.key,
            );
          }
        }
      }
      expect(openChordFrets['C/E'], isNull);
      expect(openChordFrets['未知'], isNull);
    },
  );
}

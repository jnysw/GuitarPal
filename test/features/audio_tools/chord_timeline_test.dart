import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_chord_playback.dart';

void main() {
  final base = jsonDecode(
    File('contracts/legacy_algorithm/fixtures/chords_result.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  Map<String, Object?> mapping() => {
    'version': 1,
    'coordinate_system': 'trimmed_input_seconds',
    'sample_rate_hz': 22050,
    'input_sample_count': 220500,
    'analysis_start_sample': 22050,
    'analysis_sample_count': 176400,
    'frame_hop_samples': 2048,
  };
  VideoAnalysisBinding binding({int? manual, int duration = 10000}) =>
      VideoAnalysisBinding(
        sourceId: 'source',
        path: '/local.mp4',
        sourceBytes: 1,
        modifiedMs: 1,
        sourceDurationMs: 20000,
        startMs: 3000,
        durationMs: duration,
        inputSha256: 'a' * 64,
        waveform: [],
        manualChordZeroMs: manual,
      );
  test('exact sample offset and selected range are applied once, with silence left unlabelled', () {
    final result = LegacyChordResult.fromJson({...base, 'timeline': mapping()});
    final p = VideoChordPlayback(result, binding());
    expect(result.canSyncWithOriginal, isTrue);
    expect(p.automatic, isTrue);
    expect(p.zeroMs, 4000);
    expect(p.current(3999), isNull);
    expect(p.current(4000)!.displayLabel, 'C');
    expect(p.current(7249)!.displayLabel, 'C');
    expect(p.current(7250)!.displayLabel, 'Am');
    expect(p.current(12000), isNull);
    for (final ms in [7250, 8000, 4000, 7250]) {
      expect(p.current(ms)!.displayLabel, ms < 7250 ? 'C' : 'Am');
    }
  });
  test('manual override wins; clearing it restores automatic mapping without rewriting labels', () {
    final r = LegacyChordResult.fromJson({...base, 'timeline': mapping()});
    final b = binding(manual: 3500);
    expect(VideoChordPlayback(r, b).zeroMs, 3500);
    expect(VideoChordPlayback(r, b).manual, isTrue);
    final reset = VideoAnalysisBinding.fromJson(b.withChordZero(null).toJson());
    expect(VideoChordPlayback(r, reset).zeroMs, 4000);
    expect(r.segments.first.start, Duration.zero);
  });
  test('legacy, malformed, unknown and mismatched-input metadata never invent automatic timing', () {
    for (final raw in [
      null,
      {...mapping(), 'version': 2},
      {...mapping(), 'analysis_start_sample': -1},
      {...mapping(), 'analysis_sample_count': 999999},
      {...mapping(), 'sample_rate_hz': double.nan},
      {...mapping(), 'analysis_sample_count': 176400.5},
      {...mapping(), 'frame_hop_samples': 0},
    ]) {
      final r = LegacyChordResult.fromJson({...base, 'timeline': raw});
      expect(r.timeline, isNull);
      expect(VideoChordPlayback(r, binding()).zeroMs, 3000);
      expect(VideoChordPlayback(r, binding()).calibrated, isFalse);
    }
    final r = LegacyChordResult.fromJson({...base, 'timeline': mapping()});
    expect(
      VideoChordPlayback(r, binding(duration: 11000)).automaticAvailable,
      isFalse,
    );
    expect(VideoChordPlayback(r, binding(duration: 11000)).zeroMs, 3000);
  });
  test('sample-count duration handles rounded headers and rejects segment coverage past known audio', () {
    final raw = {
      ...base,
      'duration_seconds': 8.00,
      'segments': [
        {'chord': 'C', 'roman': 'I', 'start': 0.0, 'end': 8.004},
      ],
    };
    final r = LegacyChordResult.fromJson({
      ...raw,
      'timeline': {...mapping(), 'analysis_sample_count': 176488},
    });
    expect(r.timeline, isNotNull);
    final invalid = LegacyChordResult.fromJson({...raw, 'timeline': mapping()});
    expect(
      invalid.timeline,
      isNull,
    ); // labels still usable under legacy bounded-tail policy.
  });
}

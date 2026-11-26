import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/domain/audio_analysis_result.dart';
import 'package:guitar_pal/features/audio_tools/domain/audio_time_mapping.dart';

Map<String, Object?> fixture() => jsonDecode(
  File('contracts/audio/fixtures/chords_offset_v1.json').readAsStringSync(),
) as Map<String, Object?>;

void main() {
  test('30–50s source coordinates are consumed without a second offset', () {
    final result = ChordAnalysisResult.fromJson(fixture());
    expect(result.mapping.sourceOffsetMs, 30000);
    expect(result.currentAt(30000)?.isNoChord, isTrue);
    expect(result.currentAt(32000)?.displayLabel, 'C');
    expect(result.currentAt(36000)?.displayLabel, 'Am');
    expect(result.currentAt(40000)?.isUnknown, isTrue);
    expect(result.currentAt(45000)?.displayLabel, 'C/E');
    expect(result.currentAt(50000), isNull);
    expect(result.currentAt(35000), isNull);
    expect(result.currentAt(29999), isNull);
    expect(result.nextAt(35000)?.displayLabel, 'Am');
    expect(result.segments.every((s) => s.confidence == null), isTrue);
    expect(result.segments.first.canRecommendVoicing, isFalse);
    expect(result.status, AudioJobStatus.partiallySucceeded);
    // Seeking backwards or jumping through A-B re-reads source positions.
    for (final position in [36000, 49999, 32000, 36000]) {
      expect(result.currentAt(position), isNotNull);
    }
    expect(() => result.segments.clear(), throwsUnsupportedError);
  });

  test('rejects overlaps, duplicate ids, bad confidence and implicit trim', () {
    for (final edit in <void Function(Map<String, Object?>)>[
      (j) => segments(j)[1]['start_ms'] = 31000,
      (j) => segments(j)[1]['id'] = 's1',
      (j) => segments(j)[0]['end_ms'] = 30000,
      (j) => segments(j)[0]['confidence'] = double.nan,
      (j) => segments(j)[0]['confidence'] = 1.0,
      (j) => segments(j)[0]['chord_key'] = 'X',
      (j) => (j['mapping'] as Map)['trim_start_ms'] = 1200,
      (j) => (j['coverage'] as Map)['start_ms'] = 0,
      (j) => segments(j).last['end_ms'] = 50001,
      (j) => j['timebase'] = 'input_ms',
      (j) => j['status'] = 'running',
      (j) => j['status'] = 'succeeded',
    ]) {
      final value = fixture();
      edit(value);
      expect(() => ChordAnalysisResult.fromJson(value), throwsFormatException);
    }
    final future = fixture()..['schema_version'] = 2;
    expect(
      () => ChordAnalysisResult.fromJson(future),
      throwsA(isA<UnsupportedAudioResultVersion>()),
    );
  });

  test('a human correction can retain the original unknown machine label', () {
    final value = fixture();
    segments(
      value,
    )[3].addAll({'origin': 'human', 'chord_key': 'G:7', 'display_label': 'G7'});
    final result = ChordAnalysisResult.fromJson(value);
    expect(result.currentAt(40000)?.rawLabel, 'X');
    expect(result.currentAt(40000)?.displayLabel, 'G7');
  });

  test(
    'sample rounding is deterministic and alignment never clamps silently',
    () {
      expect(AudioTimeMapping.samplesToMilliseconds(44100, 44100), 1000);
      expect(AudioTimeMapping.samplesToMilliseconds(24, 48000), 1);
      final mapping = AudioTimeMapping(
        sourceOffsetMs: 30000,
        inputDurationMs: 20000,
        sourceDurationMs: 180000,
        userAlignmentMs: -1000,
      );
      expect(mapping.inputToSource(2000), 32000);
      expect(mapping.sourceToDisplay(32000), 31000);
      expect(() => mapping.sourceToDisplay(0), throwsFormatException);
      expect(
        () => AudioTimeMapping(sourceOffsetMs: 0, inputDurationMs: 1999),
        throwsFormatException,
      );
    },
  );
}

List<Map<String, Object?>> segments(Map<String, Object?> value) =>
    ((value['chords'] as Map)['segments'] as List).cast<Map<String, Object?>>();

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/features/performance/application/performance_comparison_controller.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/domain/performance_comparison.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;

PracticeRecording comparisonRecording(PerformanceTake t, String title) =>
    PracticeRecording(
      id: t.id,
      sourceId: t.sourceId,
      kind: PracticeRecordingKind.performanceTake,
      filePath: t.filePath,
      duration: Duration(milliseconds: t.durationMs),
      referenceStart: Duration(milliseconds: t.preset.startMs),
      referenceSpeed: t.preset.speed,
      title: title,
      recordedAt: t.createdAt,
      performanceContextJson: jsonEncode(t.toJson()),
    );

PerformanceComparison comparisonFixture(Directory root) {
  final c = fixtureCandidate(root);
  final p = BackingPreset.forCandidate(c, {'bass'});
  final a = PerformanceTake.begin('compare-a', c, p, trial: false).update({
    'durationMs': 6200,
    'endSourceMs': 8000,
    'leadMs': 200,
    'createdAt': '2026-10-01T00:00:00Z',
  });
  final b =
      PerformanceTake.begin(
        'compare-b',
        c,
        p.copyWith(speed: .5),
        trial: false,
      ).update({
        'durationMs': 12100,
        'endSourceMs': 8000,
        'leadMs': 200,
        'alignmentMs': 100,
        'createdAt': '2026-11-01T00:00:00Z',
      });
  return PerformanceComparison(
    PerformanceComparisonEntry.fromRecording(comparisonRecording(a, '以前的演奏')),
    PerformanceComparisonEntry.fromRecording(comparisonRecording(b, '这次的演奏')),
  );
}

void main() {
  late Directory root;
  late PerformanceComparison pair;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_compare_');
    pair = comparisonFixture(root);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('common source clock accounts for lead, saved alignment and different speeds exactly once', () {
    expect(pair.startMs, 2000);
    expect(pair.endMs, 8000);
    expect(pair.differentSpeeds, isTrue);
    expect(pair.recordingAt(0, 4000), 2200);
    expect(pair.recordingAt(1, 4000), 4100);
    expect(pair.sourceAt(0, 2200), 4000);
    expect(pair.sourceAt(1, 4100), 4000);
    expect(pair.recordingAt(0, -1), 200);
    expect(pair.sourceAt(1, 999999), 8000);
  });

  test('rejects changed source revision, missing origin, wrong saved identity and disjoint ranges', () {
    final a = pair.first;
    PerformanceComparisonEntry entry(PerformanceTake t) =>
        PerformanceComparisonEntry.fromRecording(
          comparisonRecording(t, 'other'),
        );
    expect(
      () => PerformanceComparison(
        a,
        entry(pair.second.take.update({'sourceBytes': 99})),
      ),
      throwsFormatException,
    );
    expect(
      () => entry(pair.second.take.update({'leadMs': null})),
      throwsFormatException,
    );
    expect(() => PerformanceComparison(a, a), throwsFormatException);
    expect(
      () => PerformanceComparisonEntry.fromRecording(
        a.recording.copyWith(duration: const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
    expect(
      () => PerformanceComparison(
        a,
        entry(
          pair.second.take.update({'durationMs': 800, 'endSourceMs': 2400}),
        ),
      ),
      throwsFormatException,
    );
  });

  test('single player switches at current original position, pauses and respects common end', () async {
    final mic = FakePerformanceMic()
      ..files.addAll([pair.first.take.filePath, pair.second.take.filePath]);
    final extra = FakePerformanceAudio(mic);
    final controller = PerformanceComparisonController(pair, mic, extra);
    try {
      await controller.initialize();
      expect(mic.playing, isFalse);
      await controller.toggle();
      expect(mic.position, 200);
      mic.position = 2200;
      await controller.select(1);
      expect(controller.sourceMs, 4000);
      expect(mic.playbackPath, pair.second.take.filePath);
      expect(mic.position, 4100);
      expect(mic.playing, isTrue);
      await controller.toggle();
      await controller.seek(7000);
      await controller.select(0);
      expect(mic.playing, isFalse);
      await controller.toggle();
      expect(mic.position, 5200);
      await controller.seek(pair.endMs);
      expect(controller.playing, isFalse);
      await controller.toggle();
      expect(mic.position, 200);
      await controller.setVolume(.3);
      expect(extra.volume, .3);
    } finally {
      await controller.close();
      controller.dispose();
    }
  });

  test('late play completion after background cannot resume or switch native audio', () async {
    final mic = FakePerformanceMic()
      ..files.addAll([pair.first.take.filePath, pair.second.take.filePath]);
    final extra = _DelayedAudio(mic);
    final c = PerformanceComparisonController(pair, mic, extra);
    await c.initialize();
    final play = c.toggle();
    await extra.entered.future;
    final stop = c.suspend();
    extra.gate.complete();
    await Future.wait([play, stop]);
    expect(c.playing, isFalse);
    expect(mic.playing, isFalse);
    c.resume();
    expect(mic.playing, isFalse);
    await c.close();
    c.dispose();
  });

  test(
    'missing local files fail without starting audio or needing original media',
    () async {
      final mic = FakePerformanceMic()..files.add(pair.first.take.filePath);
      final c = PerformanceComparisonController(
        pair,
        mic,
        FakePerformanceAudio(mic),
      );
      await c.initialize();
      expect(c.error, contains('丢失'));
      await c.toggle();
      expect(mic.playing, isFalse);
      await c.close();
      c.dispose();
    },
  );

  test('poll stops at common interval before continuing into unrelated trailing audio', () async {
    final mic = FakePerformanceMic()
      ..files.addAll([pair.first.take.filePath, pair.second.take.filePath]);
    final c = PerformanceComparisonController(
      pair,
      mic,
      FakePerformanceAudio(mic),
    );
    await c.initialize();
    await c.toggle();
    mic.position = pair.recordingAt(0, pair.endMs) + 50;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(c.sourceMs, pair.endMs);
    expect(c.playing, isFalse);
    expect(mic.playing, isFalse);
    await c.close();
    c.dispose();
  });
}

class _DelayedAudio extends FakePerformanceAudio {
  _DelayedAudio(super.mic);
  final gate = Completer<void>(), entered = Completer<void>();
  @override
  Future<void> play(String path, int position, double volume) async {
    entered.complete();
    await gate.future;
    await super.play(path, position, volume);
  }
}

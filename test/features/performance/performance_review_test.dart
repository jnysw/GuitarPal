import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/performance/application/performance_review_controller.dart';
import 'package:guitar_pal/features/performance/application/performance_source_resolver.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_stage_controller_test.dart' show StagePlayer, StageStore;

class TakeResolver implements PerformanceSourceResolver {
  TakeResolver(this.candidate);
  final PerformanceCandidate candidate;
  bool missing = false;
  @override
  Future<PerformanceCandidate> lookup(String sourceId, String taskId) async {
    if (missing) throw StateError('missing source');
    return candidate;
  }

  @override
  Future<void> verify(PerformanceCandidate c) async {
    if (missing) throw StateError('missing source');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory root;
  late FakePerformanceMic mic;
  late FakePerformanceAudio extra;
  late StagePlayer player;
  late StageStore store;
  late TakeResolver resolver;
  late PerformanceTake take;
  late PerformanceReviewController review;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_review_');
    final c = fixtureCandidate(root);
    resolver = TakeResolver(c);
    player = StagePlayer();
    store = StageStore(root);
    take = PerformanceTake.begin(
      'take',
      c,
      BackingPreset.forCandidate(c, {'bass'}).copyWith(speed: 1.37),
      trial: false,
    ).update({'durationMs': 2000, 'endSourceMs': 4500, 'leadMs': 120});
    mic = FakePerformanceMic()..files.add(take.filePath);
    extra = FakePerformanceAudio(mic);
    review = PerformanceReviewController(
      take,
      mic,
      extra,
      player,
      store,
      resolver,
    );
  });
  tearDown(() async {
    await review.close();
    review.dispose();
    await player.meter.close();
    root.deleteSync(recursive: true);
  });
  test('review prepares cached backing paused and maps microphone clock through actual speed and estimated lead', () async {
    await review.initialize();
    expect(review.backingReady, isTrue);
    expect(player.plays, 0);
    expect(mic.playing, isFalse);
    await review.toggle();
    expect(mic.playing, isTrue);
    expect(player.playing, isFalse);
    mic.position = 500;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(player.playing, isTrue);
    expect(player.position, ((500 - 120) * 1.37).round());
    await review.setAlignment(100);
    expect(player.position, ((500 - 120 + 100) * 1.37).round());
    await review.pause();
    expect(mic.playing, isFalse);
    expect(player.playing, isFalse);
    expect(store.downloads, 0);
  });
  test('independent gains and backing toggle do not change the recorded preset or microphone file', () async {
    await review.initialize();
    await review.setVolumes(mic: .25, backing: .4);
    expect(extra.volume, .25);
    expect(player.master, closeTo(.32, .0001));
    expect(review.take.preset.master, .8);
    mic.position = 600;
    await review.toggle();
    await review.setBacking(false);
    expect(mic.playing, isTrue);
    expect(player.playing, isFalse);
    await review.setBacking(true);
    expect(mic.files, {take.filePath});
    await review.seek(1000);
    expect(mic.position, 1000);
    expect(mic.playing, isTrue);
  });
  test('missing original or changed revision preserves raw microphone playback without new network requests', () async {
    resolver.missing = true;
    await review.initialize();
    expect(review.backingReady, isFalse);
    expect(review.backingError, isNotNull);
    await review.toggle();
    expect(mic.playing, isTrue);
    expect(player.plays, 0);
    expect(store.downloads, 0);
  });
  test(
    'missing cached backing never downloads and raw playback remains usable',
    () async {
      store.available = false;
      await review.initialize();
      expect(review.backingReady, isFalse);
      expect(store.downloads, 0);
      await review.toggle();
      expect(mic.playing, isTrue);
    },
  );
  test('background and natural end stop both tracks and do not resume automatically', () async {
    await review.initialize();
    await review.toggle();
    mic.position = 500;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await review.suspend();
    expect(mic.playing, isFalse);
    expect(player.playing, isFalse);
    review.resume();
    expect(review.playing, isFalse);
    await review.toggle();
    mic.position = 2000;
    mic.playing = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(review.playing, isFalse);
    expect(player.playing, isFalse);
  });
}

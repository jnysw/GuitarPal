import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/performance/application/performance_export_service.dart';
import 'package:guitar_pal/features/performance/data/performance_export_platform.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_review_test.dart' show TakeResolver;
import 'performance_stage_controller_test.dart' show StageStore;

void main() {
  late Directory root;
  late FakePerformanceMic mic;
  late StageStore store;
  late TakeResolver resolver;
  late PerformanceExportService service;
  late PerformanceTake take;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_export_');
    final c = fixtureCandidate(root);
    resolver = TakeResolver(c);
    mic = FakePerformanceMic();
    store = StageStore(root);
    take =
        PerformanceTake.begin(
          'export-take',
          c,
          BackingPreset.forCandidate(c, {'bass', 'drums'}).copyWith(
            controls: {
              'bass': const StemMixControl(volume: .5, pan: -1, solo: true),
              'drums': const StemMixControl(),
            },
            master: .8,
          ),
          trial: false,
        ).update({
          'durationMs': 2000,
          'endSourceMs': 3500,
          'leadMs': 120,
          'alignmentMs': -50,
          'reviewMicVolume': .6,
          'reviewBackingVolume': .5,
        });
    mic.files.add(take.filePath);
    service = PerformanceExportService(
      mic,
      store,
      resolver,
      const PerformanceExportPlatform(),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));
  test('snapshot maps relative end without adding source offset and freezes solo/gains/pans once', () async {
    final before = take.toJson();
    final m = await service.prepare(take, withBacking: true);
    expect(m['backingEndMs'], 1500);
    expect(m['leadMs'], 120);
    expect(m['alignmentMs'], -50);
    expect(m['micGain'], .6);
    expect(m['backingGain'], .4);
    final tracks = (m['tracks'] as List).cast<Map<String, Object?>>();
    expect(tracks.map((t) => t['gain']), containsAll([.5, 0.0]));
    expect(tracks.map((t) => t['pan']), contains(-1));
    expect(store.downloads, 0);
    expect(take.toJson(), before);
  });
  test('missing cached stem never downloads and explicit mic-only works even if source vanished', () async {
    store.available = false;
    await expectLater(
      service.prepare(take, withBacking: true),
      throwsFormatException,
    );
    resolver.missing = true;
    final m = await service.prepare(take, withBacking: false);
    expect(m['tracks'], isEmpty);
    expect(store.downloads, 0);
    expect(mic.files, {take.filePath});
  });
  test('rejects changed source, trial and non-1x backing but permits mic-only at recorded speed', () async {
    final non1 = take.update({
      'preset': take.preset.copyWith(speed: 1.37).toJson(),
    });
    await expectLater(
      service.prepare(non1, withBacking: true),
      throwsFormatException,
    );
    expect(
      (await service.prepare(non1, withBacking: false))['tracks'],
      isEmpty,
    );
    resolver.missing = true;
    await expectLater(
      service.prepare(take, withBacking: true),
      throwsStateError,
    );
    await expectLater(
      service.prepare(take.update({'trial': true}), withBacking: false),
      throwsFormatException,
    );
  });
  test('revalidates snapshot after rendering and rejects changed cache before exposing output', () async {
    final snapshot = await service.prepare(take, withBacking: true);
    await service.verify(take, snapshot, withBacking: true);
    store.available = false;
    await expectLater(
      service.verify(take, snapshot, withBacking: true),
      throwsFormatException,
    );
    expect(store.downloads, 0);
  });
}

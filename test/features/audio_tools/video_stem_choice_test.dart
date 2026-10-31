import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_mix_selection.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_stem_choice.dart';
import 'package:guitar_pal/features/player/widgets/video_stem_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  final endpoint = AlgorithmEndpoint(
    'https://algorithm.example',
    allowLocalHttp: false,
  );
  LegacySeparationResult result({bool expired = false}) =>
      LegacySeparationResult.fromJson(
        separationFixture(
          expires: expired ? '2000-01-01T00:00:00Z' : '2035-01-01T00:00:00Z',
        ),
        endpoint,
      );

  test('model subsets and vocals/backing pair are valid; duplicated sums are rejected', () {
    final r = result();
    expect(videoStemSubset(r, ['guitar']).single.id, 'guitar');
    expect(videoStemSubset(r, ['instrumental', 'vocals']).map((s) => s.id), [
      'vocals',
      'instrumental',
    ]);
    for (final ids in <List<String>>[
      [],
      ['unknown'],
      ['guitar', 'guitar'],
      ['instrumental', 'guitar'],
      ['instrumental', 'vocals', 'bass'],
    ]) {
      expect(() => videoStemSubset(r, ids), throwsFormatException);
    }
    final changed = separationFixture();
    (changed['stems'] as List).removeWhere((s) => (s as Map)['id'] == 'guitar');
    final other = (changed['stems'] as List).last as Map;
    other['id'] = 'custom_sum';
    other['download_url'] =
        '/api/v1/separation/jobs/contract_job_1/files/custom_sum';
    final custom = LegacySeparationResult.fromJson(changed, endpoint);
    expect(videoStemSubset(custom, ['custom_sum']).single.origin, 'derived');
    expect(
      () => videoStemSubset(custom, ['custom_sum', 'vocals']),
      throwsFormatException,
    );
  });
  test(
    'toggle switches between derived and model tracks without duplicate sums',
    () {
      final r = result();
      final pair = toggleVideoStem(
        r,
        r.mixStems.map((s) => s.id).toSet(),
        'instrumental',
      );
      expect(pair, {'vocals', 'instrumental'});
      expect(toggleVideoStem(r, pair, 'guitar'), {'vocals', 'guitar'});
      expect(toggleVideoStem(r, {'instrumental'}, 'vocals'), {
        'vocals',
        'instrumental',
      });
      expect(toggleVideoStem(r, {'guitar'}, 'guitar'), isEmpty);
      expect(() => toggleVideoStem(r, {}, 'unknown'), throwsFormatException);
    },
  );
  test('v3 persists explicit subset; v1/v2 controls do not accidentally become a subset', () {
    final selection = VideoMixSelection(
      taskId: 'task',
      inputSha256: 'a' * 64,
      useStems: true,
      controls: {
        'guitar': const StemMixControl(volume: .4),
        'drums': const StemMixControl(solo: true),
      },
      selectedTrackIds: ['guitar'],
    );
    final roundtrip = VideoMixSelection.fromJson(selection.toJson());
    expect(roundtrip.selectedTrackIds, {'guitar'});
    expect(roundtrip.gains, {'guitar': .4});
    expect(roundtrip.withMode(false).selectedTrackIds, {'guitar'});
    final old = selection.toJson()..['version'] = 2;
    expect(VideoMixSelection.fromJson(old).selectedTrackIds, isNull);
    expect(VideoMixSelection.fromJson(old).gains['guitar'], 0);
    for (final ids in [
      [],
      ['guitar', 'guitar'],
      ['unknown'],
      'guitar',
    ]) {
      final bad = selection.toJson()..['selectedTrackIds'] = ids;
      expect(() => VideoMixSelection.fromJson(bad), throwsFormatException);
    }
  });
  test(
    'inspection reads complete and resumable bytes without new requests',
    () async {
      final root = await Directory.systemTemp.createTemp('gp_inspect_');
      final r = result(), wav = syntheticAlgorithmWav();
      var requests = 0;
      final store = AlgorithmStemStore(
        () => Future.value(root),
        maxAttempts: 1,
        clientFactory: () => MockClient.streaming((request, _) async {
          requests++;
          return http.StreamedResponse(
            Stream.value(
              request.url.path.endsWith('drums') ? wav.sublist(0, 32768) : wav,
            ),
            200,
            contentLength: wav.length,
            headers: {'content-type': 'audio/wav', 'etag': '"v1"'},
          );
        }),
      );
      try {
        await store.download('task', r.stems[0]);
        await expectLater(
          store.download('task', r.stems[1]),
          throwsA(isA<AlgorithmApiError>()),
        );
        await File('${root.path}/task_bass.wav.part')
            .writeAsBytes(wav.sublist(0, 100));
        final states = await store.inspect('task', r.stems);
        expect(states['vocals']!.complete, isTrue);
        expect(states['drums']!.receivedBytes, 32768);
        expect(states['bass']!.receivedBytes, 0);
        expect(states['guitar']!.complete, isFalse);
        expect(requests, 2);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('temporarily unselected controls survive while hidden solo and sums stay inactive', () {
    final selection = VideoMixSelection(
      taskId: 'task',
      inputSha256: 'a' * 64,
      useStems: true,
      controls: {
        'guitar': const StemMixControl(volume: .4),
        'drums': const StemMixControl(muted: true, solo: true),
        'vocals': const StemMixControl(volume: .7),
        'instrumental': const StemMixControl(volume: .6),
      },
      selectedTrackIds: ['guitar'],
    );
    final backing = selection.forTracks(['vocals', 'instrumental']);
    expect(backing.gains, {'vocals': .7, 'instrumental': .6});
    final restored = VideoMixSelection.fromJson(backing.toJson())
        .forTracks(['guitar', 'drums']);
    expect(restored.controls['guitar']!.volume, .4);
    expect(restored.controls['drums']!.muted, isTrue);
    expect(restored.controls['drums']!.solo, isTrue);
    expect(restored.activeControls.keys, containsAll(['guitar', 'drums']));
    expect(restored.activeControls.containsKey('instrumental'), isFalse);
  });

  test('concurrent inspections adopt legacy cache without colliding receipt writes', () async {
    final root = await Directory.systemTemp.createTemp('gp_inspect_race_');
    try {
      final stem = result().stems.first;
      await File('${root.path}/task_${stem.id}.wav')
          .writeAsBytes(syntheticAlgorithmWav());
      final stores = List.generate(
        3,
        (_) => AlgorithmStemStore(
          () => Future.value(root),
          clientFactory: () => throw StateError('No HTTP'),
        ),
      );
      final reads = await Future.wait(
        stores.map((s) => s.inspect('task', [stem])),
      );
      expect(reads.every((r) => r[stem.id]!.complete), isTrue);
      expect(
        (await root.list().toList()).where((f) => f.path.endsWith('.tmp')),
        isEmpty,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  Future<void> showPicker(
    WidgetTester tester,
    _Store store,
    LegacySeparationResult r,
    void Function(VideoStemLoadChoice?) receive,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => receive(
                await showModalBottomSheet<VideoStemLoadChoice>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => VideoStemPicker(
                    taskId: 'task',
                    result: r,
                    store: store,
                    initialIds: r.mixStems.map((s) => s.id),
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'picker can download guitar alone and inspection is not repeated on toggles',
    (tester) async {
      final store = _Store({
        'vocals': const StemCacheStatus(complete: true, receivedBytes: 256044),
        'guitar': const StemCacheStatus(complete: false, receivedBytes: 32768),
      });
      VideoStemLoadChoice? choice;
      await showPicker(tester, store, result(), (v) => choice = v);
      expect(find.textContaining('可续传'), findsOneWidget);
      await tester.tap(find.text('只听吉他'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video_apply_stem_choice')));
      await tester.pumpAndSettle();
      expect(choice!.ids, {'guitar'});
      expect(choice!.localOnly, isFalse);
      expect(store.inspections, 1);
    },
  );
  testWidgets('expired server results can use only complete local selections', (
    tester,
  ) async {
    final store = _Store({
      'guitar': const StemCacheStatus(complete: true, receivedBytes: 256044),
    });
    VideoStemLoadChoice? choice;
    await showPicker(tester, store, result(expired: true), (v) => choice = v);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('video_apply_stem_choice')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('video_use_cached_stems')));
    await tester.pumpAndSettle();
    expect(choice!.ids, {'guitar'});
    expect(choice!.localOnly, isTrue);
  });
  testWidgets(
    'backing preset uses only the actual vocal and instrumental files',
    (tester) async {
      final store = _Store({});
      VideoStemLoadChoice? choice;
      await showPicker(tester, store, result(), (v) => choice = v);
      await tester.tap(find.text('人声与伴奏'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('video_pick_stem_guitar')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('video_apply_stem_choice')));
      await tester.pumpAndSettle();
      expect(choice!.ids, {'vocals', 'instrumental'});
    },
  );
  testWidgets('picker remains usable with large text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: VideoStemPicker(
              taskId: 'task',
              result: result(),
              store: _Store({}),
              initialIds: ['guitar'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('video_apply_stem_choice')), findsOneWidget);
  });
}

class _Store extends AlgorithmStemStore {
  _Store(this.states)
    : super(
        () => throw StateError('No disk access'),
        clientFactory: () => throw StateError('No network'),
      );
  final Map<String, StemCacheStatus> states;
  int inspections = 0;
  @override
  Future<Map<String, StemCacheStatus>> inspect(
    String taskId,
    List<LegacyStemFile> stems,
  ) async {
    inspections++;
    return {
      for (final s in stems)
        s.id:
            states[s.id] ??
            const StemCacheStatus(complete: false, receivedBytes: 0),
    };
  }
}

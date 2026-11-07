import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/performance/application/performance_preview.dart';
import 'package:guitar_pal/features/performance/data/backing_preset_store.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PerformanceCandidate candidate;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_performance_');
    candidate = fixtureCandidate(root);
  });
  tearDown(() {
    root.deleteSync(recursive: true);
  });
  test('backing presets use actual model tracks and never add derived instrumental on top', () {
    final c = candidate;
    expect(performanceBackingTracks(c.result, omitGuitar: true), {
      'vocals',
      'drums',
      'bass',
      'piano',
      'other',
    });
    expect(
      performanceBackingTracks(c.result, omitGuitar: true, omitVocals: true),
      {'drums', 'bass', 'piano', 'other'},
    );
    expect(c.wholeSong, isFalse);
    final missing = separationFixture();
    missing['stems'] = (missing['stems'] as List)
        .where((s) => (s as Map)['id'] != 'guitar')
        .toList();
    final result = LegacySeparationResult.fromJson(
      missing,
      AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
    );
    expect(
      () => performanceBackingTracks(result, omitGuitar: true),
      throwsFormatException,
    );
    expect(performanceBackingTracks(result).contains('instrumental'), isFalse);
  });
  test('round trip binds source revision manifest range and rejects derived duplication', () {
    final p = BackingPreset.forCandidate(
      candidate,
      performanceBackingTracks(candidate.result, omitGuitar: true),
    );
    final read = BackingPreset.fromJson(
      p.copyWith(speed: 1.37, master: .6).toJson(),
    );
    read.validateAgainst(candidate);
    expect(read.speed, 1.37);
    expect(read.startMs, 2000);
    expect(
      () => p
          .copyWith(
            controls: {
              'guitar': const StemMixControl(),
              'instrumental': const StemMixControl(),
            },
          )
          .validateAgainst(candidate),
      throwsFormatException,
    );
    expect(() => p.copyWith(speed: 1.375), throwsFormatException);
    expect(
      () =>
          BackingPreset.fromJson({...p.toJson(), 'manifestHash': 'b' * 64})
              .validateAgainst(candidate),
      throwsFormatException,
    );
    final wrong = fixtureCandidate(root, jobId: 'another_job');
    expect(p.matches(wrong), isFalse);
  });
  test('candidate refuses changed source metadata', () {
    final original = candidate;
    final file = File(original.binding.path)..writeAsBytesSync([1, 2]);
    final now = DateTime.now();
    final source = PracticeSource(
      id: 'source',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      title: 'song',
      canonicalUri: file.uri,
      createdAt: now,
      updatedAt: now,
    );
    expect(
      PerformanceCandidate.fromTask(source, file.statSync(), original.task),
      isNull,
    );
  });
  test('performance preferences are separate, serial, restart readable and cannot resurrect a deleted song', () async {
    final store = BackingPresetStore(() async => root);
    final old = File('${root.path}/video_workspace/source.json');
    await old.parent.create(recursive: true);
    await old.writeAsString('original mix');
    final p = BackingPreset.forCandidate(
      candidate,
      performanceBackingTracks(candidate.result, omitGuitar: true),
    );
    await Future.wait([store.save(p), store.save(p.copyWith(master: .3))]);
    final restored = await BackingPresetStore(() async => root).load('source');
    expect(restored!.master, .3);
    expect(restored.controls.containsKey('guitar'), isFalse);
    expect(await old.readAsString(), 'original mix');
    await store.delete('source');
    await expectLater(store.save(p), throwsStateError);
    expect(await store.load('source'), isNull);
    expect(
      root.listSync(recursive: true).where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });
  test('cached-only preparation downloads nothing, configures selected dynamic IDs and starts only on explicit play', () async {
    final platform = _Player(), store = _Store(root);
    final preview = PerformancePreview(platform, store, verify: (_) async {});
    try {
      final p = BackingPreset.forCandidate(
        candidate,
        performanceBackingTracks(candidate.result, omitGuitar: true),
      );
      await preview.prepare(candidate, p);
      expect(preview.ready, isTrue);
      expect(preview.playing, isFalse);
      expect(platform.plays, 0);
      expect(store.downloads, isEmpty);
      expect(platform.loaded.keys.toSet(), p.controls.keys.toSet());
      expect(platform.loaded.containsKey('guitar'), isFalse);
      await preview.toggle();
      expect(preview.playing, isTrue);
      await preview.configure(
        p.copyWith(
          controls: {
            for (final id in p.controls.keys)
              id: StemMixControl(volume: .4, solo: id == 'drums'),
          },
          speed: 1.37,
        ),
      );
      expect(preview.applied!.speed, 1.37);
      expect(platform.controls['drums']!.solo, isTrue);
      await preview.suspend();
      expect(preview.ready, isFalse);
      expect(platform.playing, isFalse);
      preview.resume();
      expect(platform.plays, 1);
    } finally {
      preview.dispose();
    }
  });
  test('missing selected files are the only requested tracks; cancellation retains cache and allows retry', () async {
    final player = _Player(), store = _Store(root)..cached = false;
    final preview = PerformancePreview(player, store, verify: (_) async {});
    try {
      final p = BackingPreset.forCandidate(candidate, {'drums', 'bass'});
      store.gate = Completer<void>();
      final prepare = preview.prepare(candidate, p);
      while (store.downloads.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      preview.pauseDownload();
      store.gate!.complete();
      await prepare;
      expect(preview.ready, isFalse);
      expect(preview.error, contains('暂停'));
      expect(player.loaded, isEmpty);
      expect(store.downloads.single, {'drums', 'bass'});
      store.gate = null;
      await preview.prepare(candidate, p);
      expect(preview.ready, isTrue);
    } finally {
      preview.dispose();
    }
  });
  test('late native load after background cannot start playback or mark preview ready', () async {
    final player = _Player()..loadGate = Completer<void>(),
        store = _Store(root);
    final preview = PerformancePreview(player, store, verify: (_) async {});
    final p = BackingPreset.forCandidate(candidate, {'drums'});
    final loading = preview.prepare(candidate, p);
    while (player.loaded.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await preview.suspend();
    player.loadGate!.complete();
    await loading;
    expect(preview.ready, isFalse);
    expect(player.plays, 0);
    expect(preview.applied, isNull);
    preview.dispose();
  });
  test(
    'expired results can use complete cache but never GET missing files',
    () async {
      final expired = fixtureCandidate(root, expires: '2020-01-01T00:00:00Z');
      final store = _Store(root), player = _Player();
      final preview = PerformancePreview(player, store, verify: (_) async {});
      try {
        final p = BackingPreset.forCandidate(expired, {'drums'});
        await preview.prepare(expired, p);
        expect(preview.ready, isTrue);
        store.cached = false;
        await preview.prepare(expired, p);
        expect(preview.ready, isFalse);
        expect(preview.error, contains('到期'));
        expect(store.downloads, isEmpty);
      } finally {
        preview.dispose();
      }
    },
  );
  test('real cache transfer GETs only selected files and a second preparation reuses verified files', () async {
    final requests = <String>[];
    final wav = syntheticAlgorithmWav();
    final store = AlgorithmStemStore(
      () async => root,
      clientFactory: () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response.bytes(
          wav,
          200,
          headers: {
            'content-length': '${wav.length}',
            'content-type': 'audio/wav',
            'etag': '"fixture"',
          },
        );
      }),
    );
    final player = _Player();
    final preview = PerformancePreview(player, store, verify: (_) async {});
    try {
      final p = BackingPreset.forCandidate(candidate, {'drums', 'bass'});
      await preview.prepare(candidate, p);
      expect(preview.ready, isTrue, reason: preview.error);
      expect(requests.toSet(), {
        'GET /api/v1/separation/jobs/contract_job_1/files/drums',
        'GET /api/v1/separation/jobs/contract_job_1/files/bass',
      });
      await preview.prepare(candidate, p);
      expect(preview.ready, isTrue);
      expect(requests.length, 2);
    } finally {
      preview.dispose();
    }
  });
  test(
    'dynamic native configuration applies solo to the loaded subset only',
    () async {
      Map<dynamic, dynamic>? args;
      const channel = MethodChannel('com.guitarpal/algorithm_mix');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            args = call.arguments as Map;
            return null;
          });
      try {
        await const AlgorithmMixPlatform().configureTracks(
          {
            'lead_guitar': const StemMixControl(
              volume: .6,
              solo: true,
              pan: -.4,
            ),
            'drums': const StemMixControl(volume: .7),
          },
          master: .8,
          speed: 1.21,
        );
        expect(args!['gains'], {'lead_guitar': .6, 'drums': 0});
        expect(args!['pans'], {'lead_guitar': -.4, 'drums': 0});
        expect(args!['loopStartMs'], isNull);
        expect(args!['master'], .8);
        expect(args!['speed'], 1.21);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );
  test('source invalidation blocks native playback even after a previous successful preparation', () async {
    var valid = true;
    final player = _Player(), store = _Store(root);
    final preview = PerformancePreview(
      player,
      store,
      verify: (_) async {
        if (!valid) throw const FormatException('来源变化');
      },
    );
    try {
      await preview.prepare(
        candidate,
        BackingPreset.forCandidate(candidate, {'drums'}),
      );
      valid = false;
      await preview.toggle();
      expect(player.plays, 0);
      expect(preview.error, contains('来源变化'));
    } finally {
      preview.dispose();
    }
  });
}

PerformanceCandidate fixtureCandidate(
  Directory root, {
  String jobId = 'contract_job_1',
  String expires = '2035-01-01T00:00:00Z',
}) {
  final file = File('${root.path}/video.mp4');
  if (!file.existsSync()) file.writeAsBytesSync([1]);
  final stat = file.statSync(), now = DateTime.now();
  final source = PracticeSource(
    id: 'source',
    platform: SourcePlatform.local,
    kind: SourceKind.video,
    title: 'song',
    canonicalUri: file.uri,
    createdAt: now,
    updatedAt: now,
  );
  final binding = VideoAnalysisBinding(
    sourceId: 'source',
    path: file.path,
    sourceBytes: stat.size,
    modifiedMs: stat.modified.millisecondsSinceEpoch,
    sourceDurationMs: 12000,
    startMs: 2000,
    durationMs: 8000,
    inputSha256: 'a' * 64,
    waveform: [],
  );
  final task = AlgorithmTaskRecord(
    id: 'task',
    endpoint: 'https://algorithm.example',
    inputPath: '/input',
    inputName: 'input.wav',
    inputSizeBytes: 256044,
    inputDurationMs: 8000,
    ownsInput: true,
    state: AlgorithmTaskState.completed,
    createdAt: now,
    updatedAt: now,
    failures: 0,
    operation: AlgorithmOperation.separation,
    remoteJobId: jobId,
    linkedSourceId: 'source',
    resultJson: jsonEncode(separationFixture(jobId: jobId, expires: expires)),
    mediaBindingJson: jsonEncode(binding.toJson()),
  );
  return PerformanceCandidate.fromTask(source, stat, task)!;
}

class _Store extends AlgorithmStemStore {
  _Store(this.folder) : super(() async => folder);
  final Directory folder;
  bool cached = true;
  Completer<void>? gate;
  final List<Set<String>> downloads = [];
  @override
  Future<File?> localFile(String taskId, LegacyStemFile stem) async =>
      cached ? File('${folder.path}/${stem.id}.wav') : null;
  @override
  Future<Map<String, String>> downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
  }) async {
    downloads.add(stems.map((s) => s.id).toSet());
    if (gate != null) await gate!.future;
    cancellation?.check();
    cached = true;
    return {for (final stem in stems) stem.id: '${folder.path}/${stem.id}.wav'};
  }
}

class _Player extends AlgorithmMixPlatform {
  Map<String, String> loaded = {};
  Map<String, StemMixControl> controls = {};
  bool playing = false;
  int position = 0, plays = 0;
  Completer<void>? loadGate;
  int generation = 0;
  @override
  Future<void> load(Map<String, String> paths) async {
    final token = generation;
    loaded = Map.of(paths);
    if (loadGate != null) await loadGate!.future;
    if (token != generation) return;
  }

  @override
  Future<void> configureTracks(
    Map<String, StemMixControl> c, {
    required double master,
    required double speed,
  }) async {
    controls = Map.of(c);
  }

  @override
  Future<void> stop() async {
    generation++;
    loaded = {};
    playing = false;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
  }

  @override
  Future<void> seek(int ms) async {
    position = ms;
  }

  @override
  Future<Map<String, Object?>> snapshot() async => {
    'isLoaded': loaded.isNotEmpty,
    'isPlaying': playing,
    'positionMs': position,
    'durationMs': 8000,
    'completedLoops': 0,
  };
}

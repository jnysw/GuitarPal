import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/video_mix_preferences.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_mix_selection.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_panel.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  testWidgets(
    'offline reopen restores gains without transport changes; original-mode choice survives another reopen',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      try {
        await f.show(tester);
        await _until(tester, () => f.controller.stemsLoaded);
        expect(f.networkRequests, 0);
        expect(f.bridge.paths, hasLength(6));
        expect(f.bridge.preserved, isTrue);
        expect(f.bridge.onlyPaused, isTrue);
        expect(f.bridge.gains['guitar'], .35);
        expect(f.bridge.gains['vocals'], 0);
        expect(f.controller.position.inMilliseconds, 4500);
        expect(f.controller.speed, 1.37);
        expect(f.controller.volume, .7);
        expect(f.controller.loopController.range!.start.inMilliseconds, 5000);
        expect(f.controller.isPlaying, isFalse);
        await tester.tap(find.text('和弦与分轨'));
        await _until(tester, () {
          final original = find.byKey(const Key('video_mix_original'));
          return original.evaluate().isNotEmpty &&
              tester.widget<TextButton>(original).onPressed != null;
        });
        var slider = tester.widget<Slider>(
          find.byKey(const Key('video_stem_volume_guitar')),
        );
        slider.onChanged!(.42);
        await tester.pump();
        slider = tester.widget<Slider>(
          find.byKey(const Key('video_stem_volume_guitar')),
        );
        slider.onChangeEnd!(.42);
        await _until(tester, () => f.bridge.gains['guitar'] == .42);
        final saved = (await _settle(tester, f.preferences.load('source')))!;
        expect(saved.controls['guitar']!.volume, .42);
        expect(saved.useStems, isTrue);
        tester
            .widget<TextButton>(find.byKey(const Key('video_mix_original')))
            .onPressed!();
        await _until(
          tester,
          () => find.text('已切回视频原声，分轨设置已保留').evaluate().isNotEmpty,
        );
        final original = (await _settle(tester, f.preferences.load('source')))!;
        expect(original.useStems, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        f.controller.dispose();
        f.newController();
        await f.show(tester);
        await _until(
          tester,
          () => find.text('上次选择：视频原声，分轨音量设置已保留').evaluate().isNotEmpty,
        );
        expect(f.bridge.loadCount, 0);
        expect(f.controller.stemsLoaded, isFalse);
        expect(f.networkRequests, 0);
      } finally {
        await f.close(tester);
      }
    },
  );

  for (final scenario in ['missing-cache', 'changed-video', 'playing']) {
    testWidgets(
      '$scenario retains original audio without automatic downloads or playback interruption',
      (tester) async {
        final f = (await tester.runAsync(_Fixture.create))!;
        try {
          await tester.runAsync(() async {
            if (scenario == 'missing-cache') {
              await File('${f.root.path}/task_guitar.wav').delete();
            }
            if (scenario == 'changed-video') {
              await f.video.writeAsBytes([1, 2, 3, 4]);
            }
          });
          if (scenario == 'playing') {
            await f.controller.play();
          }
          await f.show(tester);
          await _until(
            tester,
            () => find
                .textContaining(
                  scenario == 'missing-cache'
                      ? '本机文件不完整'
                      : scenario == 'changed-video'
                      ? '视频文件已变化'
                      : '视频已开始播放',
                )
                .evaluate()
                .isNotEmpty,
          );
          expect(f.bridge.loadCount, 0);
          expect(f.networkRequests, 0);
          expect(f.controller.isPlaying, scenario == 'playing');
        } finally {
          await f.close(tester);
        }
      },
    );
  }

  testWidgets(
    'a settings write failure keeps current audio usable and offers retry',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      final preferences = _FlakyPreferences(f.root);
      f.preferences = preferences;
      try {
        await f.show(tester);
        await _until(tester, () => f.controller.stemsLoaded);
        await tester.tap(find.text('和弦与分轨'));
        await _until(
          tester,
          () => find
              .byKey(const Key('video_mix_retry_save'))
              .evaluate()
              .isNotEmpty,
        );
        expect(f.controller.stemsLoaded, isTrue);
        preferences.broken = false;
        tester
            .widget<TextButton>(find.byKey(const Key('video_mix_retry_save')))
            .onPressed!();
        await _until(
          tester,
          () =>
              find.byKey(const Key('video_mix_retry_save')).evaluate().isEmpty,
        );
        expect(
          (await _settle(tester, preferences.load('source')))!.useStems,
          isTrue,
        );
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'recording cancels pending restore and ignores late cache lookups without forgetting the chosen mix',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      final gate = Completer<void>();
      var entered = false;
      f.store = _GatedStore(f.root, gate.future, () => entered = true);
      var recording = false;
      late StateSetter update;
      try {
        await f.show(
          tester,
          builder: (child) => StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return f.panel(recording: recording);
            },
          ),
        );
        await _until(tester, () => entered);
        update(() => recording = true);
        await tester.pump();
        gate.complete();
        await _until(
          tester,
          () => find.text('录音期间使用视频原声，分轨设置已保留').evaluate().isNotEmpty,
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(f.bridge.loadCount, 0);
        expect(f.controller.stemsLoaded, isFalse);
        expect(
          (await _settle(tester, f.preferences.load('source')))!.useStems,
          isTrue,
        );
      } finally {
        if (!gate.isCompleted) gate.complete();
        await f.close(tester);
      }
    },
  );
}

class _Fixture {
  _Fixture(this.root, this.database, this.video, this.source) {
    preferences = VideoMixPreferences(() async => root);
    store = AlgorithmStemStore(
      () async => root,
      clientFactory: () {
        networkRequests++;
        throw StateError('No network allowed during restore');
      },
    );
    newController();
  }
  final Directory root;
  final AppDatabase database;
  final File video;
  final domain.PracticeSource source;
  late VideoMixPreferences preferences;
  late AlgorithmStemStore store;
  late _Bridge bridge;
  late LocalVideoPlaybackController controller;
  int networkRequests = 0;
  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('gp_mix_restore_');
    final database = AppDatabase(NativeDatabase.memory());
    final video = File('${root.path}/video.mp4');
    await video.writeAsBytes([1, 2, 3]);
    final date = DateTime.utc(2026, 10, 30);
    final source = domain.PracticeSource(
      id: 'source',
      platform: domain.SourcePlatform.local,
      kind: domain.SourceKind.video,
      title: '同一视频',
      canonicalUri: video.uri,
      createdAt: date,
      updatedAt: date,
    );
    final f = _Fixture(root, database, video, source);
    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source',
            platform: 'local',
            kind: 'video',
            title: source.title,
            createdAt: date,
            updatedAt: date,
          ),
        );
    final stat = await video.stat();
    final binding = VideoAnalysisBinding(
      sourceId: 'source',
      path: video.path,
      sourceBytes: stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
      sourceDurationMs: 8000,
      startMs: 0,
      durationMs: 8000,
      inputSha256: 'a' * 64,
      waveform: [.2, .8],
    );
    final repository = AlgorithmTaskRepository(database);
    await repository.insert(
      AlgorithmTaskRecord(
        id: 'task',
        endpoint: 'https://algorithm.example',
        inputPath: '/input.wav',
        inputName: 'input.wav',
        inputSizeBytes: 256044,
        inputDurationMs: 8000,
        ownsInput: true,
        state: AlgorithmTaskState.completed,
        createdAt: date,
        updatedAt: date,
        failures: 0,
        operation: AlgorithmOperation.separation,
        linkedSourceId: 'source',
        mediaBindingJson: jsonEncode(binding.toJson()),
      ),
    );
    await repository.update(
      'task',
      AlgorithmTaskState.completed,
      resultJson: jsonEncode(separationFixture()),
    );
    final wav = syntheticAlgorithmWav();
    for (final id in videoStemIds) {
      await File('${root.path}/task_$id.wav').writeAsBytes(wav);
    }
    await f.preferences.save(
      'source',
      VideoMixSelection(
        taskId: 'task',
        inputSha256: 'a' * 64,
        useStems: true,
        controls: {
          'guitar': const StemMixControl(volume: .35, solo: true),
          'drums': const StemMixControl(muted: true),
        },
      ),
    );
    return f;
  }

  void newController() {
    bridge = _Bridge();
    controller = LocalVideoPlaybackController(bridge);
    bridge.emit();
    controller.loopController.setRange(
      LoopRange(
        start: const Duration(milliseconds: 5000),
        end: const Duration(milliseconds: 7000),
      ),
    );
  }

  Widget panel({bool recording = false}) => VideoAnalysisPanel(
    source: source,
    path: video.path,
    controller: controller,
    enabled: !recording,
    recordingActive: recording,
  );
  Future<void> show(WidgetTester tester, {Widget Function(Widget)? builder}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            videoMixPreferencesProvider.overrideWithValue(preferences),
            algorithmStemStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) => builder?.call(panel()) ?? panel(),
                ),
              ),
            ),
          ),
        ),
      );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    controller.dispose();
    await _settle(tester, preferences.load('source'));
    await _settle(tester, database.close());
    await tester.runAsync(() => root.delete(recursive: true));
  }
}

class _GatedStore extends AlgorithmStemStore {
  _GatedStore(Directory root, this.gate, this.entered)
    : super(() async => root);
  final Future<void> gate;
  final VoidCallback entered;
  @override
  Future<File?> localFile(String taskId, LegacyStemFile stem) async {
    entered();
    await gate;
    return super.localFile(taskId, stem);
  }
}

class _FlakyPreferences extends VideoMixPreferences {
  _FlakyPreferences(Directory root) : super(() async => root);
  bool broken = true;
  @override
  Future<void> save(String sourceId, VideoMixSelection value) async {
    if (broken) throw const FileSystemException('test write failure');
    await super.save(sourceId, value);
  }
}

class _Bridge implements LocalVideoPlayerBridge, LocalVideoStemBridge {
  LocalVideoStateListener? listener;
  bool loaded = false, playing = false, preserved = false, onlyPaused = false;
  int position = 4500, loadCount = 0;
  Map<String, String> paths = {};
  Map<String, double> gains = {};
  void emit() => listener?.call({
    'ready': true,
    'playing': playing,
    'positionMilliseconds': position,
    'durationMilliseconds': 8000,
    'speed': 1.37,
    'volume': .7,
    'stemsLoaded': loaded,
    'stemsActive': loaded,
  });
  @override
  Future<void> loadStems(
    Map<String, String> paths,
    int startMs,
    int durationMs, {
    bool preservePosition = false,
    bool onlyIfPaused = false,
    Map<String, double>? initialGains,
  }) async {
    if (onlyIfPaused && playing) {
      throw PlatformException(code: 'restore_skipped');
    }
    loadCount++;
    this.paths = paths;
    gains = initialGains ?? {};
    preserved = preservePosition;
    onlyPaused = onlyIfPaused;
    loaded = true;
    if (!preservePosition) position = startMs;
    emit();
  }

  @override
  Future<void> clearStems() async {
    loaded = false;
    emit();
  }

  @override
  Future<void> setStemGains(Map<String, double> value) async {
    gains = value;
  }

  @override
  void setStateListener(LocalVideoStateListener? listener) {
    this.listener = listener;
  }

  @override
  Future<void> play() async {
    playing = true;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value.inMilliseconds;
    emit();
  }

  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> requestSnapshot() async {
    emit();
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (ready()) return;
  }
  fail('Restore did not reach expected state');
}

Future<T> _settle<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  Object? error;
  future.then(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object e, StackTrace _) {
      error = e;
      done = true;
    },
  );
  await _until(tester, () => done);
  if (error != null) throw error!;
  return value;
}

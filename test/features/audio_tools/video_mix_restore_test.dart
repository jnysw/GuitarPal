import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    'choosing guitar downloads only that file from the existing task',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      final requests = <String>[];
      final downloading = _DownloadStore(f.root, requests);
      f.store = downloading;
      try {
        await tester.runAsync(() async {
          await File('${f.root.path}/video_workspace/source.json').delete();
          for (final id in videoStemIds) {
            await File('${f.root.path}/task_$id.wav').delete();
          }
        });
        await f.show(tester);
        await tester.tap(find.text('和弦与分轨'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('分轨').first);
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find
              .byKey(const Key('video_choose_stems_task'))
              .evaluate()
              .isNotEmpty,
        );
        tester
            .widget<TextButton>(
              find.byKey(const Key('video_choose_stems_task')),
            )
            .onPressed!();
        await _until(
          tester,
          () => find.text('只听吉他').hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text('只听吉他'));
        await _until(
          tester,
          () =>
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('video_apply_stem_choice')),
                  )
                  .onPressed !=
              null,
        );
        await tester.tap(find.byKey(const Key('video_apply_stem_choice')));
        await _until(
          tester,
          () =>
              downloading.error != null ||
              (f.controller.stemsLoaded &&
                  find.byType(BottomSheet).evaluate().isEmpty),
        );
        expect(downloading.error, isNull, reason: '${downloading.stack}');
        expect(requests, [
          'GET /api/v1/separation/jobs/contract_job_1/files/guitar',
        ]);
        expect(f.bridge.paths.keys, ['guitar']);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'guitar-only cache loads and reopens offline without missing unselected tracks',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      try {
        await tester.runAsync(() async {
          await File('${f.root.path}/video_workspace/source.json').delete();
          for (final id in videoStemIds.where((id) => id != 'guitar')) {
            await File('${f.root.path}/task_$id.wav').delete();
          }
        });
        await f.controller.play();
        await f.show(tester);
        await tester.tap(find.text('和弦与分轨'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('分轨').first);
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find
              .byKey(const Key('video_choose_stems_task'))
              .evaluate()
              .isNotEmpty,
        );
        tester
            .widget<TextButton>(
              find.byKey(const Key('video_choose_stems_task')),
            )
            .onPressed!();
        await _until(
          tester,
          () => find.byTooltip('关闭').hitTestable().evaluate().isNotEmpty,
        );
        expect(f.controller.isPlaying, isTrue);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(f.controller.isPlaying, isTrue);
        expect(f.bridge.loadCount, 0);
        tester
            .widget<TextButton>(
              find.byKey(const Key('video_choose_stems_task')),
            )
            .onPressed!();
        await _until(
          tester,
          () => find.text('只听吉他').hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text('只听吉他'));
        await _until(
          tester,
          () =>
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('video_apply_stem_choice')),
                  )
                  .onPressed !=
              null,
        );
        await tester.tap(find.byKey(const Key('video_apply_stem_choice')));
        await _until(
          tester,
          () =>
              f.controller.stemsLoaded &&
              find.byType(BottomSheet).evaluate().isEmpty,
        );
        expect(f.bridge.paths.keys, ['guitar']);
        expect(f.networkRequests, 0);
        expect(
          (await _settle(
            tester,
            f.preferences.load('source'),
          ))!.selectedTrackIds,
          {'guitar'},
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        f.controller.dispose();
        f.newController();
        await f.show(tester);
        await _until(tester, () => f.controller.stemsLoaded);
        expect(f.bridge.paths.keys, ['guitar']);
        expect(f.bridge.preserved, isTrue);
        expect(f.networkRequests, 0);
        await tester.tap(find.text('和弦与分轨'));
        await _until(
          tester,
          () =>
              find.byKey(const Key('video_open_mixer')).evaluate().isNotEmpty &&
              tester
                      .widget<FilledButton>(
                        find.byKey(const Key('video_open_mixer')),
                      )
                      .onPressed !=
                  null,
        );
        tester
            .widget<FilledButton>(find.byKey(const Key('video_open_mixer')))
            .onPressed!();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('video_mixer_choose_stems')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('video_mixer_choose_stems')));
        await _until(
          tester,
          () => find.text('全部分轨').hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text('全部分轨'));
        await _until(
          tester,
          () => find
              .byKey(const Key('video_use_cached_stems'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.tap(find.byKey(const Key('video_use_cached_stems')));
        await _until(
          tester,
          () =>
              find.byType(BottomSheet).evaluate().isEmpty &&
              f.controller.stemsLoaded,
        );
        expect(f.bridge.paths.keys, ['guitar']);
        expect(f.networkRequests, 0);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets(
    'same range reuses completed analysis without contacting server',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      try {
        await tester.runAsync(
          () => File('${f.root.path}/video_workspace/source.json').delete(),
        );
        await f.show(tester);
        await tester.tap(find.text('和弦与分轨'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('分轨').first);
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find.text('在当前视频中使用分轨').evaluate().isNotEmpty,
        );
        tester
            .widget<FilledButton>(
              find.byKey(const Key('video_analysis_submit')),
            )
            .onPressed!();
        await _until(
          tester,
          () => find.text('这个区间已经分过轨').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('使用已有结果'));
        await _until(tester, () => f.controller.stemsLoaded);
        expect(f.networkRequests, 0);
        expect(f.bridge.loadCount, 1);
      } finally {
        await f.close(tester);
      }
    },
  );

  testWidgets('pause download keeps result available for manual retry', (
    tester,
  ) async {
    final f = (await tester.runAsync(_Fixture.create))!;
    f.store = _PausedStore(f.root);
    try {
      await tester.runAsync(
        () => File('${f.root.path}/video_workspace/source.json').delete(),
      );
      await f.show(tester);
      await tester.tap(find.text('和弦与分轨'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('分轨').first);
      await tester.pumpAndSettle();
      await _until(tester, () => find.text('在当前视频中使用分轨').evaluate().isNotEmpty);
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '在当前视频中使用分轨'))
          .onPressed!();
      await _until(
        tester,
        () => find
            .byKey(const Key('video_pause_stem_download'))
            .evaluate()
            .isNotEmpty,
      );
      tester
          .widget<TextButton>(
            find.byKey(const Key('video_pause_stem_download')),
          )
          .onPressed!();
      await _until(
        tester,
        () => find.textContaining('下载已暂停').evaluate().isNotEmpty,
      );
      expect(f.controller.stemsLoaded, isFalse);
      final retry = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '在当前视频中使用分轨'),
      );
      expect(retry.onPressed, isNotNull);
      retry.onPressed!();
      await _until(tester, () => f.controller.stemsLoaded);
      expect(f.networkRequests, 0);
    } finally {
      await f.close(tester);
    }
  });

  testWidgets(
    'fresh in-place load tolerates native loaded event arriving before load acknowledgement',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      final receipt = Completer<void>();
      try {
        await tester.runAsync(
          () => File('${f.root.path}/video_workspace/source.json').delete(),
        );
        f.bridge.loadReceipt = receipt;
        await f.show(tester);
        await tester.tap(find.text('和弦与分轨'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('分轨').first);
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find.text('在当前视频中使用分轨').evaluate().isNotEmpty,
        );
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '在当前视频中使用分轨'))
            .onPressed!();
        await _until(tester, () => f.controller.stemsLoaded);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('video_open_mixer')), findsNothing);
        receipt.complete();
        await _until(
          tester,
          () => find.byKey(const Key('video_open_mixer')).evaluate().isNotEmpty,
        );
        expect(
          find.byKey(const Key('video_stem_volume_guitar')),
          findsOneWidget,
        );
      } finally {
        if (!receipt.isCompleted) receipt.complete();
        await f.close(tester);
      }
    },
  );
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
                      ? '本机分轨尚未完整'
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
            algorithmEndpointProvider.overrideWithValue(
              'https://algorithm.example',
            ),
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

class _DownloadStore extends AlgorithmStemStore {
  _DownloadStore(Directory root, List<String> requests)
    : super(
        () => Future.value(root),
        clientFactory: () => MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          return http.Response.bytes(
            syntheticAlgorithmWav(),
            200,
            headers: {'content-type': 'audio/wav'},
          );
        }),
      );
  Object? error;
  StackTrace? stack;
  @override
  Future<Map<String, String>> downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
  }) async {
    try {
      return await super.downloadBatch(
        taskId,
        stems,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    } catch (e, s) {
      error = e;
      stack = s;
      rethrow;
    }
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

class _PausedStore extends AlgorithmStemStore {
  _PausedStore(Directory root) : super(() async => root);
  bool first = true;
  @override
  Future<Map<String, String>> downloadBatch(
    String taskId,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
  }) async {
    if (!first) {
      return super.downloadBatch(
        taskId,
        stems,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    }
    first = false;
    onProgress?.call(const StemDownloadProgress(100, 1000, 0, 6, 10));
    await cancellation!.whenCancelled;
    throw const StemDownloadPaused();
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
  Completer<void>? loadReceipt;
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
    if (loadReceipt != null) await loadReceipt!.future;
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
  for (var i = 0; i < 500; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (ready()) return;
  }
  fail(
    'Restore did not reach expected state: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().join(' | ')}',
  );
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

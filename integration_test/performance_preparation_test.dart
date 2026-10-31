import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/video_mix_preferences.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_mix_selection.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/performance/data/backing_preset_store.dart';
import 'package:guitar_pal/features/performance/performance_prepare_screen.dart';
import 'package:guitar_pal/features/player/local_video_player_screen.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_panel.dart';

import '../test/support/algorithm_fixtures.dart';
import 'support/video_analysis_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'practice pauses before real native backing preview; saved guitar-free preset stays separate and return does not auto-play or add practice time',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final root = await const AlgorithmStemPlatform().directory();
      final video = File(
        '${root.parent.path}/guitarpal_videos/performance-source.mp4',
      );
      await video.parent.create(recursive: true);
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      final now = DateTime.now();
      final source = domain.PracticeSource(
        id: 'performance-source',
        platform: domain.SourcePlatform.local,
        kind: domain.SourceKind.video,
        title: '演奏伴奏验证',
        canonicalUri: video.uri,
        createdAt: now,
        updatedAt: now,
      );
      final store = AlgorithmStemStore(
        () async => root,
        clientFactory: () => throw StateError(
          'No network is allowed in this cached native test',
        ),
      );
      final prefs = BackingPresetStore(() async => root);
      await prefs.delete(source.id);
      // A fresh store simulates a new app lifetime after cleaning previous test artifacts.
      final activePrefs = BackingPresetStore(() async => root);
      final mixPrefs = VideoMixPreferences(() async => root);
      await mixPrefs.save(
        source.id,
        VideoMixSelection(
          taskId: 'performance-task',
          inputSha256: 'a' * 64,
          useStems: false,
          selectedTrackIds: ['guitar'],
          controls: {'guitar': const StemMixControl(volume: .23, pan: -.2)},
        ),
      );
      final oldMix = await File(
        '${root.path}/video_workspace/${source.id}.json',
      ).readAsString();
      final stat = await video.stat();
      final binding = VideoAnalysisBinding(
        sourceId: source.id,
        path: video.path,
        sourceBytes: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        sourceDurationMs: 8000,
        startMs: 0,
        durationMs: 8000,
        inputSha256: 'a' * 64,
        waveform: [],
      );
      await database
          .into(database.practiceSources)
          .insert(
            PracticeSourcesCompanion.insert(
              id: source.id,
              platform: 'local',
              kind: 'video',
              title: source.title,
              canonicalUrl: Value(video.uri.toString()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repository = AlgorithmTaskRepository(database);
      await repository.insert(
        AlgorithmTaskRecord(
          id: 'performance-task',
          endpoint: 'https://algorithm.example',
          inputPath: '/test-input',
          inputName: 'test.wav',
          inputSizeBytes: 256044,
          inputDurationMs: 8000,
          ownsInput: false,
          state: AlgorithmTaskState.completed,
          createdAt: now,
          updatedAt: now,
          failures: 0,
          operation: AlgorithmOperation.separation,
          linkedSourceId: source.id,
          mediaBindingJson: jsonEncode(binding.toJson()),
        ),
      );
      await repository.update(
        'performance-task',
        AlgorithmTaskState.completed,
        jobId: 'contract_job_1',
        resultJson: jsonEncode(separationFixture()),
      );
      for (final stem in [
        'vocals',
        'drums',
        'bass',
        'guitar',
        'piano',
        'other',
        'instrumental',
      ]) {
        await File('${root.path}/performance-task_$stem.wav')
            .writeAsBytes(syntheticAlgorithmWav());
      }
      final router = GoRouter(
        initialLocation: '/player',
        routes: [
          GoRoute(
            path: '/player',
            builder: (context, state) => LocalVideoPlayerScreen(source: source),
          ),
          GoRoute(
            path: '/performance/prepare',
            builder: (context, state) => PerformancePrepareRouteScreen(
              sourceId: state.uri.queryParameters['sourceId']!,
            ),
          ),
        ],
      );
      const player = AlgorithmMixPlatform();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              algorithmStemStoreProvider.overrideWithValue(store),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await _until(
          tester,
          () =>
              find
                  .byType(VideoAnalysisPanel, skipOffstage: false)
                  .evaluate()
                  .isNotEmpty &&
              tester
                  .widget<VideoAnalysisPanel>(
                    find.byType(VideoAnalysisPanel, skipOffstage: false),
                  )
                  .controller
                  .isReady,
        );
        final controller = tester
            .widget<VideoAnalysisPanel>(
              find.byType(VideoAnalysisPanel, skipOffstage: false),
            )
            .controller;
        await controller.play();
        await _until(tester, () => controller.isPlaying);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await tester.tap(find.byKey(const Key('local_video_performance')));
        await _until(
          tester,
          () =>
              find.byType(PerformancePrepareScreen).evaluate().isNotEmpty &&
              find
                  .byKey(const Key('performance_prepare'))
                  .evaluate()
                  .isNotEmpty,
        );
        expect(controller.isPlaying, isFalse);
        final heldPosition = controller.position.inMilliseconds;
        final before =
            (await database.select(database.practiceSessions).get()).single;
        expect(before.activeDurationMilliseconds, greaterThan(500));
        await tester.tap(find.byKey(const Key('performance_prepare')));
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_preview_play'))
              .evaluate()
              .isNotEmpty,
        );
        final snapshot = await player.snapshot();
        expect(snapshot['isLoaded'], isTrue);
        expect(snapshot['isPlaying'], isFalse);
        expect((snapshot['gains'] as Map).keys.toSet(), {
          'vocals',
          'drums',
          'bass',
          'piano',
          'other',
        });
        if (const bool.fromEnvironment('CAPTURE_PERFORMANCE_QA')) {
          await tester.pump(const Duration(milliseconds: 400));
          debugPrint('PERFORMANCE_QA_READY');
          await Future<void>.delayed(const Duration(seconds: 15));
        }
        await _tap(tester, find.byKey(const Key('performance_preview_play')));
        await _nativeUntil(
          tester,
          player,
          (s) => s['isPlaying'] == true && (s['positionMs'] as num) > 200,
        );
        expect(controller.isPlaying, isFalse);
        await _tap(tester, find.byKey(const Key('performance_save')));
        await _until(
          tester,
          () => find.text('伴奏方案已保存，下次可继续使用').evaluate().isNotEmpty,
        );
        final saved = await activePrefs.load(source.id);
        expect(saved, isNotNull);
        expect(saved!.controls.containsKey('guitar'), isFalse);
        expect(saved.controls.containsKey('instrumental'), isFalse);
        expect(saved.startMs, 0);
        expect(saved.durationMs, 8000);
        expect(
          await File('${root.path}/video_workspace/${source.id}.json')
              .readAsString(),
          oldMix,
        );
        expect(
          (await database.select(database.practiceSessions).get())
              .single
              .activeDurationMilliseconds,
          before.activeDurationMilliseconds,
        );
        await tester.binding.handlePopRoute();
        await _until(
          tester,
          () => find.byType(PerformancePrepareScreen).evaluate().isEmpty,
        );
        await _nativeUntil(tester, player, (s) => s['isLoaded'] == false);
        expect(controller.isPlaying, isFalse);
        expect(
          (controller.position.inMilliseconds - heldPosition).abs(),
          lessThan(250),
        );
        expect(
          tester
              .widget<VideoAnalysisPanel>(
                find.byType(VideoAnalysisPanel, skipOffstage: false),
              )
              .controller,
          same(controller),
        );
        expect(
          (await database.select(database.practiceSessions).get()).length,
          1,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } finally {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await player.stop();
        await activePrefs.delete(source.id);
        await mixPrefs.delete(source.id);
        await store.deleteTask('performance-task');
        await database.close();
        if (await video.exists()) await video.delete();
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(
    'UI did not settle: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
  );
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 250));
      if (target.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(target);
        return;
      }
    } else {
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  fail('Control not reachable: $target');
}

Future<void> _nativeUntil(
  WidgetTester tester,
  AlgorithmMixPlatform player,
  bool Function(Map<String, Object?>) done,
) async {
  for (var i = 0; i < 100; i++) {
    final s = await player.snapshot();
    if (done(s)) return;
    await tester.pump(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Native preview did not reach expected state');
}

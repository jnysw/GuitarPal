import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart'
    as segments;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/video_mix_preferences.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_mix_selection.dart';
import 'package:guitar_pal/features/player/local_video_player_screen.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_panel.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';

import '../test/support/algorithm_fixtures.dart';
import 'support/video_analysis_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline video reopens restore six-track controls, preserve segment intent and remember original audio',
    (tester) async {
      const sourceId = 'integration-video-mix-source',
          taskId = 'integration-video-mix-task';
      final database = AppDatabase(NativeDatabase.memory());
      final root = await const AlgorithmStemPlatform().directory();
      final folder = Directory('${root.parent.path}/guitarpal_videos');
      await folder.create(recursive: true);
      final video = File('${folder.path}/integration-mix-restore.mp4');
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      final preferences = VideoMixPreferences(() async => root);
      var network = 0;
      final store = AlgorithmStemStore(
        () async => root,
        clientFactory: () {
          network++;
          throw StateError('Offline restore may not request HTTP');
        },
      );
      final now = DateTime.now();
      final source = domain.PracticeSource(
        id: sourceId,
        platform: domain.SourcePlatform.local,
        kind: domain.SourceKind.video,
        title: '离线分轨恢复测试',
        canonicalUri: video.uri,
        createdAt: now,
        updatedAt: now,
      );
      final segment = segments.PracticeSegment(
        id: 'restore-segment',
        sourceId: sourceId,
        title: '片段入口',
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
        preferredSpeed: 1.21,
        createdAt: now,
        updatedAt: now,
      );
      final repository = AlgorithmTaskRepository(database);
      final files = <File>[];
      try {
        await database
            .into(database.practiceSources)
            .insert(
              PracticeSourcesCompanion.insert(
                id: sourceId,
                platform: 'local',
                kind: 'video',
                title: source.title,
                createdAt: now,
                updatedAt: now,
              ),
            );
        final stat = await video.stat();
        final binding = VideoAnalysisBinding(
          sourceId: sourceId,
          path: video.path,
          sourceBytes: stat.size,
          modifiedMs: stat.modified.millisecondsSinceEpoch,
          sourceDurationMs: 8000,
          startMs: 0,
          durationMs: 8000,
          inputSha256: 'a' * 64,
          waveform: [.2, .8],
        );
        await repository.insert(
          AlgorithmTaskRecord(
            id: taskId,
            endpoint: 'https://algorithm.example',
            inputPath: '/test-input.wav',
            inputName: 'test.wav',
            inputSizeBytes: 256044,
            inputDurationMs: 8000,
            ownsInput: false,
            state: AlgorithmTaskState.completed,
            createdAt: now,
            updatedAt: now,
            failures: 0,
            operation: AlgorithmOperation.separation,
            linkedSourceId: sourceId,
            mediaBindingJson: jsonEncode(binding.toJson()),
          ),
        );
        final wav = syntheticAlgorithmWav();
        final fixture = separationFixture(jobId: taskId)
          ..['diagnostics'] = {
            'queue_ms': 2000,
            'inference_ms': 1500,
            'worker_total_ms': 1800,
            'device': 'cuda:0',
          };
        for (final stem in fixture['stems'] as List) {
          (stem as Map)['sha256'] = sha256.convert(wav).toString();
        }
        await repository.update(
          taskId,
          AlgorithmTaskState.completed,
          resultJson: jsonEncode(fixture),
        );
        for (final id in [...videoStemIds, 'instrumental']) {
          final file = File('${root.path}/${taskId}_$id.wav');
          await file.writeAsBytes(wav);
          files.add(file);
        }
        await preferences.save(
          sourceId,
          VideoMixSelection(
            taskId: taskId,
            inputSha256: 'a' * 64,
            useStems: true,
            controls: {'guitar': const StemMixControl(volume: .25, solo: true)},
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              videoMixPreferencesProvider.overrideWithValue(preferences),
              algorithmStemStoreProvider.overrideWithValue(store),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LocalVideoPlayerScreen(
                          source: source,
                          initialSegment: segment,
                        ),
                      ),
                    ),
                    child: const Text('打开测试练习'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<LocalVideoPlaybackController> open({required bool stems}) async {
          await tester.tap(find.text('打开测试练习'));
          await _until(
            tester,
            () => find
                .byKey(const Key('practice_section_1'))
                .evaluate()
                .isNotEmpty,
          );
          await tester.tap(find.byKey(const Key('practice_section_1')));
          await tester.pump(const Duration(milliseconds: 350));
          await _until(tester, () {
            final panel = find.byType(VideoAnalysisPanel);
            if (panel.evaluate().isEmpty) return false;
            final controller = tester
                .widget<VideoAnalysisPanel>(panel)
                .controller;
            return controller.isReady &&
                controller.stemsLoaded == stems &&
                (stems ||
                    find.textContaining('上次选择：视频原声').evaluate().isNotEmpty);
          });
          final controller = tester
              .widget<VideoAnalysisPanel>(find.byType(VideoAnalysisPanel))
              .controller;
          await _until(
            tester,
            () =>
                (controller.speed - 1.21).abs() < .001 &&
                controller.position.inMilliseconds >= 1900,
          );
          expect(controller.loopController.range!.start.inMilliseconds, 2000);
          expect(controller.loopController.range!.end.inMilliseconds, 4000);
          expect(controller.isPlaying, isFalse);
          expect(controller.position.inMilliseconds, lessThan(2300));
          return controller;
        }

        Future<void> leave() async {
          await tester.pageBack();
          await _until(
            tester,
            () => find.byType(LocalVideoPlayerScreen).evaluate().isEmpty,
          );
          await tester.pumpAndSettle();
        }

        var controller = await open(stems: true);
        await _tap(tester, find.text('和弦与分轨'));
        await _until(
          tester,
          () => find
              .byKey(const Key('video_stem_volume_guitar'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          tester
              .widget<Slider>(find.byKey(const Key('video_stem_volume_guitar')))
              .value,
          .25,
        );
        tester
            .widget<Slider>(find.byKey(const Key('video_stem_pan_guitar')))
            .onChanged!(-.4);
        await _until(
          tester,
          () =>
              tester
                  .widget<Slider>(
                    find.byKey(const Key('video_stem_pan_guitar')),
                  )
                  .value ==
              -.4,
        );
        expect(
          (await preferences.load(sourceId))!.controls['guitar']!.pan,
          -.4,
        );
        await _tap(tester, find.text('服务器处理详情'));
        await _until(
          tester,
          () => find.text('处理方式：GPU 加速').evaluate().isNotEmpty,
        );
        expect(find.text('2.00 秒'), findsOneWidget);
        expect(find.text('1.50 秒'), findsOneWidget);
        expect(network, 0);
        if (const bool.fromEnvironment('CAPTURE_MIXER_QA')) {
          await _tap(tester, find.byKey(const Key('video_open_mixer')));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('播放混音台'), findsWidgets);
          debugPrint('MIXER_QA_READY');
          await Future<void>.delayed(const Duration(seconds: 20));
          Navigator.of(tester.element(find.byType(BottomSheet))).pop();
          await tester.pump(const Duration(milliseconds: 500));
        }
        await _tap(tester, find.byKey(const Key('video_stem_mute_guitar')));
        await _until(
          tester,
          () => tester
              .widget<FilterChip>(
                find.byKey(const Key('video_stem_mute_guitar')),
              )
              .selected,
        );
        expect(
          (await preferences.load(sourceId))!.controls['guitar']!.muted,
          isTrue,
        );
        await leave();
        controller = await open(stems: true);
        await _tap(tester, find.text('和弦与分轨'));
        await _until(
          tester,
          () => find
              .byKey(const Key('video_stem_mute_guitar'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const Key('video_stem_mute_guitar')),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<Slider>(find.byKey(const Key('video_stem_pan_guitar')))
              .value,
          -.4,
        );
        await _tap(tester, find.byKey(const Key('video_mix_original')));
        await _until(tester, () => !controller.stemsLoaded);
        expect((await preferences.load(sourceId))!.useStems, isFalse);
        await leave();
        controller = await open(stems: false);
        await _tap(tester, find.text('和弦与分轨'));
        await _tap(tester, find.byKey(const Key('video_mix_restore')));
        await _until(
          tester,
          () =>
              controller.stemsLoaded &&
              find.text('正在准备当前视频的音轨…').evaluate().isEmpty,
        );
        await _tap(tester, find.byKey(const Key('video_stem_mute_guitar')));
        await controller.play();
        await _until(tester, () => controller.isPlaying);
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        await controller.pause();
        await leave();
        final sessions = await database.select(database.practiceSessions).get();
        expect(sessions, hasLength(1));
        expect(
          sessions.single.activeDurationMilliseconds,
          inInclusiveRange(1000, 2800),
        );
        expect(network, 0);
        controller = await open(stems: true);
        await _tap(tester, find.text('和弦与分轨'));
        await _tap(tester, find.byKey(const Key('video_open_mixer')));
        await _tap(tester, find.byKey(const Key('video_mixer_choose_stems')));
        await _until(tester, () => find.text('选择练习音轨').evaluate().isNotEmpty);
        if (const bool.fromEnvironment('CAPTURE_STEM_PICKER_QA')) {
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
          debugPrint('SELECT_STEM_QA_READY');
          await Future<void>.delayed(const Duration(seconds: 20));
        }
        await _tap(tester, find.text('只听吉他'));
        await _tap(tester, find.byKey(const Key('video_apply_stem_choice')));
        await _until(
          tester,
          () =>
              find.byType(BottomSheet).evaluate().isEmpty &&
              find
                  .byKey(const Key('video_stem_volume_guitar'))
                  .evaluate()
                  .isNotEmpty &&
              find
                  .byKey(const Key('video_stem_volume_drums'))
                  .evaluate()
                  .isEmpty,
        );
        expect((await preferences.load(sourceId))!.selectedTrackIds, {
          'guitar',
        });
        expect(controller.speed, closeTo(1.21, .001));
        expect(controller.loopController.range!.start.inMilliseconds, 2000);
        for (final id in ['drums', 'bass', 'piano', 'other']) {
          await File('${root.path}/${taskId}_$id.wav').delete();
        }
        await leave();
        controller = await open(stems: true);
        await _tap(tester, find.text('和弦与分轨'));
        await _until(
          tester,
          () => find
              .byKey(const Key('video_stem_volume_guitar'))
              .evaluate()
              .isNotEmpty,
        );
        expect(find.byKey(const Key('video_stem_volume_drums')), findsNothing);
        expect(network, 0);
        await _tap(tester, find.byKey(const Key('video_choose_stems_$taskId')));
        await _tap(tester, find.text('人声与伴奏'));
        await _tap(tester, find.byKey(const Key('video_apply_stem_choice')));
        await _until(
          tester,
          () =>
              find.byType(BottomSheet).evaluate().isEmpty &&
              find
                  .byKey(const Key('video_stem_volume_instrumental'))
                  .evaluate()
                  .isNotEmpty,
        );
        expect((await preferences.load(sourceId))!.selectedTrackIds, {
          'vocals',
          'instrumental',
        });
        expect(find.byKey(const Key('video_stem_volume_guitar')), findsNothing);
        expect(controller.loopController.range!.end.inMilliseconds, 4000);
        expect(network, 0);
        await leave();
        expect(
          await database.select(database.practiceSessions).get(),
          hasLength(1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await preferences.delete(sourceId);
        await database.close();
        for (final file in files) {
          if (await file.exists()) await file.delete();
        }
        await store.deleteTask(taskId);
        await video.delete();
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 180; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (done()) return;
  }
  fail('Video mix recovery did not reach expected state');
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _until(tester, () => target.evaluate().isNotEmpty);
  for (var i = 0; i < 5; i++) {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 300));
    if (target.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(target);
      return;
    }
  }
  fail('Control was not visible: $target');
}

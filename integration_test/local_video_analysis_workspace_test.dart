import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/application/algorithm_task_service.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/player/local_video_player_screen.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_panel.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_editor_sheet.dart';

import 'support/video_analysis_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'video toolbar runs extraction, automatic task binding and in-place chord calibration without extra routes',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final root = (await const AlgorithmStemPlatform().directory()).parent;
      final folder = Directory('${root.path}/guitarpal_videos');
      await folder.create(recursive: true);
      final video = File('${folder.path}/workspace-test.mp4');
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      final now = DateTime.now();
      final source = domain.PracticeSource(
        id: 'workspace-source',
        platform: domain.SourcePlatform.local,
        kind: domain.SourceKind.video,
        title: '本地视频 · 页内分析验证',
        canonicalUri: video.uri,
        createdAt: now,
        updatedAt: now,
      );
      await database
          .into(database.practiceSources)
          .insert(
            PracticeSourcesCompanion.insert(
              id: source.id,
              platform: 'local',
              kind: 'video',
              title: source.title,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repository = AlgorithmTaskRepository(database);
      final api = _WorkspaceApi();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              algorithmEndpointProvider.overrideWithValue(
                'https://algorithm.example',
              ),
              algorithmTaskServiceProvider.overrideWithValue(
                AlgorithmTaskService(
                  repository,
                  allowLocalHttp: false,
                  apiFactory: (_) => api,
                ),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LocalVideoPlayerScreen(source: source),
                      ),
                    ),
                    child: const Text('打开视频'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开视频'));
        await _spin(
          tester,
          () =>
              find.byType(VideoAnalysisPanel).evaluate().isNotEmpty &&
              tester
                  .widget<VideoAnalysisPanel>(find.byType(VideoAnalysisPanel))
                  .controller
                  .isReady &&
              tester
                  .widget<PopupMenuButton<AlgorithmOperation>>(
                    find.byKey(const Key('local_video_analysis_menu')),
                  )
                  .enabled,
        );
        await tester.tap(find.byKey(const Key('local_video_analysis_menu')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('扒和弦'));
        await tester.pump(const Duration(milliseconds: 500));
        await _tapVisible(
          tester,
          find.byKey(const Key('video_analysis_submit')),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.byKey(const Key('video_analysis_confirm')));
        await _spin(tester, () => find.text('与视频时间校准').evaluate().isNotEmpty);
        expect(api.uploads, 1);
        expect(api.audioBytes, greaterThan(100000));
        final task =
            (await database.select(database.algorithmTasks).get()).single;
        expect(task.linkedSourceId, source.id);
        expect(jsonDecode(task.mediaBindingJson!)['startMs'], 0);
        expect(find.text('关联曲目／计划'), findsNothing);
        expect(find.text('当前和弦 C'), findsOneWidget);
        expect(find.textContaining('静音偏移待校准'), findsOneWidget);
        await _tapVisible(tester, find.text('与视频时间校准'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.enterText(find.byType(TextFormField), '0');
        await tester.tap(find.text('确认'));
        await _spin(tester, () => find.text('调整人工校准').evaluate().isNotEmpty);
        await _tapVisible(
          tester,
          find.byKey(const Key('video_analysis_chord_3250')),
        );
        final controller = tester
            .widget<VideoAnalysisPanel>(find.byType(VideoAnalysisPanel))
            .controller;
        await _spin(tester, () => controller.position.inMilliseconds >= 3000);
        await _spin(tester, () => find.text('当前和弦 Am').evaluate().isNotEmpty);
        expect(find.byType(LocalVideoPlayerScreen), findsOneWidget);
        expect(controller.hasVideoFrame, isTrue);
        await _tapVisible(
          tester,
          find.byKey(const Key('video_analysis_selection_loop')),
        );
        await _spin(
          tester,
          () =>
              controller.loopController.enabled &&
              controller.loopController.range?.start.inMilliseconds == 3250,
        );
        expect(controller.loopController.range!.end.inMilliseconds, 8000);
        if (const bool.fromEnvironment('CAPTURE_TIMELINE_QA')) {
          await tester.ensureVisible(
            find.byKey(const Key('video_analysis_waveform')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          debugPrint('TIMELINE_QA_READY');
          await Future<void>.delayed(const Duration(seconds: 30));
        }
        await _tapVisible(
          tester,
          find.byKey(const Key('video_analysis_save_loop')),
        );
        await _spin(
          tester,
          () =>
              find.byKey(PracticeSegmentEditorKeys.title).evaluate().isNotEmpty,
        );
        await tester.enterText(
          find.byKey(PracticeSegmentEditorKeys.title),
          '和弦选区练习',
        );
        await _tapVisible(tester, find.byKey(PracticeSegmentEditorKeys.save));
        await _spin(tester, () => find.text('片段已保存并应用').evaluate().isNotEmpty);
        final segments = await database.select(database.practiceSegments).get();
        expect(segments.single.sourceId, source.id);
        expect(segments.single.startMilliseconds, 3250);
        expect(segments.single.endMilliseconds, 8000);
        expect(segments.single.title, '和弦选区练习');
        await tester.tap(find.byKey(const Key('local_video_fullscreen')));
        final fullscreen = find.byKey(
          const Key('local_video_fullscreen_position_slider'),
        );
        await _spin(tester, () => fullscreen.evaluate().isNotEmpty);
        expect(find.text('当前和弦 Am'), findsOneWidget);
        expect(
          tester
              .widget<VideoAnalysisPanel>(
                find.byType(VideoAnalysisPanel, skipOffstage: false),
              )
              .controller,
          same(controller),
        );
        await tester.binding.handlePopRoute();
        await _spin(tester, () => fullscreen.evaluate().isEmpty);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('调整人工校准'), findsOneWidget);
        await controller.play();
        await _spin(tester, () => controller.isPlaying);
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        await controller.pause();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pageBack();
        await _spin(
          tester,
          () => find.byType(LocalVideoPlayerScreen).evaluate().isEmpty,
        );
        await tester.pumpAndSettle();
        final sessions = await database
            .select(database.practiceSessions)
            .watch()
            .firstWhere((rows) => rows.isNotEmpty)
            .timeout(const Duration(seconds: 5));
        expect(sessions, hasLength(1));
        expect(
          sessions.single.activeDurationMilliseconds,
          inInclusiveRange(1000, 2500),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final task
            in await database.select(database.algorithmTasks).get()) {
          await const MethodChannelAlgorithmAudioImport().deleteInput(
            task.inputPath,
          );
        }
        await database.close();
        await video.delete();
      }
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 5; i++) {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 300));
    if (target.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(target);
      return;
    }
  }
  fail('Expected an unobscured control: $target');
}

Future<void> _spin(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (done()) return;
  }
  fail('Video workspace did not reach expected state');
}

class _WorkspaceApi implements AlgorithmApi {
  int uploads = 0, audioBytes = 0;
  @override
  Future<void> ping({
    AlgorithmOperation operation = AlgorithmOperation.chords,
  }) async {}
  @override
  void close() {}
  @override
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int, int)? onProgress,
  }) async {
    final bytes = await File(path).readAsBytes();
    audioBytes = bytes.length;
    uploads++;
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(ByteData.sublistView(bytes).getUint32(24, Endian.little), 16000);
    return LegacyUploadReceipt.fromJson(
      {
        'job_id': 'workspace-job',
        'status': 'queued',
        'poll_url': '/api/v1/jobs/workspace-job/status',
        'result_url': '/api/v1/jobs/workspace-job/result',
      },
      AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      operation,
    );
  }

  @override
  Future<LegacyAlgorithmStatus> status(
    String id,
    AlgorithmOperation operation,
  ) async => LegacyAlgorithmStatus.fromJson({
    'job_id': id,
    'status': 'completed',
    'progress': 100,
    'message': 'completed',
  }, operation);
  @override
  Future<Map<String, Object?>> result(
    String id,
    AlgorithmOperation operation,
  ) async => {
    'job_id': id,
    'status': 'completed',
    'duration_seconds': 8.0,
    'key': 'C major',
    'progression': 'C–Am',
    'segments': [
      {'chord': 'C', 'roman': 'I', 'start': 0.0, 'end': 3.25},
      {'chord': 'Am', 'roman': 'vi', 'start': 3.25, 'end': 8.0},
    ],
  };
}

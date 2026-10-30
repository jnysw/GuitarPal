import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/application/algorithm_task_service.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/data/video_audio_extractor.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_panel.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

void main() {
  testWidgets(
    'current video uses the configured origin without address input and calibrates chords in place',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('gp_video_panel_');
      final video = File('${directory.path}/video.mp4')
        ..writeAsBytesSync([1, 2, 3]);
      final database = AppDatabase(NativeDatabase.memory());
      final repository = AlgorithmTaskRepository(database);
      final now = DateTime.now();
      final bridge = _Bridge();
      final controller = LocalVideoPlaybackController(bridge);
      await controller.requestSnapshot();
      await tester.runAsync(
        () => database
            .into(database.practiceSources)
            .insert(
              PracticeSourcesCompanion.insert(
                id: 'source',
                platform: 'local',
                kind: 'video',
                title: '同一视频',
                createdAt: now,
                updatedAt: now,
              ),
            ),
      );
      final api = _Api();
      final extractor = _Extractor();
      final source = domain.PracticeSource(
        id: 'source',
        platform: domain.SourcePlatform.local,
        kind: domain.SourceKind.video,
        title: '同一视频',
        canonicalUri: video.uri,
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            algorithmEndpointProvider.overrideWithValue(
              'http://100.80.90.10:8000',
            ),
            videoAudioExtractorProvider.overrideWithValue(extractor),
            algorithmTaskServiceProvider.overrideWithValue(
              AlgorithmTaskService(
                repository,
                allowLocalHttp: true,
                apiFactory: (_) => api,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) => VideoAnalysisPanel(
                    source: source,
                    path: video.path,
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('和弦与分轨'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('video_analysis_endpoint')), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await controller.activateLoopRange(
        LoopRange(start: Duration.zero, end: const Duration(seconds: 4)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      controller.clearLoop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video_analysis_submit')));
      await tester.pumpAndSettle();
      expect(find.text('请先设置 A-B 区间，再开始分析'), findsOneWidget);
      expect(find.byKey(const Key('video_analysis_confirm')), findsNothing);
      expect(extractor.calls, 0);
      await tester.tap(
        find.byType(SwitchListTile),
      ); // A cleared A-B must still allow returning to whole-video mode.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video_analysis_submit')));
      await tester.pumpAndSettle();
      expect(api.uploads, 0);
      expect(find.textContaining('仅提取并上传此区间的音频'), findsOneWidget);
      await tester.tap(find.byKey(const Key('video_analysis_confirm')));
      await _until(tester, () {
        final retry = find.byKey(const Key('video_analysis_retry_connection'));
        return retry.evaluate().isNotEmpty &&
            tester.widget<TextButton>(retry).onPressed != null;
      });
      expect(extractor.calls, 0);
      expect(api.uploads, 0);
      expect(
        (await tester.runAsync(
          () => database.select(database.algorithmTasks).get(),
        ))!,
        isEmpty,
      );
      api.failPing = false;
      await tester.tap(
        find.byKey(const Key('video_analysis_retry_connection')),
      );
      await _until(tester, () => find.text('分析服务已连接').evaluate().isNotEmpty);
      await tester.tap(find.byKey(const Key('video_analysis_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('video_analysis_confirm')));
      await _until(tester, () => find.text('与视频时间校准').evaluate().isNotEmpty);
      expect(extractor.calls, 1);
      expect(api.uploads, 1);
      final task = (await tester.runAsync(
        () => database
            .select(database.algorithmTasks)
            .get()
            .timeout(const Duration(seconds: 5)),
      ))!.single;
      expect(task.linkedSourceId, 'source');
      expect(task.endpoint, 'http://100.80.90.10:8000');
      expect(jsonDecode(task.mediaBindingJson!)['path'], video.path);
      expect(find.text('关联曲目／计划'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('与视频时间校准'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('与视频时间校准'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('确认'));
      await _until(tester, () => find.text('调整人工校准').evaluate().isNotEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('video_analysis_chord_3250')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('video_analysis_chord_3250')));
      await _until(
        tester,
        () => bridge.lastSeek == const Duration(milliseconds: 3250),
      );
      expect(bridge.lastSeek, const Duration(milliseconds: 3250));
      expect(find.textContaining('人工校准'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
      await tester.runAsync(
        () => database.close().timeout(const Duration(seconds: 5)),
      );
      directory.deleteSync(recursive: true);
    },
  );
}

class _Extractor extends VideoAudioExtractor {
  int calls = 0;
  @override
  Future<ExtractedVideoAudio> extract(
    String path,
    int startMs,
    int endMs, {
    int? sourceDurationMs,
  }) async {
    expect(sourceDurationMs, 8000);
    calls++;
    return ExtractedVideoAudio(
      const AlgorithmAudioInput(
        path: '/private/extracted.wav',
        name: 'video-audio.wav',
        sizeBytes: 100,
        duration: Duration(seconds: 8),
      ),
      'a' * 64,
      [0, .5, 1],
    );
  }
}

class _Api implements AlgorithmApi {
  int uploads = 0;
  bool failPing = true;
  @override
  Future<void> ping() async {
    if (failPing) {
      throw const AlgorithmApiError('network_error', '暂时无法连接分析服务，请稍后重试');
    }
  }

  @override
  void close() {}
  @override
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int, int)? onProgress,
  }) async {
    uploads++;
    expect(path, '/private/extracted.wav');
    return LegacyUploadReceipt.fromJson(
      {
        'job_id': 'contract_job_1',
        'status': 'queued',
        'poll_url': '/api/v1/jobs/contract_job_1/status',
        'result_url': '/api/v1/jobs/contract_job_1/result',
      },
      AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      operation,
    );
  }

  @override
  Future<LegacyAlgorithmStatus> status(
    String jobId,
    AlgorithmOperation operation,
  ) async => LegacyAlgorithmStatus.fromJson({
    'job_id': jobId,
    'status': 'completed',
    'progress': 100,
    'message': 'completed',
  }, operation);
  @override
  Future<Map<String, Object?>> result(
    String jobId,
    AlgorithmOperation operation,
  ) async => jsonDecode(
    File('contracts/legacy_algorithm/fixtures/chords_result.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
}

class _Bridge implements LocalVideoPlayerBridge {
  LocalVideoStateListener? listener;
  Duration? lastSeek;
  void emit() => listener?.call({
    'ready': true,
    'playing': false,
    'positionMilliseconds': lastSeek?.inMilliseconds ?? 0,
    'durationMilliseconds': 8000,
  });
  @override
  void setStateListener(LocalVideoStateListener? listener) {
    this.listener = listener;
  }

  @override
  Future<void> play() async {
    emit();
  }

  @override
  Future<void> pause() async {
    emit();
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
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

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (condition()) return;
  }
  fail('Video analysis UI did not reach the expected state');
}

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_service_configuration.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/data/video_audio_extractor.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_configuration.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

import 'support/video_analysis_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'ordinary Android builds resolve the deployment origin without API Dart defines',
    (tester) async {
      final origin = await const AlgorithmServiceConfiguration().load();
      expect(AlgorithmConfiguration.baseUrl, isEmpty);
      expect(
        origin,
        isNotEmpty,
        reason: 'Local deployment configuration must be present for this live health check',
      );
      final api = LegacyAlgorithmApi(
        AlgorithmEndpoint(origin, allowLocalHttp: true),
      );
      try {
        await api.ping();
      } finally {
        api.close();
      }
    },
    skip: !const bool.fromEnvironment('CHECK_ALGORITHM_HEALTH'),
  );
  testWidgets(
    'playback clock end differing by 1ms is preserved; real range violations remain rejected',
    (tester) async {
      final root = (await const AlgorithmStemPlatform().directory()).parent;
      final folder = Directory('${root.path}/guitarpal_videos');
      await folder.create(recursive: true);
      final video = File('${folder.path}/range-boundary-test.mp4');
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      final paths = <String>[];
      const extractor = VideoAudioExtractor();
      try {
        final audio = await extractor.extract(
          video.path,
          0,
          8001,
          sourceDurationMs: 8001,
        );
        paths.add(audio.input.path);
        expect(audio.input.duration.inMilliseconds, 8001);
        final bytes = await File(audio.input.path).readAsBytes();
        expect(
          ByteData.sublistView(bytes).getUint32(40, Endian.little),
          8001 * 16 * 2,
        );
        await expectLater(
          extractor.extract(video.path, 0, 8005, sourceDurationMs: 8000),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.message,
              'range error',
              contains('超出视频时长'),
            ),
          ),
        );
        await expectLater(
          extractor.extract(video.path, 0, 7000, sourceDurationMs: 7000),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.message,
              'stale clock',
              contains('时长信息已变化'),
            ),
          ),
        );
      } finally {
        for (final path in paths) {
          await const MethodChannelAlgorithmAudioImport().deleteInput(path);
        }
        await video.delete();
      }
    },
  );
  testWidgets(
    'live extracted video audio completes chord and separation jobs',
    (tester) async {
      final origin = await const AlgorithmServiceConfiguration().load();
      final endpoint = AlgorithmEndpoint(origin, allowLocalHttp: true);
      final root = (await const AlgorithmStemPlatform().directory()).parent;
      final folder = Directory('${root.path}/guitarpal_videos');
      await folder.create(recursive: true);
      final video = File('${folder.path}/live-analysis-generated.mp4');
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      String? input;
      final api = LegacyAlgorithmApi(endpoint);
      try {
        await api.ping();
        final extracted = await const VideoAudioExtractor().extract(
          video.path,
          0,
          8000,
          sourceDurationMs: 8000,
        );
        input = extracted.input.path;
        for (final operation in AlgorithmOperation.values) {
          final watch = Stopwatch()..start();
          // Exactly one POST per operation; a lost receipt fails this test without replay.
          final prior = operation == AlgorithmOperation.chords
              ? const String.fromEnvironment('LIVE_CHORD_JOB_ID')
              : const String.fromEnvironment('LIVE_SEPARATION_JOB_ID');
          final jobId = prior.isNotEmpty
              ? prior
              : (await api.upload(
                  input,
                  'generated-video-audio.wav',
                  operation: operation,
                )).jobId;
          debugPrint('LIVE_VIDEO_${operation.name}: job=$jobId');
          while (true) {
            final status = await api.status(jobId, operation);
            if (status.state == LegacyJobState.failed) {
              fail('${operation.name}: ${status.error ?? status.message}');
            }
            if (status.state == LegacyJobState.completed) break;
            if (watch.elapsed > const Duration(minutes: 3)) {
              throw TimeoutException('${operation.name} did not complete');
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          final result = await api.result(jobId, operation);
          expect(result['status'], 'completed');
          if (operation == AlgorithmOperation.separation) {
            final stems = LegacySeparationResult.fromJson(result, endpoint);
            expect(stems.stems, hasLength(7));
            expect(stems.duration.inMilliseconds, closeTo(8000, 100));
          }
          debugPrint(
            'LIVE_VIDEO_${operation.name}: completed in ${watch.elapsed.inSeconds}s',
          );
        }
      } finally {
        api.close();
        if (input != null) {
          await const MethodChannelAlgorithmAudioImport().deleteInput(input);
        }
        await video.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
    skip: !const bool.fromEnvironment('CHECK_ALGORITHM_JOBS'),
  );
}

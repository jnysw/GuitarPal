import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_access.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/data/video_audio_extractor.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';

import 'support/video_analysis_fixture.dart';

/// Opt-in live acceptance only. No access token may be passed via Dart defines.
/// The host writes a one-time 0600 bootstrap through adb stdin into app-private
/// storage after the readiness marker; it is deleted before secure persistence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'public Android client extracts generated video, runs both authenticated algorithms and verifies resumed downloads plus native mix',
    (tester) async {
      const access = AlgorithmAccess(), secure = FlutterSecureStorage();
      const mix = AlgorithmMixPlatform();
      final keys = [AlgorithmAccess.key, AlgorithmAccess.guestKey];
      final prior = {for (final key in keys) key: await secure.read(key: key)};
      final root = await const AlgorithmStemPlatform().directory();
      final bootstrap = File('${root.parent.path}/melpal-test-credential.json');
      final video = File(
        '${root.parent.path}/guitarpal_videos/melpal-live-${const Uuid().v4()}.mp4',
      );
      final report = File('${root.parent.path}/melpal-live-report.json');
      final trace = <String>[];
      final endpoint = AlgorithmEndpoint(
        melpalAlgorithmOrigin,
        allowLocalHttp: false,
      );
      final api = LegacyAlgorithmApi(
        endpoint,
        client: _TraceClient(http.Client(), trace),
      );
      final localId = 'public-live-${const Uuid().v4()}';
      final store = AlgorithmStemStore(
        () async => root,
        clientFactory: () => _TraceClient(http.Client(), trace),
      );
      final summary = <String, Object?>{
        'source': 'generated-eight-second-video',
        'jobs': <String, Object?>{},
      };
      String? input;
      try {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('MelPal 合成音频联调'))),
        );
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('IMPORT_MELPAL_TEST_CREDENTIAL')) {
          debugPrint('MELPAL_PRIVATE_CREDENTIAL_READY');
          final waiting = Stopwatch()..start();
          while (!await bootstrap.exists()) {
            if (waiting.elapsed > const Duration(seconds: 45)) {
              throw TimeoutException('Credential bridge not supplied');
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (await bootstrap.length() > 4096) {
            throw const FormatException('Credential bridge is oversized');
          }
          final value = await bootstrap.readAsString();
          await bootstrap.delete();
          await access.save(value);
          await secure.delete(key: AlgorithmAccess.guestKey);
        }
        await api.ping();
        await video.parent.create(recursive: true);
        await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
        final extracted = await const VideoAudioExtractor().extract(
          video.path,
          0,
          8000,
          sourceDurationMs: 8000,
        );
        input = extracted.input.path;
        for (final operation in AlgorithmOperation.values) {
          final watch = Stopwatch()..start();
          final oldId = operation == AlgorithmOperation.chords
              ? const String.fromEnvironment('LIVE_CHORD_JOB_ID')
              : const String.fromEnvironment('LIVE_SEPARATION_JOB_ID');
          final id = oldId.isNotEmpty
              ? oldId
              : (await api.upload(
                  input,
                  'melpal-generated-eight-seconds.wav',
                  operation: operation,
                )).jobId;
          final item = <String, Object?>{'job_id': id};
          (summary['jobs'] as Map<String, Object?>)[operation.name] = item;
          await report.writeAsString(jsonEncode(summary), flush: true);
          debugPrint('MELPAL_LIVE_${operation.name}: job=$id');
          while (true) {
            final status = await api.status(id, operation);
            if (status.state == LegacyJobState.failed) {
              throw StateError('Synthetic ${operation.name} job failed');
            }
            if (status.state == LegacyJobState.completed) break;
            if (watch.elapsed > const Duration(minutes: 3)) {
              throw TimeoutException('Synthetic job not completed');
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          final result = await api.result(id, operation);
          item['completed_ms'] = watch.elapsedMilliseconds;
          if (operation == AlgorithmOperation.chords) {
            final chords = LegacyChordResult.fromJson(result);
            expect(chords.canSyncWithOriginal, isTrue);
            expect(
              chords.timeline!.inputDuration.inMilliseconds,
              closeTo(8000, 2),
            );
            item['segments'] = chords.segments.length;
            item['automatic_offset_ms'] = chords.timeline!.offsetMs;
            item['input_samples'] = chords.timeline!.inputSamples;
            await Future<void>.delayed(const Duration(seconds: 3));
          } else {
            final stems = LegacySeparationResult.fromJson(result, endpoint);
            expect(stems.stems, isNotEmpty);
            expect(stems.duration.inMilliseconds, closeTo(8000, 100));
            expect(stems.stems.every((s) => s.sha256 != null), isTrue);
            final largest = ([
              ...stems.stems,
            ]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes))).first;
            expect(largest.sizeBytes, greaterThan(1024));
            final interrupted = AlgorithmStemStore(
              () async => root,
              maxAttempts: 1,
              clientFactory: () =>
                  _CutClient(_TraceClient(http.Client(), trace)),
            );
            await expectLater(
              interrupted.download(localId, largest),
              throwsA(isA<AlgorithmApiError>()),
            );
            final partial = await store.inspect(localId, [largest]);
            expect(partial[largest.id]!.receivedBytes, 1024);
            final paths = await store.downloadBatch(localId, stems.stems);
            expect(
              trace.any((entry) => entry.contains('Range=bytes=1024-')),
              isTrue,
            );
            expect(paths.length, stems.stems.length);
            final models = stems.stems
                .where((s) => s.origin == 'model')
                .toList();
            await mix.load({
              for (final stem in models) stem.id: paths[stem.id]!,
            });
            await mix.configureTracks(
              {for (final stem in models) stem.id: const StemMixControl()},
              master: 0,
              speed: 1,
            );
            await mix.play();
            await Future<void>.delayed(const Duration(milliseconds: 350));
            final playback = await mix.snapshot();
            expect(playback['isPlaying'], isTrue);
            expect(playback['positionMs'] as num, greaterThan(0));
            await mix.stop();
            final offline = AlgorithmStemStore(
              () async => root,
              clientFactory: () =>
                  throw StateError('Offline cache must not request HTTP'),
            );
            for (final stem in stems.stems) {
              expect(await offline.localFile(localId, stem), isNotNull);
            }
            item['stems'] = stems.stems.map((s) => s.id).toList();
            item['verified_files'] = paths.length;
            item['resumed_from_bytes'] = 1024;
            item['native_mix_position_ms'] = playback['positionMs'];
          }
          await report.writeAsString(jsonEncode(summary), flush: true);
          debugPrint('MELPAL_LIVE_${operation.name}: complete');
        }
        final expectedPosts =
            (const String.fromEnvironment('LIVE_CHORD_JOB_ID').isEmpty
                ? 1
                : 0) +
            (const String.fromEnvironment('LIVE_SEPARATION_JOB_ID').isEmpty
                ? 1
                : 0);
        expect(trace.where((p) => p.startsWith('POST ')).length, expectedPosts);
        summary['post_count'] = expectedPosts;
        summary['passed'] = true;
        await report.writeAsString(jsonEncode(summary), flush: true);
      } finally {
        api.close();
        await mix.stop();
        await store.deleteTask(localId);
        if (input != null) {
          await const MethodChannelAlgorithmAudioImport().deleteInput(input);
        }
        if (await video.exists()) await video.delete();
        if (await bootstrap.exists()) await bootstrap.delete();
        for (final entry in prior.entries) {
          if (entry.value case final value?) {
            await secure.write(key: entry.key, value: value);
          } else {
            await secure.delete(key: entry.key);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !const bool.fromEnvironment('CHECK_MELPAL_LIVE'),
  );
}

class _TraceClient extends http.BaseClient {
  _TraceClient(this.inner, this.trace);
  final http.Client inner;
  final List<String> trace;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Range is non-secret; Authorization and request bodies are never recorded.
    trace.add(
      '${request.method} ${request.url.path}${request.headers['Range'] == null ? '' : ' Range=${request.headers['Range']}'}',
    );
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

class _CutClient extends http.BaseClient {
  _CutClient(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (response.statusCode != 200) return response;
    return http.StreamedResponse(
      _firstKilobyte(response.stream),
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: response.request,
    );
  }

  Stream<List<int>> _firstKilobyte(Stream<List<int>> source) async* {
    var n = 0;
    await for (final chunk in source) {
      final count = chunk.length.clamp(0, 1024 - n);
      if (count > 0) yield chunk.sublist(0, count);
      n += count;
      if (n >= 1024) break;
    }
  }

  @override
  void close() => inner.close();
}

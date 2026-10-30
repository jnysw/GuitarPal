import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';

import '../test/support/stem_flac_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real interrupted HTTP resumes FLAC; native decode is lossless and reusable',
    (tester) async {
      final bytes = base64Decode(stemFlacFixtureBase64);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final ranges = <String?>[], validators = <String?>[];
      final listener = server.listen((request) async {
        requests++;
        ranges.add(request.headers.value('range'));
        validators.add(request.headers.value('if-range'));
        request.response.headers.set('content-type', 'audio/flac');
        request.response.headers.set('etag', '"fixture-v1"');
        if (requests == 1) {
          request.response.contentLength = bytes.length;
          final socket = await request.response.detachSocket();
          socket.add(bytes.sublist(0, 4096));
          await socket.flush();
          socket.destroy();
        } else {
          final start = int.parse(
            RegExp(r'bytes=(\d+)-').firstMatch(ranges.last!)![1]!,
          );
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            'content-range',
            'bytes $start-${bytes.length - 1}/${bytes.length}',
          );
          request.response.contentLength = bytes.length - start;
          request.response.add(bytes.sublist(start));
          await request.response.close();
        }
      });
      const platform = AlgorithmStemPlatform();
      const player = AlgorithmMixPlatform();
      final store = AlgorithmStemStore(platform.directory, maxAttempts: 1);
      final stem = LegacyStemFile.fromJson(
        {
          'id': 'guitar',
          'origin': 'model',
          'size_bytes': bytes.length,
          'duration_seconds': 2,
          'sample_rate': 16000,
          'channels': 1,
          'content_type': 'audio/flac',
          'download_url': '/api/v1/separation/jobs/resume/files/guitar',
        },
        AlgorithmEndpoint(
          'http://127.0.0.1:${server.port}',
          allowLocalHttp: true,
        ),
        'resume',
      );
      const task = 'integration-resume';
      try {
        await store.deleteTask(task);
        await expectLater(
          store.download(task, stem),
          throwsA(isA<AlgorithmApiError>()),
        );
        final restarted = AlgorithmStemStore(
          platform.directory,
          maxAttempts: 1,
        );
        final file = await restarted.download(task, stem);
        expect(requests, 2);
        expect(ranges, [null, 'bytes=4096-']);
        expect(validators, [null, '"fixture-v1"']);
        expect(await file.readAsBytes(), bytes);
        await player.load({'guitar': file.path});
        final decoded = File('${file.path}.mix.wav');
        final pcm = await decoded.readAsBytes();
        expect(sha256.convert(pcm.sublist(44)).toString(), stemFlacPcmSha256);
        final stamp = await decoded.lastModified();
        await player.configure(
          StemMixSettings(
            speed: .73,
            controls: {'guitar': const StemMixControl(volume: .6, pan: -.4)},
          ),
          ['guitar'],
        );
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final state = await player.snapshot();
        expect(state['durationMs'], 2000);
        expect(state['positionMs'], greaterThan(50));
        await player.stop();
        await player.load({'guitar': file.path});
        expect(await decoded.lastModified(), stamp);
        await player.stop();
        await decoded.writeAsBytes([0]);
        await player.load({'guitar': file.path});
        expect(
          sha256.convert((await decoded.readAsBytes()).sublist(44)).toString(),
          stemFlacPcmSha256,
        );
        expect(requests, 2);
      } finally {
        await player.stop();
        await listener.cancel();
        await server.close(force: true);
        await store.deleteTask(task);
      }
    },
  );
}

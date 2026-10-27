import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> legacyFixture() => jsonDecode(
  File('contracts/legacy_algorithm/fixtures/chords_result.json')
      .readAsStringSync(),
) as Map<String, Object?>;

void main() {
  test(
    'real HTTP multipart uses audio, query options and source filename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'guitarpal_algorithm_http_',
      );
      final file = File('${directory.path}/test.wav');
      await file.writeAsBytes(List.generate(8000, (i) => i % 256));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final endpoint = AlgorithmEndpoint(
        'http://127.0.0.1:${server.port}',
        allowLocalHttp: true,
      );
      final api = LegacyAlgorithmApi(endpoint);
      final received = <String>[];
      final handler = server.forEach((request) async {
        received.add(request.uri.path);
        if (request.method == 'POST') {
          expect(request.uri.queryParameters, {
            'smooth_method': 'hmm',
            'include_raw_chords': 'false',
          });
          expect(request.headers.contentType?.mimeType, 'multipart/form-data');
          expect(request.headers.value('authorization'), isNull);
          final body = await request.fold<List<int>>(
            [],
            (a, b) => a..addAll(b),
          );
          expect(
            utf8.decode(body, allowMalformed: true),
            contains('name="audio"'),
          );
          request.response.statusCode = 202;
          request.response.write(
            jsonEncode({
              'job_id': 'contract_job_1',
              'status': 'queued',
              'message': 'queued',
              'poll_url': '/api/v1/jobs/contract_job_1/status',
              'result_url': '/api/v1/jobs/contract_job_1/result',
            }),
          );
        } else if (request.uri.path.endsWith('/status')) {
          request.response.write(
            jsonEncode({
              'job_id': 'contract_job_1',
              'status': 'completed',
              'progress': 100,
              'message': 'completed',
              'error': null,
            }),
          );
        } else {
          request.response.write(jsonEncode(legacyFixture()));
        }
        await request.response.close();
      });
      try {
        var sent = 0;
        final receipt = await api.upload(
          file.path,
          '测试.wav',
          onProgress: (value, _) => sent = value,
        );
        expect(sent, 8000);
        expect(
          (await api.status(receipt.jobId, AlgorithmOperation.chords)).state,
          LegacyJobState.completed,
        );
        final result = LegacyChordResult.fromJson(
          await api.result(receipt.jobId, AlgorithmOperation.chords),
        );
        expect(result.segments[1].start.inMilliseconds, 3250);
        expect(result.segments[1].displayLabel, 'Am');
        expect(result.segments.every((s) => s.confidence == null), isTrue);
        expect(result.canSyncWithOriginal, isFalse);
        expect(received, [
          '/api/v1/jobs',
          '/api/v1/jobs/contract_job_1/status',
          '/api/v1/jobs/contract_job_1/result',
        ]);
      } finally {
        api.close();
        await server.close(force: true);
        await handler;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'rejects cross-origin callbacks and exposes flat errors and Retry-After',
    () async {
      final endpoint = AlgorithmEndpoint(
        'https://algorithm.example/api/v1',
        allowLocalHttp: false,
      );
      expect(
        () => LegacyUploadReceipt.fromJson(
          {
            'job_id': 'job-1',
            'status': 'queued',
            'poll_url': '//other.example/api/v1/jobs/job-1/status',
            'result_url': '/api/v1/jobs/job-1/result',
          },
          endpoint,
          AlgorithmOperation.chords,
        ),
        throwsFormatException,
      );
      expect(
        () => AlgorithmEndpoint(
          'https://user:secret@algorithm.example',
          allowLocalHttp: false,
        ),
        throwsFormatException,
      );
      expect(
        () => AlgorithmEndpoint('http://public.example', allowLocalHttp: true),
        throwsFormatException,
      );
      final api = LegacyAlgorithmApi(
        endpoint,
        client: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response(
            jsonEncode({
              'error': 'queue_full',
              'detail': '请稍后重试',
              'job_id': null,
            }),
            429,
            headers: {
              'retry-after': '20',
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );
      await expectLater(
        api.status('job-1', AlgorithmOperation.chords),
        throwsA(
          isA<AlgorithmApiError>()
              .having((e) => e.code, 'code', 'queue_full')
              .having(
                (e) => e.retryAfter,
                'delay',
                const Duration(seconds: 20),
              ),
        ),
      );
      api.close();
      expect(displayLegacyChord('C:maj7'), 'Cmaj7');
      expect(displayLegacyChord('C:minmaj7/Eb'), 'Cm(maj7)/Eb');
      expect(displayLegacyChord('C:unknown'), 'C:unknown');
    },
  );

  test('stems preserve derived accompaniment and reject path substitution', () {
    final endpoint = AlgorithmEndpoint(
      'https://algorithm.example',
      allowLocalHttp: false,
    );
    final stem = <String, Object?>{
      'id': 'instrumental',
      'origin': 'derived',
      'size_bytes': 1000,
      'duration_seconds': 8,
      'sample_rate': 44100,
      'channels': 2,
      'content_type': 'audio/wav',
      'download_url': '/api/v1/separation/jobs/job-1/files/instrumental',
    };
    expect(LegacyStemFile.fromJson(stem, endpoint, 'job-1').origin, 'derived');
    stem['download_url'] = 'file:///F:/private/input.wav';
    expect(
      () => LegacyStemFile.fromJson(stem, endpoint, 'job-1'),
      throwsFormatException,
    );
  });
}

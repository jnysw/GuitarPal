import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/algorithm_fixtures.dart';

Map<String, Object?> legacyFixture() => jsonDecode(
  File('contracts/legacy_algorithm/fixtures/chords_result.json')
      .readAsStringSync(),
) as Map<String, Object?>;

void main() {
  test('unsent connection failure differs from a lost response after the body was read', () async {
    final root = await Directory.systemTemp.createTemp('gp_receipt_loss_');
    final file = File('${root.path}/audio.wav');
    await file.writeAsBytes(syntheticAlgorithmWav());
    final endpoint = AlgorithmEndpoint(
      'https://algorithm.example',
      allowLocalHttp: false,
    );
    final unsent = LegacyAlgorithmApi(endpoint, client: _UnsentClient());
    var posts = 0;
    final lost = LegacyAlgorithmApi(
      endpoint,
      uploadTimeout: const Duration(milliseconds: 20),
      client: MockClient((r) async {
        posts++;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response('{}', 202);
      }),
    );
    try {
      await expectLater(
        unsent.upload(file.path, 'audio.wav'),
        throwsA(
          isA<AlgorithmApiError>().having(
            (e) => e.code,
            'not sent',
            'upload_not_sent',
          ),
        ),
      );
      await expectLater(
        lost.upload(file.path, 'audio.wav'),
        throwsA(
          isA<AlgorithmApiError>().having(
            (e) => e.code,
            'ambiguous',
            'network_timeout',
          ),
        ),
      );
      expect(posts, 1);
    } finally {
      unsent.close();
      lost.close();
      await root.delete(recursive: true);
    }
  });
  test('upload has its own budget, accepts progressed receipts, and preserves IDs on metadata drift', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gp_upload_budget_',
    );
    final file = File('${directory.path}/input.wav');
    await file.writeAsBytes(syntheticAlgorithmWav());
    final endpoint = AlgorithmEndpoint(
      'https://algorithm.example',
      allowLocalHttp: false,
    );
    var badReceipt = false, calls = 0;
    final api = LegacyAlgorithmApi(
      endpoint,
      requestTimeout: const Duration(milliseconds: 20),
      uploadTimeout: const Duration(seconds: 1),
      client: MockClient((r) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 70));
        return http.Response(
          jsonEncode({
            'job_id': 'existing',
            'status': 'processing',
            'poll_url': badReceipt
                ? 'https://evil.example/private'
                : '/api/v1/jobs/existing/status',
            'result_url': '/api/v1/jobs/existing/result',
          }),
          202,
        );
      }),
    );
    try {
      expect((await api.upload(file.path, 'input.wav')).jobId, 'existing');
      badReceipt = true;
      await expectLater(
        api.upload(file.path, 'input.wav'),
        throwsA(
          isA<AlgorithmReceiptError>().having((e) => e.jobId, 'ID', 'existing'),
        ),
      );
      expect(
        calls,
        2,
      ); // Never replay a POST to repair acknowledgement metadata.
    } finally {
      api.close();
      await directory.delete(recursive: true);
    }
  });

  test('separation follows actual safe IDs/count and excludes derived sums from default mix', () {
    final json = separationFixture();
    final stems = (json['stems'] as List)
        .take(3)
        .map((s) => Map<String, Object?>.from(s as Map))
        .toList();
    stems[0]['id'] = 'lead_guitar';
    stems[0]['origin'] = 'model';
    stems[0]['download_url'] =
        '/api/v1/separation/jobs/${json['job_id']}/files/lead_guitar';
    stems[1]['origin'] = 'model';
    stems[2]['origin'] = 'derived';
    json['stems'] = stems;
    final endpoint = AlgorithmEndpoint(
      'https://algorithm.example',
      allowLocalHttp: false,
    );
    final parsed = LegacySeparationResult.fromJson(json, endpoint);
    expect(parsed.stems, hasLength(3));
    expect(parsed.mixStems, hasLength(2));
    expect(parsed.stems.first.displayName, 'lead_guitar');
    stems[0]['id'] = '../private';
    expect(
      () => LegacySeparationResult.fromJson(json, endpoint),
      throwsFormatException,
    );
  });
  test('legacy small tail disagreement preserves raw intervals and declared duration but rejects genuine invalid timing', () {
    final json = legacyFixture()..['duration_seconds'] = 7.85;
    json['segments'] = [
      {'chord': 'C', 'roman': 'I', 'start': 0.0, 'end': 7.895},
    ];
    final parsed = LegacyChordResult.fromJson(json);
    expect(parsed.declaredDuration.inMilliseconds, 7850);
    expect(parsed.duration.inMilliseconds, 7850);
    expect(parsed.coverageEnd.inMilliseconds, 7895);
    expect(parsed.segments.single.end.inMilliseconds, 7895);
    expect(parsed.hasTailTimingDifference, isTrue);
    expect(json['duration_seconds'], 7.85); // Raw machine output is unchanged.
    json['segments'] = [
      {'chord': 'C', 'roman': 'I', 'start': 0.0, 'end': 7.901},
    ];
    expect(() => LegacyChordResult.fromJson(json), throwsFormatException);
    json['segments'] = [
      {'chord': 'C', 'roman': 'I', 'start': 0.0, 'end': 4.0},
      {'chord': 'Am', 'roman': 'vi', 'start': 3.99, 'end': 7.85},
    ];
    expect(() => LegacyChordResult.fromJson(json), throwsFormatException);
  });
  test('tailnet connection errors tell private-test users to connect Tailscale without asking for an address', () async {
    final api = LegacyAlgorithmApi(
      AlgorithmEndpoint(
        'https://example.tailnet.ts.net',
        allowLocalHttp: false,
      ),
      client: MockClient(
        (request) async => throw http.ClientException('test offline'),
      ),
    );
    try {
      await expectLater(
        api.ping(),
        throwsA(
          isA<AlgorithmApiError>()
              .having(
                (e) => e.message,
                'actionable message',
                contains('Tailscale'),
              )
              .having(
                (e) => e.message,
                'no address form',
                isNot(contains('检查地址')),
              ),
        ),
      );
    } finally {
      api.close();
    }
  });
  test('health preflight has a short independent timeout and does not report a lost POST receipt', () async {
    final api = LegacyAlgorithmApi(
      AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      requestTimeout: const Duration(seconds: 2),
      healthTimeout: const Duration(milliseconds: 20),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/health/ping');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return http.Response('{"ping":"pong"}', 200);
      }),
    );
    try {
      await expectLater(
        api.ping(),
        throwsA(
          isA<AlgorithmApiError>()
              .having((e) => e.code, 'code', 'network_timeout')
              .having((e) => e.message, 'message', isNot(contains('服务器可能已接收'))),
        ),
      );
    } finally {
      api.close();
    }
  });
  test('separation POST uses its route/query and accepts unknown processing progress and structured failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gp_separation_post_',
    );
    final file = File('${directory.path}/test.wav');
    await file.writeAsBytes(syntheticAlgorithmWav());
    final endpoint = AlgorithmEndpoint(
      'https://algorithm.example',
      allowLocalHttp: false,
    );
    final api = LegacyAlgorithmApi(
      endpoint,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/separation/jobs');
          expect(request.url.queryParameters, {'output_format': 'wav_s16'});
          expect(
            utf8.decode(request.bodyBytes, allowMalformed: true),
            contains('name="audio"'),
          );
          return http.Response(
            jsonEncode({
              'job_id': 'job-1',
              'status': 'queued',
              'poll_url': '/api/v1/separation/jobs/job-1/status',
              'result_url': '/api/v1/separation/jobs/job-1/result',
            }),
            202,
          );
        }
        if (request.url.path.endsWith('/result')) {
          return http.Response(
            jsonEncode(separationFixture(jobId: 'job-1')),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'job_id': 'job-1',
            'status': 'failed',
            'progress': null,
            'message': 'failed',
            'error': {
              'code': 'processing_failed',
              'message': '可读推理错误',
              'retryable': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    try {
      await api.upload(
        file.path,
        'test.wav',
        operation: AlgorithmOperation.separation,
      );
      final status = await api.status('job-1', AlgorithmOperation.separation);
      expect(status.error, '可读推理错误');
      expect(status.progress, isNull);
      expect(
        (await api.result('job-1', AlgorithmOperation.separation))['stems'],
        hasLength(7),
      );
    } finally {
      api.close();
      await directory.delete(recursive: true);
    }
  });
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

class _UnsentClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw http.ClientException('no connection established');
}

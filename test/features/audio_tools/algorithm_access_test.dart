import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_access.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const access = AlgorithmAccess();
  final endpoint = AlgorithmEndpoint(
    melpalAlgorithmOrigin,
    allowLocalHttp: false,
  );
  final secret = 'mp_${'a' * 43}';
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('private storage accepts scoped JSON, refuses wrong origin and header injection, clears without echo', () async {
    await access.save(
      jsonEncode({'base_url': melpalAlgorithmOrigin, 'access_token': secret}),
    );
    expect(await access.token(), secret);
    expect(await const AlgorithmAccess().configured(), isTrue);
    await expectLater(
      access.save(
        jsonEncode({
          'base_url': 'https://other.example',
          'access_token': secret,
        }),
      ),
      throwsFormatException,
    );
    await expectLater(
      access.save('$secret\r\nX-Test: bad'),
      throwsFormatException,
    );
    expect(await access.token(), secret);
    await access.clear();
    expect(await access.configured(), isFalse);
  });

  test('credentials only accompany exact HTTPS origin and protected paths; redirects remain disabled', () async {
    await access.save(secret);
    final observed = <http.BaseRequest>[];
    final client = MelpalHttpClient(
      MockClient.streaming((r, _) async {
        observed.add(r);
        return http.StreamedResponse(
          const Stream.empty(),
          302,
          headers: {'location': 'https://elsewhere.example/steal'},
        );
      }),
    );
    for (final url in [
      '$melpalAlgorithmOrigin/api/v1/jobs/${'0' * 32}/status',
      '$melpalAlgorithmOrigin/health',
      'https://api.melpal.com.cn.evil.example/api/v1/jobs',
      'http://api.melpal.com.cn/api/v1/jobs',
      'https://api.melpal.com.cn:444/api/v1/jobs',
      'https://old.ts.net/api/v1/jobs',
    ]) {
      await client.send(http.Request('GET', Uri.parse(url)));
    }
    expect(observed.first.headers['Authorization'], 'Bearer $secret');
    expect(observed.first.followRedirects, isFalse);
    expect(
      observed.skip(1).every((r) => !r.headers.containsKey('Authorization')),
      isTrue,
    );
    expect(observed.length, 6);
    client.close();
  });

  test('public preflight authenticates using only health and GET, never model diagnostics or POST', () async {
    await access.save(secret);
    final routes = <String>[];
    final api = LegacyAlgorithmApi(
      endpoint,
      client: MockClient((r) async {
        expect(r.method, 'GET');
        routes.add(r.url.path);
        if (r.url.path == '/health') {
          expect(r.headers['Authorization'], isNull);
          return http.Response(
            '{"status":"ok","service":"melpal-algorithm-api"}',
            200,
          );
        }
        expect(r.headers['Authorization'], 'Bearer $secret');
        return http.Response('{"error":"not_found","detail":"Not found"}', 404);
      }),
    );
    await api.ping(operation: AlgorithmOperation.separation);
    expect(routes, ['/health', '/api/v1/jobs/${'0' * 32}/status']);
    api.close();
  });

  test('missing local credentials block before extraction or any HTTP; 401 has actionable sanitized message', () async {
    var calls = 0;
    final api = LegacyAlgorithmApi(
      endpoint,
      client: MockClient((r) async {
        calls++;
        return http.Response('{"detail":"server echo"}', 401);
      }),
    );
    await expectLater(
      api.ping(),
      throwsA(
        isA<AlgorithmApiError>().having(
          (e) => e.code,
          'code',
          'authorization_required',
        ),
      ),
    );
    expect(calls, 0);
    await access.save(secret);
    await expectLater(
      api.status('0' * 32, AlgorithmOperation.chords),
      throwsA(
        isA<AlgorithmApiError>()
            .having((e) => e.httpStatus, 'HTTP', 401)
            .having(
              (e) => e.message,
              'message',
              allOf(contains('内测凭据'), isNot(contains('server echo'))),
            ),
      ),
    );
    expect(calls, 1);
    api.close();
  });

  test('multipart, status and result share bearer; Retry-After and uncertain acceptance remain explicit', () async {
    await access.save(secret);
    final root = await Directory.systemTemp.createTemp('gp_auth_upload_');
    final f = await File('${root.path}/audio.wav')
        .writeAsBytes(syntheticAlgorithmWav());
    var posts = 0;
    final api = LegacyAlgorithmApi(
      endpoint,
      client: MockClient.streaming((r, body) async {
        expect(r.headers['Authorization'], 'Bearer $secret');
        if (r.method == 'POST') {
          posts++;
          expect(
            utf8.decode(
              (await http.ByteStream(body).toBytes()).take(200).toList(),
              allowMalformed: true,
            ),
            contains('name="audio"'),
          );
          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                '{"error":"submission_unavailable","detail":"unknown"}',
              ),
            ),
            503,
          );
        }
        return http.StreamedResponse(
          Stream.value(
            utf8.encode('{"error":"rate_limited","detail":"Try later"}'),
          ),
          429,
          headers: {'retry-after': '60'},
        );
      }),
    );
    try {
      await expectLater(
        api.upload(f.path, 'audio.wav'),
        throwsA(
          isA<AlgorithmApiError>().having(
            (e) => e.code,
            'code',
            'submission_unavailable',
          ),
        ),
      );
      expect(posts, 1);
      await expectLater(
        api.result('0' * 32, AlgorithmOperation.chords),
        throwsA(
          isA<AlgorithmApiError>().having(
            (e) => e.retryAfter,
            'delay',
            const Duration(seconds: 60),
          ),
        ),
      );
    } finally {
      api.close();
      await root.delete(recursive: true);
    }
  });

  test('authenticated interrupted stem survives 401, resumes Range after token replacement and opens offline without credentials', () async {
    final root = await Directory.systemTemp.createTemp('gp_auth_stem_');
    final wav = syntheticAlgorithmWav();
    final stem = LegacySeparationResult.fromJson(
      separationFixture(),
      endpoint,
    ).mixStems.first;
    var phase = 0, calls = 0;
    AlgorithmStemStore store() => AlgorithmStemStore(
      () async => root,
      maxAttempts: 1,
      clientFactory: () => MockClient.streaming((r, _) async {
        calls++;
        expect(
          r.headers['Authorization'],
          'Bearer ${await access.requireToken()}',
        );
        if (phase == 1) return http.StreamedResponse(const Stream.empty(), 401);
        final resumed = phase == 2;
        if (resumed) {
          expect(r.headers['Range'], 'bytes=32768-');
          expect(r.headers['If-Range'], '"v1"');
        }
        return http.StreamedResponse(
          Stream.value(resumed ? wav.sublist(32768) : wav.sublist(0, 32768)),
          resumed ? 206 : 200,
          contentLength: resumed ? wav.length - 32768 : wav.length,
          headers: {
            'content-type': 'audio/wav',
            'etag': '"v1"',
            if (resumed)
              'content-range': 'bytes 32768-${wav.length - 1}/${wav.length}',
          },
        );
      }),
    );
    try {
      await access.save(secret);
      await expectLater(
        store().download('auth-task', stem),
        throwsA(isA<AlgorithmApiError>()),
      );
      phase = 1;
      await expectLater(
        store().download('auth-task', stem),
        throwsA(
          isA<AlgorithmApiError>().having((e) => e.httpStatus, 'HTTP', 401),
        ),
      );
      expect(calls, 2);
      expect(await store().inspect('auth-task', [stem]), isNotEmpty);
      await access.save('mp_${'b' * 43}');
      phase = 2;
      final file = await store().download('auth-task', stem);
      expect(await file.readAsBytes(), wav);
      await access.clear();
      expect(await store().localFile('auth-task', stem), isNotNull);
      expect(calls, 3);
      for (final f in root.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.json'),
      )) {
        expect(await f.readAsString(), isNot(contains(secret)));
      }
    } finally {
      await root.delete(recursive: true);
    }
  });
}

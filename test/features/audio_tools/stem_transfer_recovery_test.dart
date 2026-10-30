import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/algorithm_fixtures.dart';
import '../../support/stem_flac_fixture.dart';

void main() {
  late Directory root;
  final endpoint = AlgorithmEndpoint(
    'https://algorithm.example',
    allowLocalHttp: false,
  );
  final wav = syntheticAlgorithmWav();
  final stems = LegacySeparationResult.fromJson(
    separationFixture(),
    endpoint,
  ).mixStems;
  final stem = stems.first;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('gp_resume_');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  http.StreamedResponse response(
    List<int> bytes, {
    int status = 200,
    int? length,
    Map<String, String> headers = const {},
  }) => http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: length ?? bytes.length,
    headers: {'content-type': 'audio/wav', 'etag': '"v1"', ...headers},
  );
  AlgorithmStemStore store(
    Future<http.StreamedResponse> Function(http.BaseRequest) handler, {
    int attempts = 1,
    Duration timeout = const Duration(seconds: 1),
  }) => AlgorithmStemStore(
    () async => root,
    maxAttempts: attempts,
    timeout: timeout,
    retryDelay: Duration.zero,
    clientFactory: () => MockClient.streaming((request, _) => handler(request)),
  );
  Future<void> interrupted() async {
    await expectLater(
      store((_) async => response(wav.sublist(0, 32768), length: wav.length))
          .download('task', stem),
      throwsA(isA<AlgorithmApiError>()),
    );
  }

  test(
    'interruption survives store restart and resumes using Range and If-Range',
    () async {
      await interrupted();
      final progress = <int>[];
      final restored = store((r) async {
        expect(r.headers['Range'], 'bytes=32768-');
        expect(r.headers['If-Range'], '"v1"');
        return response(
          wav.sublist(32768),
          status: 206,
          headers: {
            'content-range': 'bytes 32768-${wav.length - 1}/${wav.length}',
          },
        );
      });
      final file = await restored.download(
        'task',
        stem,
        onProgress: (n, _) => progress.add(n),
      );
      expect(progress.first, 32768);
      expect(await file.readAsBytes(), wav);
      expect(await File('${file.path}.part').exists(), isFalse);
      final offline = AlgorithmStemStore(
        () async => root,
        clientFactory: () => throw StateError('offline'),
      );
      expect((await offline.download('task', stem)).path, file.path);
    },
  );

  test('automatic GET retry resumes one incomplete track and never reuploads audio', () async {
    var calls = 0;
    final retry = store((r) async {
      expect(r.method, 'GET');
      calls++;
      if (calls == 1) {
        return response(wav.sublist(0, 32768), length: wav.length);
      }
      expect(r.headers['Range'], 'bytes=32768-');
      return response(
        wav.sublist(32768),
        status: 206,
        headers: {
          'content-range': 'bytes 32768-${wav.length - 1}/${wav.length}',
        },
      );
    }, attempts: 3);
    expect(await (await retry.download('task', stem)).readAsBytes(), wav);
    expect(calls, 2);
  });

  test('server ignoring Range replaces prefix and never appends a complete response', () async {
    await interrupted();
    final file = await store((r) async {
      expect(r.headers['Range'], isNotNull);
      return response(wav, headers: {'etag': '"v2"'});
    }).download('task', stem);
    expect(await file.readAsBytes(), wav);
  });

  test('wrong content range and changed validators are rejected without corrupt cache', () async {
    for (final headers in [
      {'content-range': 'bytes 1-${wav.length - 1}/${wav.length}'},
      {
        'content-range': 'bytes 32768-${wav.length - 1}/${wav.length}',
        'etag': '"v2"',
      },
    ]) {
      await interrupted();
      final invalid = store(
        (_) async =>
            response(wav.sublist(32768), status: 206, headers: headers),
      );
      await expectLater(invalid.download('task', stem), throwsFormatException);
      expect(await invalid.localFile('task', stem), isNull);
      expect(await File('${root.path}/task_vocals.wav.part').exists(), isFalse);
    }
  });

  test(
    'pause closes transfer, preserves prefix, and next attempt resumes',
    () async {
      final token = StemDownloadCancellation();
      final transfer = store(
        (_) async => http.StreamedResponse(
          Stream.fromIterable([wav.sublist(0, 32768), wav.sublist(32768)]),
          200,
          contentLength: wav.length,
          headers: {'content-type': 'audio/wav', 'etag': '"v1"'},
        ),
      );
      await expectLater(
        transfer.download(
          'task',
          stem,
          cancellation: token,
          onProgress: (n, _) {
            if (n >= 32768) token.cancel();
          },
        ),
        throwsA(isA<StemDownloadPaused>()),
      );
      final file = await store((r) async {
        expect(r.headers['Range'], 'bytes=32768-');
        return response(
          wav.sublist(32768),
          status: 206,
          headers: {
            'content-range': 'bytes 32768-${wav.length - 1}/${wav.length}',
          },
        );
      }).download('task', stem);
      expect(await file.readAsBytes(), wav);
    },
  );

  test('416 invalidates only its partial and retries GET from zero', () async {
    await interrupted();
    var calls = 0;
    final transfer = store((r) async {
      calls++;
      if (calls == 1) {
        expect(r.headers['Range'], 'bytes=32768-');
        return response([], status: 416);
      }
      expect(r.headers['Range'], isNull);
      return response(wav);
    }, attempts: 2);
    expect(await (await transfer.download('task', stem)).readAsBytes(), wav);
    expect(calls, 2);
  });

  test('healthy transfer may exceed inactivity timeout while stalled prefix remains resumable', () async {
    final healthy = store(
      (_) async => http.StreamedResponse(
        Stream.periodic(
          const Duration(milliseconds: 40),
          (i) => wav.sublist(i * wav.length ~/ 6, (i + 1) * wav.length ~/ 6),
        ).take(6),
        200,
        contentLength: wav.length,
        headers: {'content-type': 'audio/wav', 'etag': '"v1"'},
      ),
      timeout: const Duration(milliseconds: 150),
    );
    expect(await (await healthy.download('task', stem)).readAsBytes(), wav);
    await healthy.deleteTask('task');
    final stuck = StreamController<List<int>>();
    final stalled = store((_) async {
      scheduleMicrotask(() => stuck.add(wav.sublist(0, 32768)));
      return http.StreamedResponse(
        stuck.stream,
        200,
        contentLength: wav.length,
        headers: {'content-type': 'audio/wav', 'etag': '"v1"'},
      );
    }, timeout: const Duration(milliseconds: 50));
    await expectLater(
      stalled.download('task', stem),
      throwsA(isA<AlgorithmApiError>()),
    );
    expect(await File('${root.path}/task_vocals.wav.part').length(), 32768);
    await stuck.close();
  });

  test('same-size changed PCM cache is repaired one track at a time', () async {
    var requests = 0;
    final first = store((_) async {
      requests++;
      return response(wav);
    });
    final file = await first.download('task', stem);
    final corrupt = List<int>.from(wav)..[100] = 0;
    if (corrupt[100] == wav[100]) corrupt[100] = 1;
    await file.writeAsBytes(corrupt);
    final repair = store((_) async {
      requests++;
      return response(wav);
    });
    expect(await repair.localFile('task', stem), isNull);
    expect(await (await repair.download('task', stem)).readAsBytes(), wav);
    expect(requests, 2);
  });

  test('batch limits parallel transfers to two, reports total progress, and skips complete files', () async {
    var requests = 0, active = 0, maximum = 0;
    final gates = <Completer<void>>[];
    final batch = store((r) async {
      requests++;
      active++;
      if (active > maximum) maximum = active;
      if (requests <= 2) {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
      }
      active--;
      return response(wav);
    });
    final progress = <StemDownloadProgress>[];
    final pending = batch.downloadBatch(
      'task',
      stems,
      onProgress: progress.add,
    );
    for (var i = 0; i < 100 && gates.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(requests, 2);
    for (final gate in gates) {
      gate.complete();
    }
    expect(await pending, hasLength(6));
    expect(maximum, 2);
    expect(progress.last.completedFiles, 6);
    expect(progress.last.fraction, 1);
    expect(progress.last.totalBytes, wav.length * 6);
    final offline = AlgorithmStemStore(
      () async => root,
      clientFactory: () => throw StateError('offline'),
    );
    expect(await offline.downloadBatch('task', stems), hasLength(6));
    expect(requests, 6);
  });

  test(
    'FLAC16 cache verifies real STREAMINFO and remains usable without network',
    () async {
      final flac = base64Decode(stemFlacFixtureBase64);
      final s = LegacyStemFile.fromJson(
        {
          'id': 'guitar',
          'origin': 'model',
          'size_bytes': flac.length,
          'duration_seconds': 2,
          'sample_rate': 16000,
          'channels': 1,
          'content_type': 'audio/flac',
          'download_url': '/api/v1/separation/jobs/flac/files/guitar',
        },
        endpoint,
        'flac',
      );
      final download = store(
        (_) async => response(flac, headers: {'content-type': 'audio/flac'}),
      );
      expect(await (await download.download('flac', s)).readAsBytes(), flac);
      expect(await download.localFile('flac', s), isNotNull);
    },
  );
}

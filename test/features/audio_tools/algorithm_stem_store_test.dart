import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  late Directory directory;
  final endpoint = AlgorithmEndpoint(
    'https://algorithm.example',
    allowLocalHttp: false,
  );
  final wav = syntheticAlgorithmWav();
  final result = LegacySeparationResult.fromJson(separationFixture(), endpoint);
  final stem = result.stems.first;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gp_stems_');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('streams verified files, persists across stores and opens offline after expiry', () async {
    var calls = 0, progress = 0;
    final store = AlgorithmStemStore(
      () async => directory,
      clientFactory: () => MockClient((request) async {
        calls++;
        expect(
          request.url.path,
          '/api/v1/separation/jobs/contract_job_1/files/vocals',
        );
        expect(request.followRedirects, isFalse);
        return http.Response.bytes(
          wav,
          200,
          headers: {'content-type': 'audio/wav'},
        );
      }),
    );
    final file = await store.download(
      'local-job',
      stem,
      onProgress: (n, _) => progress = n,
    );
    expect(progress, wav.length);
    expect(await file.readAsBytes(), wav);
    expect(await store.download('local-job', stem), isA<File>());
    expect(calls, 1);
    final offline = AlgorithmStemStore(
      () async => directory,
      clientFactory: () => throw StateError('offline'),
    );
    final expiredStem = LegacySeparationResult.fromJson(
      separationFixture(expires: '2000-01-01T00:00:00Z'),
      endpoint,
    ).stems.first;
    expect(await offline.localFile('local-job', expiredStem), isNotNull);
    await offline.deleteTask('local-job');
    expect(await directory.list().toList(), isEmpty);
  });

  test('rejects redirects, missing files, wrong type, short body and bogus audio without publishing cache', () async {
    for (final response in [
      http.Response(
        '',
        302,
        headers: {'location': 'https://other.example/private'},
      ),
      http.Response('', 410),
      http.Response.bytes(wav, 200, headers: {'content-type': 'text/html'}),
      http.Response.bytes(
        wav.sublist(0, 80),
        200,
        headers: {'content-type': 'audio/wav'},
      ),
      http.Response.bytes(
        List.filled(wav.length, 0),
        200,
        headers: {'content-type': 'audio/wav'},
      ),
    ]) {
      final store = AlgorithmStemStore(
        () async => directory,
        clientFactory: () => MockClient((_) async => response),
      );
      await expectLater(store.download('local-job', stem), throwsA(anything));
      expect(await store.localFile('local-job', stem), isNull);
      expect(await directory.list().toList(), isEmpty);
    }
  });

  test(
    'concurrent download/delete blocked, interrupted partial is replaced',
    () async {
      final pending = Completer<http.Response>();
      final store = AlgorithmStemStore(
        () async => directory,
        clientFactory: () => MockClient((_) => pending.future),
      );
      final first = store.download('local-job', stem);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await expectLater(store.download('local-job', stem), throwsStateError);
      await expectLater(store.deleteTask('local-job'), throwsStateError);
      pending.complete(
        http.Response.bytes(wav, 200, headers: {'content-type': 'audio/wav'}),
      );
      final file = await first;
      await file.writeAsBytes([0]);
      await File('${file.path}.part').writeAsBytes([1, 2]);
      final retry = AlgorithmStemStore(
        () async => directory,
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes(
            wav,
            200,
            headers: {'content-type': 'audio/wav'},
          ),
        ),
      );
      await retry.download('local-job', stem);
      expect(await file.length(), wav.length);
      expect(await File('${file.path}.part').exists(), isFalse);
      await expectLater(
        store.localFile('../escape', stem),
        throwsFormatException,
      );
    },
  );

  test(
    'separation parser rejects missing tracks and inconsistent duration',
    () {
      final missing = separationFixture();
      (missing['stems'] as List).removeLast();
      expect(
        () => LegacySeparationResult.fromJson(missing, endpoint),
        throwsFormatException,
      );
      final wrong = separationFixture();
      ((wrong['stems'] as List).first as Map)['duration_seconds'] = 4;
      expect(
        () => LegacySeparationResult.fromJson(wrong, endpoint),
        throwsFormatException,
      );
    },
  );
}

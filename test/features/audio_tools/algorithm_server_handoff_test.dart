import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/separation_processing_info.dart';
import 'package:guitar_pal/features/player/widgets/separation_processing_details.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  final endpoint = AlgorithmEndpoint(
    'https://algorithm.example',
    allowLocalHttp: false,
  );
  test(
    'separation checks its own readiness; chords only use lightweight ping',
    () async {
      final requests = <String>[];
      final api = LegacyAlgorithmApi(
        endpoint,
        client: MockClient((r) async {
          requests.add(r.url.path);
          expect(r.method, 'GET');
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/ping')
                  ? {'ping': 'pong'}
                  : {
                      'status': 'ready',
                      'model_loaded': true,
                      'model_device': 'cuda:0',
                    },
            ),
            200,
          );
        }),
      );
      try {
        await api.ping();
        expect(requests, ['/api/v1/health/ping']);
        requests.clear();
        await api.ping(operation: AlgorithmOperation.separation);
        expect(requests, ['/api/v1/health/ping', '/api/v1/separation/health']);
      } finally {
        api.close();
      }
    },
  );

  for (final code in [200, 503]) {
    test(
      'unavailable separation is rejected even when general ping works (HTTP $code)',
      () async {
        final api = LegacyAlgorithmApi(
          endpoint,
          client: MockClient(
            (r) async => r.url.path.endsWith('/ping')
                ? http.Response('{"ping":"pong"}', 200)
                : http.Response(
                    '{"status":"unavailable","model_loaded":false,"error":"CUDA unavailable"}',
                    code,
                  ),
          ),
        );
        try {
          await expectLater(
            api.ping(operation: AlgorithmOperation.separation),
            throwsA(
              isA<AlgorithmApiError>().having(
                (e) => e.code,
                'code',
                'model_unavailable',
              ),
            ),
          );
        } finally {
          api.close();
        }
      },
    );
  }
  test(
    'only missing optional readiness route falls back to legacy ping',
    () async {
      for (final code in [404, 401, 502]) {
        final api = LegacyAlgorithmApi(
          endpoint,
          client: MockClient(
            (r) async => r.url.path.endsWith('/ping')
                ? http.Response('{"ping":"pong"}', 200)
                : http.Response('{"detail":"unavailable"}', code),
          ),
        );
        try {
          if (code == 404) {
            await api.ping(operation: AlgorithmOperation.separation);
          } else {
            await expectLater(
              api.ping(operation: AlgorithmOperation.separation),
              throwsA(isA<AlgorithmApiError>()),
            );
          }
        } finally {
          api.close();
        }
      }
    },
  );
  test('legacy lazy-loaded model may accept a job; contradictory ready response fails', () async {
    for (final status in ['not_loaded', 'ready']) {
      final api = LegacyAlgorithmApi(
        endpoint,
        client: MockClient(
          (r) async => r.url.path.endsWith('/ping')
              ? http.Response('{"ping":"pong"}', 200)
              : http.Response(
                  jsonEncode({'status': status, 'model_loaded': false}),
                  200,
                ),
        ),
      );
      try {
        if (status == 'not_loaded') {
          await api.ping(operation: AlgorithmOperation.separation);
        } else {
          await expectLater(
            api.ping(operation: AlgorithmOperation.separation),
            throwsFormatException,
          );
        }
      } finally {
        api.close();
      }
    }
  });
  test('server stages localize without inventing percentage and preserve chord messages', () {
    for (final entry in {
      'decoding': '正在准备音频',
      'loading_model': '正在准备分轨模型',
      'separating': '正在分离音轨',
      'writing_outputs': '正在保存并校验分轨结果',
      'future_stage': '服务器正在处理分轨',
    }.entries) {
      final status = LegacyAlgorithmStatus.fromJson({
        'job_id': 'job',
        'status': 'processing',
        'stage': entry.key,
        'message': 'backend text',
        'progress': null,
        'error': null,
      }, AlgorithmOperation.separation);
      expect(status.displayMessage(AlgorithmOperation.separation), entry.value);
      expect(status.progress, isNull);
      expect(status.displayMessage(AlgorithmOperation.chords), 'backend text');
    }
  });
  test(
    'optional diagnostics never invalidate otherwise valid audio results',
    () {
      for (final value in [
        null,
        'future format',
        {
          'queue_ms': -1,
          'inference_ms': double.infinity,
          'worker_total_ms': 'slow',
          'device': 'arbitrary host',
        },
      ]) {
        final json = separationFixture()..['diagnostics'] = value;
        expect(
          LegacySeparationResult.fromJson(json, endpoint).processing,
          isNull,
        );
      }
      final result = separationFixture()
        ..addAll({
          'processing_time_seconds': 3.5,
          'diagnostics': {
            'queue_ms': 200,
            'inference_ms': 1500.25,
            'encode_ms': 50,
            'device': 'cuda:0',
          },
        });
      final info = LegacySeparationResult.fromJson(
        result,
        endpoint,
      ).processing!;
      expect(info.queue, const Duration(milliseconds: 200));
      expect(info.inference, const Duration(microseconds: 1500250));
      expect(info.processing, const Duration(milliseconds: 3500));
      expect(info.gpu, isTrue);
    },
  );
  test('optional checksums accept legacy results and reject malformed integrity claims', () {
    final json = separationFixture();
    final entry = (json['stems'] as List).first as Map;
    expect(
      LegacySeparationResult.fromJson(json, endpoint).stems.first.sha256,
      isNull,
    );
    entry['sha256'] = 'A' * 64;
    expect(
      LegacySeparationResult.fromJson(json, endpoint).stems.first.sha256,
      'a' * 64,
    );
    for (final bad in ['', 42, 'g' * 64, 'a' * 63]) {
      entry['sha256'] = bad;
      expect(
        () => LegacySeparationResult.fromJson(json, endpoint),
        throwsFormatException,
      );
    }
  });
  testWidgets(
    'processing details disclose recorded timings on demand without download ETA',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SeparationProcessingDetails(
              info: SeparationProcessingInfo(
                queue: Duration(seconds: 2),
                inference: Duration(milliseconds: 1500),
                processing: Duration(seconds: 3),
                gpu: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('分离音轨'), findsNothing);
      await tester.tap(find.text('服务器处理详情'));
      await tester.pumpAndSettle();
      expect(find.text('排队等待'), findsOneWidget);
      expect(find.text('2.00 秒'), findsOneWidget);
      expect(find.text('1.50 秒'), findsOneWidget);
      expect(
        find.text('GPU 加速'),
        findsNothing,
      ); // Mode is presented as one sentence.
      expect(find.text('处理方式：GPU 加速'), findsOneWidget);
      expect(find.textContaining('上传、下载和本机载入另行计算'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}

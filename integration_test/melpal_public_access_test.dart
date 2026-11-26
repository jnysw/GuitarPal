import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_access_screen.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_access.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_service_configuration.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android verifies a guest session without a credential form and saves it in secure storage',
    (tester) async {
      const storage = FlutterSecureStorage();
      final keys = [AlgorithmAccess.key, AlgorithmAccess.guestKey];
      final previous = {
        for (final key in keys) key: await storage.read(key: key),
      };
      final raw = http.Client();
      try {
        expect(
          await const AlgorithmServiceConfiguration().load(),
          melpalAlgorithmOrigin,
        );
        const live = bool.fromEnvironment('CHECK_MELPAL_GUEST_LIVE');
        if (live) {
          final health = await raw
              .get(Uri.parse('$melpalAlgorithmOrigin/health'))
              .timeout(const Duration(seconds: 15));
          expect(health.statusCode, 200);
          final data = jsonDecode(health.body) as Map;
          expect(data['guest_access'], isTrue);
          final denied = await raw
              .get(
                Uri.parse(
                  '$melpalAlgorithmOrigin/api/v1/jobs/${'0' * 32}/status',
                ),
              )
              .timeout(const Duration(seconds: 15));
          expect(denied.statusCode, 401);
        }
        for (final key in keys) {
          await storage.delete(key: key);
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              if (!live)
                algorithmApiFactoryProvider.overrideWithValue(
                  (endpoint) => LegacyAlgorithmApi(
                    endpoint,
                    client: MockClient((request) async {
                      expect(request.method, 'GET');
                      if (request.url.path == '/health') {
                        expect(request.headers['Authorization'], isNull);
                        return http.Response(
                          '{"status":"ok","service":"melpal-algorithm-api","guest_access":true}',
                          200,
                        );
                      }
                      expect(
                        request.headers['Authorization'],
                        'Bearer ${await storage.read(key: AlgorithmAccess.guestKey)}',
                      );
                      return http.Response('{"error":"job_not_found"}', 404);
                    }),
                  ),
                ),
            ],
            child: const MaterialApp(home: AlgorithmAccessScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byKey(const Key('algorithm_access_verify')));
        await tester.pumpAndSettle();
        expect(find.text('连接正常，可回到练习页开始和弦分析或分轨'), findsOneWidget);
        final guest = await storage.read(key: AlgorithmAccess.guestKey);
        expect(
          guest != null && RegExp(r'^mg_[0-9a-f]{64}$').hasMatch(guest),
          isTrue,
        );
        expect(await storage.read(key: AlgorithmAccess.key), isNull);
        expect(tester.takeException(), isNull);
      } finally {
        raw.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        for (final entry in previous.entries) {
          if (entry.value case final value?) {
            await storage.write(key: entry.key, value: value);
          } else {
            await storage.delete(key: entry.key);
          }
        }
      }
    },
  );
}

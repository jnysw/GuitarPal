import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_access_screen.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_access.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';

void main() {
  testWidgets(
    'narrow large text saves hidden token, verifies with GET only and clears without showing secret',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final secret = 'mp_${'s' * 43}';
      var requests = 0;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            algorithmApiFactoryProvider.overrideWithValue(
              (endpoint) => LegacyAlgorithmApi(
                endpoint,
                client: MockClient((r) async {
                  requests++;
                  expect(r.method, 'GET');
                  return r.url.path == '/health'
                      ? http.Response(
                          '{"status":"ok","service":"melpal-algorithm-api"}',
                          200,
                        )
                      : http.Response('{"error":"not_found"}', 404);
                }),
              ),
            ),
          ],
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const AlgorithmAccessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('algorithm_access_input')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('algorithm_access_input')),
        secret,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('algorithm_access_input')))
            .obscureText,
        isTrue,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tap(tester, 'algorithm_access_save');
      expect(await const AlgorithmAccess().configured(), isTrue);
      expect(find.text(secret), findsNothing);
      await _tap(tester, 'algorithm_access_verify');
      expect(requests, 2);
      await tester.scrollUntilVisible(
        find.text('公网连接与内测凭据检查通过，可返回练习进行分析'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('公网连接与内测凭据检查通过，可返回练习进行分析'), findsOneWidget);
      await _tap(tester, 'algorithm_access_clear');
      expect(await const AlgorithmAccess().configured(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

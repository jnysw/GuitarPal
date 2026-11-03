import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_access_screen.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_access.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_service_configuration.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'ordinary Android configuration reaches public HTTPS and keystore credential UI handles 401 without POST',
    (tester) async {
      const storage = FlutterSecureStorage();
      const access = AlgorithmAccess();
      // Never print or copy a pre-existing secret into a fixture or file.
      final previous = await storage.read(key: AlgorithmAccess.key);
      final raw = http.Client();
      try {
        expect(
          await const AlgorithmServiceConfiguration().load(),
          melpalAlgorithmOrigin,
        );
        final health = await raw
            .get(Uri.parse('$melpalAlgorithmOrigin/health'))
            .timeout(const Duration(seconds: 15));
        expect(health.statusCode, 200);
        expect(
          (jsonDecode(health.body) as Map)['service'],
          'melpal-algorithm-api',
        );
        final denied = await raw
            .get(
              Uri.parse(
                '$melpalAlgorithmOrigin/api/v1/jobs/${'0' * 32}/status',
              ),
            )
            .timeout(const Duration(seconds: 15));
        expect(denied.statusCode, 401);
        await access.clear();
        final api = LegacyAlgorithmApi(
          AlgorithmEndpoint(melpalAlgorithmOrigin, allowLocalHttp: false),
        );
        try {
          await expectLater(
            api.ping(),
            throwsA(
              isA<AlgorithmApiError>().having(
                (e) => e.code,
                'local auth gate',
                'authorization_required',
              ),
            ),
          );
        } finally {
          api.close();
        }
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: AlgorithmAccessScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('algorithm_access_input')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        // Deliberately invalid, non-secret token exercises the real 401 route.
        await tester.enterText(
          find.byKey(const Key('algorithm_access_input')),
          'mp_${'invalid'.padRight(43, 'x')}',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _tap(tester, 'algorithm_access_save');
        expect(await access.configured(), isTrue);
        expect(await const AlgorithmAccess().configured(), isTrue);
        await _tap(tester, 'algorithm_access_verify');
        await _until(
          tester,
          () => find.textContaining('内测凭据已过期、被撤销或无效').evaluate().isNotEmpty,
        );
        await _tap(tester, 'algorithm_access_clear');
        expect(await access.configured(), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        raw.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (previous == null) {
          await storage.delete(key: AlgorithmAccess.key);
        } else {
          await storage.write(key: AlgorithmAccess.key, value: previous);
        }
      }
    },
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  for (
    var i = 0;
    i < 80 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Public credential response did not arrive');
}

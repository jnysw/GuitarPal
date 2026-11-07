import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_configuration.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

import '../test/support/algorithm_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const platform = AlgorithmStemPlatform();
  testWidgets('Android private stem playback, seek, pause and path isolation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Stem playback integration')),
      ),
    );
    final directory = await platform.directory();
    final file = File('${directory.path}/integration_native_guitar.wav');
    await file.writeAsBytes(syntheticAlgorithmWav());
    try {
      await platform.play(file.path, Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      var state = await platform.snapshot();
      expect(state['isPlaying'], isTrue);
      expect(state['durationMs'], inInclusiveRange(7900, 8100));
      await platform.seek(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      state = await platform.snapshot();
      expect(state['positionMs'], greaterThanOrEqualTo(2900));
      await platform.pause();
      expect((await platform.snapshot())['isPlaying'], isFalse);
      await expectLater(
        platform.play('/sdcard/invalid.wav', Duration.zero),
        throwsA(isA<PlatformException>()),
      );
      await platform.stop();
      expect((await platform.snapshot())['durationMs'], 0);
    } finally {
      await platform.stop();
      await file.delete();
    }
  });

  const job = String.fromEnvironment('SMOKE_SEPARATION_JOB');
  testWidgets(
    'Flutter HTTPS client downloads a real Windows guitar stem and plays it locally',
    (tester) async {
      final api = LegacyAlgorithmApi(
        AlgorithmEndpoint(
          AlgorithmConfiguration.baseUrl,
          allowLocalHttp: false,
        ),
      );
      final store = AlgorithmStemStore(platform.directory);
      try {
        await api.ping();
        final status = await api.status(job, AlgorithmOperation.separation);
        expect(status.state, LegacyJobState.completed);
        final result = LegacySeparationResult.fromJson(
          await api.result(job, AlgorithmOperation.separation),
          api.endpoint,
        );
        final guitar = result.stems.firstWhere((s) => s.id == 'guitar');
        final file = await store.download('integration-live', guitar);
        expect(await file.length(), guitar.sizeBytes);
        await platform.play(file.path, Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect((await platform.snapshot())['isPlaying'], isTrue);
        await platform.seek(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(
          (await platform.snapshot())['positionMs'],
          greaterThanOrEqualTo(1900),
        );
      } finally {
        api.close();
        await platform.stop();
        await store.deleteTask('integration-live');
      }
    },
    skip: job.isEmpty || AlgorithmConfiguration.baseUrl.isEmpty,
  );
}

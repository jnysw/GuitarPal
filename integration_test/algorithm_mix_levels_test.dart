import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';

import '../test/support/algorithm_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'hardware-head levels reflect gains, pan, silence, pause and seek epochs',
    (tester) async {
      const player = AlgorithmMixPlatform();
      final root = await const AlgorithmStemPlatform().directory();
      final file = File('${root.path}/integration_stage_levels.wav');
      await file.writeAsBytes(syntheticAlgorithmWav());
      final events = <Map<String, Object?>>[];
      final sub = player.levels.listen(events.add);
      try {
        await player.load({'actual_model_track': file.path});
        await player.configureTracks(
          {'actual_model_track': const StemMixControl()},
          master: .6,
          speed: 1,
        );
        final initial = await player.snapshot();
        expect(initial['leftRms'], 0);
        expect(initial['rightRms'], 0);
        await player.play();
        final sounding = await _until(
          player,
          (s) => (s['leftRms'] as num) > .01 && (s['positionMs'] as num) > 200,
        );
        final left = sounding['leftRms'] as num,
            right = sounding['rightRms'] as num;
        expect(left, closeTo(right, .00001));
        expect(sounding['leftPeak'] as num, inInclusiveRange(left, 1));
        await _until(
          player,
          (_) => events.any(
            (e) =>
                e['generation'] == initial['generation'] &&
                (e['leftRms'] as num) > .01,
          ),
        );
        expect(events.last['systemVolume'], inInclusiveRange(0, 1));
        await player.configureTracks(
          {'actual_model_track': const StemMixControl(pan: 1)},
          master: .6,
          speed: 1,
        );
        await _until(
          player,
          (s) => s['leftRms'] == 0 && (s['rightRms'] as num) > .01,
        );
        await player.configureTracks(
          {'actual_model_track': const StemMixControl(pan: 1)},
          master: 0,
          speed: 1,
        );
        await _until(player, (s) => s['leftRms'] == 0 && s['rightRms'] == 0);
        await player.pause();
        expect((await player.snapshot())['rightPeak'], 0);
        final beforeSeek = (await player.snapshot())['epoch'] as num;
        await player.seek(1000);
        final seeked = await player.snapshot();
        expect(seeked['epoch'] as num, greaterThan(beforeSeek));
        expect(seeked['leftRms'], 0);
        expect(seeked['rightRms'], 0);
        await player.configureTracks(
          {'actual_model_track': const StemMixControl()},
          master: .6,
          speed: .73,
        );
        await player.play();
        await _until(
          player,
          (s) => (s['leftRms'] as num) > .01 && (s['positionMs'] as num) > 1100,
        );
        await player.pause();
        final paused = await player.snapshot();
        expect(paused['leftRms'], 0);
        expect(paused['rightRms'], 0);
        expect(paused['error'], isNull);
      } finally {
        await sub.cancel();
        await player.stop();
        await file.delete();
      }
    },
  );
}

Future<Map<String, Object?>> _until(
  AlgorithmMixPlatform player,
  bool Function(Map<String, Object?>) done,
) async {
  Map<String, Object?> value = {};
  for (var i = 0; i < 150; i++) {
    value = await player.snapshot();
    if (done(value)) return value;
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }
  fail('Native meter state did not converge: $value');
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_configuration.dart';

import '../test/support/algorithm_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const player = AlgorithmMixPlatform();
  const stems = AlgorithmStemPlatform();
  const job = String.fromEnvironment('SMOKE_SEPARATION_JOB');
  testWidgets(
    'six real Windows stems share a clock; vocals/backing mode loads independently',
    (tester) async {
      final api = LegacyAlgorithmApi(
        AlgorithmEndpoint(
          AlgorithmConfiguration.baseUrl,
          allowLocalHttp: false,
        ),
      );
      final store = AlgorithmStemStore(stems.directory);
      try {
        final result = LegacySeparationResult.fromJson(
          await api.result(job, AlgorithmOperation.separation),
          api.endpoint,
        );
        final paths = await store.downloadBatch(
          'integration-mix-real',
          result.stems,
        );
        final six = Map<String, String>.from(paths)..remove('instrumental');
        await player.load(six);
        final settings = StemMixSettings(
          speed: .73,
          loop: const StemMixLoop(1000, 1800),
          controls: {'guitar': const StemMixControl(solo: true)},
        );
        await player.configure(settings, six.keys);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        final state = await player.snapshot();
        expect(state['isPlaying'], isTrue);
        expect(state['completedLoops'], greaterThanOrEqualTo(1));
        expect(state['positionMs'], inInclusiveRange(1000, 1799));
        expect(state['gains'], {
          for (final id in six.keys) id: id == 'guitar' ? 1.0 : 0.0,
        });
        await player.load({
          'vocals': paths['vocals']!,
          'instrumental': paths['instrumental']!,
        });
        await player.configure(
          settings.copyWith(
            mode: StemMixMode.vocalsAndBacking,
            clearLoop: true,
          ),
          ['vocals', 'instrumental'],
        );
        final seekMs = (result.duration.inMilliseconds ~/ 2).clamp(0, 2000);
        await player.seek(seekMs);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(
          (await player.snapshot())['positionMs'],
          greaterThanOrEqualTo(seekMs),
        );
      } finally {
        api.close();
        await player.stop();
        await store.deleteTask('integration-mix-real');
      }
    },
    skip: job.isEmpty || AlgorithmConfiguration.baseUrl.isEmpty,
  );
  testWidgets(
    'shared PCM clock, speed, live gains, seek, pause and repeated A-B',
    (tester) async {
      final root = await stems.directory();
      final guitar = File('${root.path}/integration_mix_guitar.wav');
      final vocals = File('${root.path}/integration_mix_vocals.wav');
      await guitar.writeAsBytes(syntheticAlgorithmWav());
      await vocals.writeAsBytes(syntheticAlgorithmWav());
      try {
        await player.load({'guitar': guitar.path, 'vocals': vocals.path});
        var settings = StemMixSettings();
        await player.configure(settings, ['guitar', 'vocals']);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        var snapshot = await player.snapshot();
        expect(snapshot['isPlaying'], isTrue);
        expect(snapshot['positionMs'], greaterThan(100));
        expect(snapshot['durationMs'], 8000);
        settings = settings.copyWith(
          speed: 1.37,
          controls: {'guitar': const StemMixControl(volume: .6, solo: true)},
        );
        await player.configure(settings, ['guitar', 'vocals']);
        snapshot = await player.snapshot();
        expect(snapshot['speed'] as num, closeTo(1.37, .001));
        expect(snapshot['gains'], {'guitar': .6, 'vocals': 0.0});
        await player.seek(3000);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(
          (await player.snapshot())['positionMs'],
          inInclusiveRange(3000, 3900),
        );
        await player.pause();
        final paused = (await player.snapshot())['positionMs'] as int;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(
          (await player.snapshot())['positionMs'],
          inInclusiveRange(paused, paused + 50),
        );
        settings = settings.copyWith(loop: const StemMixLoop(1000, 1500));
        await player.configure(settings, ['guitar', 'vocals']);
        expect((await player.snapshot())['isPlaying'], isFalse);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        snapshot = await player.snapshot();
        expect(snapshot['completedLoops'], greaterThanOrEqualTo(2));
        expect(snapshot['positionMs'], inInclusiveRange(1000, 1499));
        expect(snapshot['error'], isNull);
        await player.configure(settings.copyWith(clearLoop: true, speed: .5), [
          'guitar',
          'vocals',
        ]);
        await player.seek(7900);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        expect((await player.snapshot())['isPlaying'], isFalse);
        await player.stop();
        expect((await player.snapshot())['isLoaded'], isFalse);
      } finally {
        await player.stop();
        await guitar.delete();
        await vocals.delete();
      }
    },
  );

  testWidgets(
    'WAV chunks, incompatible formats, duplicate backing and directory isolation',
    (tester) async {
      final root = await stems.directory();
      final original = syntheticAlgorithmWav();
      final padded = Uint8List(original.length + 10);
      padded.setRange(0, 12, original);
      padded.setRange(12, 16, 'JUNK'.codeUnits);
      ByteData.sublistView(padded).setUint32(16, 1, Endian.little);
      padded.setRange(22, padded.length, original.sublist(12));
      ByteData.sublistView(padded)
          .setUint32(4, padded.length - 8, Endian.little);
      final file = File('${root.path}/integration_mix_padded.wav');
      final other = File('${root.path}/integration_mix_other.wav');
      await file.writeAsBytes(padded);
      final wrongRate = Uint8List.fromList(original);
      final data = ByteData.sublistView(wrongRate);
      data.setUint32(24, 22050, Endian.little);
      data.setUint32(28, 44100, Endian.little);
      await other.writeAsBytes(wrongRate);
      try {
        await player.load({'guitar': file.path});
        expect((await player.snapshot())['durationMs'], 8000);
        await expectLater(
          player.load({'guitar': file.path, 'vocals': other.path}),
          throwsA(isA<PlatformException>()),
        );
        await expectLater(
          player.load({'guitar': file.path, 'instrumental': file.path}),
          throwsA(isA<PlatformException>()),
        );
        await expectLater(
          player.load({'guitar': '/sdcard/not-private.wav'}),
          throwsA(isA<PlatformException>()),
        );
        final invalid = Uint8List.fromList(original)
          ..[20] = 3; // IEEE float is deliberately unsupported.
        await other.writeAsBytes(invalid);
        await expectLater(
          player.load({'guitar': other.path}),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        await player.stop();
        await file.delete();
        await other.delete();
      }
    },
  );
}

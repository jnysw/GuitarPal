import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';

void main() {
  test('modes prevent backing duplication; only loaded solo tracks affect audible gains', () {
    var settings = StemMixSettings(
      controls: {
        'guitar': const StemMixControl(volume: .65, solo: true),
        'vocals': const StemMixControl(volume: .5),
        'piano': const StemMixControl(solo: true, muted: true),
      },
    );
    expect(settings.effectiveGains(['guitar', 'vocals']), {
      'guitar': .65,
      'vocals': 0,
    });
    expect(settings.effectiveGains(['vocals']), {'vocals': .5});
    expect(
      () => settings.effectiveGains(['guitar', 'instrumental']),
      throwsFormatException,
    );
    settings = settings.copyWith(mode: StemMixMode.vocalsAndBacking);
    expect(settings.effectiveGains(['vocals', 'instrumental']), {
      'vocals': .5,
      'instrumental': 1,
    });
    expect(
      () => settings.effectiveGains(['vocals', 'guitar']),
      throwsFormatException,
    );
    expect(
      () => settings.effectiveGains(['vocals', 'vocals']),
      throwsFormatException,
    );
  });

  test('saved settings validate loop limits, speed, volume, schema and track identity', () {
    final original = StemMixSettings(
      speed: 1.37,
      loop: const StemMixLoop(1250, 3750),
      master: .7,
    );
    final restored = StemMixSettings.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      8000,
    );
    expect(restored.speed, 1.37);
    expect(restored.loop!.startMs, 1250);
    expect(restored.loop!.endMs, 3750);
    expect(restored.master, .7);
    for (final change in [
      {'version': 99},
      {'speed': double.nan},
      {'speed': 2.01},
      {'master': -1},
      {'mode': 'unknown'},
      {
        'loop': {'startMs': 0, 'endMs': 249},
      },
      {
        'loop': {'startMs': 0, 'endMs': 8001},
      },
      {
        'controls': {'unknown': {}},
      },
    ]) {
      expect(
        () => StemMixSettings.fromJson({...original.toJson(), ...change}, 8000),
        throwsFormatException,
      );
    }
    expect(original.copyWith(clearLoop: true).loop, isNull);
  });

  test('preferences persist atomically, reject corrupt files and are removed with task downloads', () async {
    final directory = await Directory.systemTemp.createTemp('gp_mix_prefs_');
    final preferences = StemMixPreferences(() async => directory);
    try {
      expect(await preferences.load('task-a', 8000), isNull);
      final settings = StemMixSettings(
        speed: .73,
        loop: const StemMixLoop(500, 2500),
      );
      await preferences.save('task-a', settings);
      expect((await preferences.load('task-a', 8000))!.speed, .73);
      expect(
        await File('${directory.path}/task-a_mix.json.part').exists(),
        isFalse,
      );
      await expectLater(
        preferences.load('../escape', 8000),
        throwsFormatException,
      );
      await File('${directory.path}/task-a_mix.json').writeAsString('{broken');
      await expectLater(
        preferences.load('task-a', 8000),
        throwsFormatException,
      );
      await AlgorithmStemStore(() async => directory).deleteTask('task-a');
      expect(await directory.list().toList(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

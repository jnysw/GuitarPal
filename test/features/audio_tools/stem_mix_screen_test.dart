import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/stem_mix_screen.dart';
import 'package:guitar_pal/features/player/widgets/precise_playback_speed_control.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  testWidgets(
    'shared controls, exact speed, loop editor, modes and saved settings',
    (tester) async {
      final player = _Mix();
      final preferences = _Preferences();
      final result = LegacySeparationResult.fromJson(
        separationFixture(),
        AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            algorithmMixPlatformProvider.overrideWithValue(player),
            algorithmStemStoreProvider.overrideWithValue(_Files()),
            stemMixPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(
            home: StemMixScreen(taskId: 'task', title: '练习音频', result: result),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(player.paths.keys, unorderedEquals(['vocals', 'guitar']));
      expect(player.paths.keys, isNot(contains('instrumental')));
      await tester.tap(find.byKey(const Key('mix_play')));
      await tester.pump();
      expect(player.playing, isTrue);
      await tester.tap(find.byKey(const Key('mix_play')));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);

      await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PrecisePlaybackSpeedControlKeys.input),
        '1.37',
      );
      await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
      await tester.pumpAndSettle();
      expect(player.settings.speed, 1.37);
      await tester.scrollUntilVisible(
        find.text('输入时间'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('输入时间'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '1.250');
      await tester.enterText(fields.at(1), '1.400');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.textContaining('至少 0.25 秒'), findsOneWidget);
      await tester.enterText(fields.at(1), '2.500');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(player.settings.loop!.startMs, 1250);
      expect(player.settings.loop!.endMs, 2500);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mix_solo_guitar')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('mix_solo_guitar')));
      await tester.pumpAndSettle();
      expect(player.settings.effectiveGains(player.paths.keys), {
        'guitar': 1,
        'vocals': 0,
      });
      await tester.tap(find.byKey(const ValueKey('mix_mute_guitar')));
      await tester.pumpAndSettle();
      expect(player.settings.effectiveGains(player.paths.keys), {
        'guitar': 0,
        'vocals': 0,
      });
      await tester.scrollUntilVisible(
        find.text('保存练习设置'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('保存练习设置'));
      await tester.pumpAndSettle();
      expect(preferences.saved!.speed, 1.37);
      expect(preferences.saved!.controls['guitar']!.muted, isTrue);
      await tester.scrollUntilVisible(
        find.text('人声＋伴奏'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('人声＋伴奏'));
      await tester.pumpAndSettle();
      expect(player.paths.keys, unorderedEquals(['vocals', 'instrumental']));
      expect(player.settings.mode, StemMixMode.vocalsAndBacking);
      expect(player.playing, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(player.stops, greaterThan(0));
    },
  );
}

class _Files extends AlgorithmStemStore {
  _Files() : super(() async => Directory.systemTemp);
  @override
  Future<File?> localFile(String taskId, LegacyStemFile stem) async =>
      {'vocals', 'guitar', 'instrumental'}.contains(stem.id)
      ? File('/app/algorithm_stems/${stem.id}.wav')
      : null;
}

class _Preferences extends StemMixPreferences {
  _Preferences() : super(() async => Directory.systemTemp);
  StemMixSettings? saved;
  @override
  Future<StemMixSettings?> load(String taskId, int durationMs) async => saved;
  @override
  Future<void> save(String taskId, StemMixSettings settings) async {
    saved = settings;
  }
}

class _Mix extends AlgorithmMixPlatform {
  Map<String, String> paths = {};
  StemMixSettings settings = StemMixSettings();
  bool playing = false;
  int position = 0, stops = 0;
  @override
  Future<void> load(Map<String, String> paths) async {
    this.paths = paths;
    playing = false;
    position = 0;
  }

  @override
  Future<void> configure(
    StemMixSettings settings,
    Iterable<String> loadedIds,
  ) async {
    this.settings = settings;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
    stops++;
  }

  @override
  Future<void> seek(int positionMs) async {
    position = positionMs;
  }

  @override
  Future<Map<String, Object?>> snapshot() async => {
    'isLoaded': true,
    'isPlaying': playing,
    'positionMs': position,
    'durationMs': 8000,
    'completedLoops': 0,
    'error': null,
  };
}

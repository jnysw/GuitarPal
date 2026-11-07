import 'dart:io';

import 'package:drift/native.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';

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
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/stem_practice_target_repository.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/plans/application/practice_session_service.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_session_repository.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  testWidgets(
    'shared controls, exact speed, loop editor, modes and saved settings',
    (tester) async {
      final player = _Mix();
      final database = AppDatabase(NativeDatabase.memory());
      final preferences = _Preferences();
      final result = LegacySeparationResult.fromJson(
        separationFixture(),
        AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
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

      await tester.ensureVisible(
        find.byKey(PrecisePlaybackSpeedControlKeys.exactValue),
      );
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
      await tester.pumpAndSettle();
      await database.close();
      expect(player.stops, greaterThan(0));
    },
  );
  testWidgets(
    'linked playback, mode reset, background and back produce one finalized practice session',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final player = _Mix();
      var now = DateTime(2026, 10, 28, 12);
      final result = LegacySeparationResult.fromJson(
        separationFixture(),
        AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
      );
      await tester.runAsync(() async {
        await database
            .into(database.practiceSources)
            .insert(
              PracticeSourcesCompanion.insert(
                id: 'source',
                platform: 'local',
                kind: 'video',
                title: '统计曲目',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await AlgorithmTaskRepository(database).insert(
          AlgorithmTaskRecord(
            id: 'task',
            endpoint: 'https://algorithm.example',
            inputPath: '/test',
            inputName: 'test.wav',
            inputSizeBytes: 100,
            inputDurationMs: 8000,
            ownsInput: false,
            state: AlgorithmTaskState.completed,
            createdAt: now,
            updatedAt: now,
            failures: 0,
          ),
        );
        await StemPracticeTargetRepository(database)
            .link('task', sourceId: 'source');
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            algorithmMixPlatformProvider.overrideWithValue(player),
            algorithmStemStoreProvider.overrideWithValue(_Files()),
            stemMixPreferencesProvider.overrideWithValue(_Preferences()),
            practiceSessionServiceProvider.overrideWithValue(
              PracticeSessionService(
                DriftPracticeSessionRepository(database),
                clock: () => now,
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StemMixScreen(
                        taskId: 'task',
                        title: '练习',
                        result: result,
                      ),
                    ),
                  ),
                  child: const Text('打开练习'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开练习'));
      await tester.pumpAndSettle();
      expect(find.textContaining('统计归属：统计曲目'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mix_play')));
      await tester.pump();
      now = now.add(const Duration(seconds: 3));
      player.loops = 2;
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.byKey(const Key('mix_play')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('人声＋伴奏'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mix_play')));
      await tester.pump();
      now = now.add(const Duration(seconds: 2));
      player.loops = 1;
      await tester.pump(const Duration(milliseconds: 120));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      now = now.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('打开练习'), findsOneWidget);
      final rows = (await tester.runAsync(
        () => database.select(database.practiceSessions).get(),
      ))!;
      expect(rows, hasLength(1));
      expect(rows.single.activeDurationMilliseconds, 5000);
      expect(rows.single.loopCount, 3);
      expect(rows.single.completed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
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
  int position = 0, stops = 0, loops = 0;
  @override
  Future<void> load(Map<String, String> paths) async {
    this.paths = paths;
    playing = false;
    position = 0;
    loops = 0;
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
    'completedLoops': loops,
    'error': null,
  };
}

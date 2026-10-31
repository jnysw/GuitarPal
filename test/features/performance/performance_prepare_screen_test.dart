import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/performance/data/backing_preset_store.dart';
import 'package:guitar_pal/features/performance/performance_providers.dart';
import 'package:guitar_pal/features/performance/performance_prepare_screen.dart';

import 'performance_backing_test.dart' show fixtureCandidate;

void main() {
  testWidgets(
    'prepare, preview and save guitar-free backing separately then restore it without practice statistics',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      try {
        await tester.pumpWidget(f.app());
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_prepare'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const Key('performance_omit_guitar')),
              )
              .selected,
          isTrue,
        );
        await tester.tap(find.byKey(const Key('performance_prepare')));
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_preview_play'))
              .evaluate()
              .isNotEmpty,
        );
        expect(f.player.loaded.containsKey('guitar'), isFalse);
        expect(f.player.loaded.containsKey('instrumental'), isFalse);
        expect(f.player.plays, 0);
        await tester.ensureVisible(
          find.byKey(const Key('performance_preview_play')),
        );
        await tester.tap(find.byKey(const Key('performance_preview_play')));
        await tester.pump(const Duration(milliseconds: 200));
        await _until(tester, () => f.player.plays == 1);
        expect(f.player.plays, 1);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_save')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('performance_save')));
        await _until(
          tester,
          () => find.text('伴奏方案已保存，下次可继续使用').evaluate().isNotEmpty,
        );
        final saved = await tester.runAsync(() => f.prefs.load('source'));
        expect(saved!.controls.containsKey('guitar'), isFalse);
        expect(
          await tester.runAsync(
            () =>
                File('${f.root.path}/video_workspace/source.json')
                    .readAsString(),
          ),
          'original mix unchanged',
        );
        expect(
          await tester.runAsync(
            () => f.database.select(f.database.practiceSessions).get(),
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(f.player.playing, isFalse);
        await tester.pumpWidget(f.app());
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_prepare'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          tester
              .widget<FilterChip>(
                find.byKey(const Key('performance_omit_guitar')),
              )
              .selected,
          isTrue,
        );
        expect(find.byKey(const Key('performance_preview_play')), findsNothing);
        expect(f.player.plays, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'changed local file is excluded and narrow large text has a useful empty state',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.runAsync(
          () =>
              File(f.source.canonicalUri!.toFilePath()).writeAsBytes([1, 2, 3]),
        );
        await tester.pumpWidget(f.app(scale: 2));
        await _until(
          tester,
          () => find.textContaining('还没有可用的分轨结果').evaluate().isNotEmpty,
        );
        expect(find.byKey(const Key('performance_prepare')), findsNothing);
        expect(f.player.loaded, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail(
    'UI not ready: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
  );
}

class _Fixture {
  _Fixture(this.root, this.database, this.source, this.prefs);
  final Directory root;
  final AppDatabase database;
  final domain.PracticeSource source;
  final BackingPresetStore prefs;
  final player = _Player();
  static Future<_Fixture> create() async {
    final root = Directory.systemTemp.createTempSync('gp_performance_ui_');
    final candidate = fixtureCandidate(root);
    final now = DateTime.now();
    final db = AppDatabase(NativeDatabase.memory());
    final source = domain.PracticeSource(
      id: 'source',
      platform: domain.SourcePlatform.local,
      kind: domain.SourceKind.video,
      title: '我的练习歌',
      canonicalUri: File(candidate.binding.path).uri,
      createdAt: now,
      updatedAt: now,
    );
    await db
        .into(db.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source',
            platform: 'local',
            kind: 'video',
            title: source.title,
            canonicalUrl: Value(source.canonicalUri.toString()),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final repo = AlgorithmTaskRepository(db);
    await repo.insert(candidate.task);
    await repo.update(
      'task',
      AlgorithmTaskState.completed,
      jobId: candidate.task.remoteJobId,
      resultJson: candidate.task.resultJson,
    );
    final old = File('${root.path}/video_workspace/source.json');
    await old.parent.create(recursive: true);
    await old.writeAsString('original mix unchanged');
    return _Fixture(root, db, source, BackingPresetStore(() async => root));
  }

  Widget app({double scale = 1}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      algorithmStemStoreProvider.overrideWithValue(_Store(root)),
      algorithmMixPlatformProvider.overrideWithValue(player),
      backingPresetStoreProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: PerformancePrepareScreen(source: source),
      ),
    ),
  );
  Future<void> close() async {
    await database.close();
    root.deleteSync(recursive: true);
  }
}

class _Store extends AlgorithmStemStore {
  _Store(this.folder) : super(() async => folder);
  final Directory folder;
  @override
  Future<File?> localFile(String taskId, LegacyStemFile stem) async =>
      File('${folder.path}/$taskId-${stem.id}.wav');
}

class _Player extends AlgorithmMixPlatform {
  Map<String, String> loaded = {};
  bool playing = false;
  int plays = 0, position = 0;
  @override
  Future<void> load(Map<String, String> paths) async {
    loaded = Map.of(paths);
  }

  @override
  Future<void> configureTracks(
    Map<String, StemMixControl> controls, {
    required double master,
    required double speed,
  }) async {}
  @override
  Future<void> play() async {
    playing = true;
    plays++;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
    loaded = {};
  }

  @override
  Future<void> seek(int value) async {
    position = value;
  }

  @override
  Future<Map<String, Object?>> snapshot() async => {
    'isLoaded': loaded.isNotEmpty,
    'isPlaying': playing,
    'positionMs': position,
    'durationMs': 8000,
    'completedLoops': 0,
  };
}

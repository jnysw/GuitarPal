import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/performance_comparison_screen.dart';
import 'package:guitar_pal/features/performance/performance_route_observer.dart';
import 'package:guitar_pal/features/performance/performance_take_providers.dart';
import 'package:guitar_pal/features/performance/performance_takes_screen.dart';
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';

import '../test/features/performance/performance_comparison_test.dart'
    show comparisonFixture, comparisonRecording;
import 'support/performance_comparison_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved history selects two takes; real native A/B mapping, pause and return leave audio and statistics unchanged',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final appRoot = (await const AlgorithmStemPlatform().directory()).parent;
      final root = await appRoot.createTemp('comparison-test-');
      final original = comparisonFixture(root);
      final token = DateTime.now().microsecondsSinceEpoch;
      final a = original.first.take.update({
        'id': 'native-comparison-$token-a',
      });
      final b = original.second.take.update({
        'id': 'native-comparison-$token-b',
      });
      final first = comparisonRecording(a, '以前的演奏');
      final second = comparisonRecording(b, '这次的演奏');
      final repo = DriftPracticeRecordingRepository(db);
      await repo.save(first);
      await repo.save(second);
      final files = [
        File('${appRoot.path}/${a.filePath}'),
        File('${appRoot.path}/${b.filePath}'),
      ];
      await files.first.parent.create(recursive: true);
      await files[0].writeAsBytes(base64Decode(comparisonAudioABase64));
      await files[1].writeAsBytes(base64Decode(comparisonAudioBBase64));
      final before = [
        await files[0].readAsBytes(),
        await files[1].readAsBytes(),
      ];
      const audio = MethodChannelPracticeAudioRecorder();
      final router = GoRouter(
        observers: [performanceRouteObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PerformanceTakesScreen(sourceId: a.sourceId),
          ),
          GoRoute(
            path: '/performance/compare',
            builder: (_, state) => PerformanceComparisonRouteScreen(
              ids: (
                sourceId: state.uri.queryParameters['sourceId']!,
                firstId: state.uri.queryParameters['firstId']!,
                secondId: state.uri.queryParameters['secondId']!,
              ),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              performanceTakeStoreProvider.overrideWithValue(
                PerformanceTakeStore(() async => root),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_compare_select'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.tap(find.byKey(const Key('performance_compare_select')));
        await tester.pumpAndSettle();
        for (final id in [a.id, b.id]) {
          await tester.tap(find.byKey(Key('performance_select_$id')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('performance_compare_open')));
        await _until(
          tester,
          () =>
              find.text('播放 A').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect((await audio.playbackSnapshot()).isPlaying, isFalse);
        final slider = tester.widget<Slider>(
          find.byKey(const Key('performance_compare_position')),
        );
        slider.onChanged!(4000);
        slider.onChangeEnd!(4000);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_compare_play')));
        await tester.pumpAndSettle();
        var snap = await audio.playbackSnapshot();
        expect(snap.duration.inMilliseconds, closeTo(6200, 100));
        expect(snap.isPlaying, isTrue);
        expect(snap.position.inMilliseconds, closeTo(2200, 500));
        final beforeSwitch = snap.position.inMilliseconds;
        await tester.tap(find.byKey(const Key('performance_compare_1')));
        await tester.pumpAndSettle();
        snap = await audio.playbackSnapshot();
        expect(snap.duration.inMilliseconds, closeTo(12100, 100));
        expect(snap.isPlaying, isTrue);
        expect(
          snap.position.inMilliseconds,
          closeTo((beforeSwitch - 200) * 2 + 100, 600),
        );
        await tester.tap(find.byKey(const Key('performance_compare_play')));
        await tester.pumpAndSettle();
        expect((await audio.playbackSnapshot()).isPlaying, isFalse);
        await tester.binding.handlePopRoute();
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_compare_select'))
              .evaluate()
              .isNotEmpty,
        );
        expect((await audio.playbackSnapshot()).isLoaded, isFalse);
        expect(await files[0].readAsBytes(), before[0]);
        expect(await files[1].readAsBytes(), before[1]);
        expect((await repo.watchAll().first).length, 2);
        expect(await db.select(db.practiceSessions).get(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await audio.stopPlayback();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        router.dispose();
        await db.close();
        for (final f in files) {
          if (await f.exists()) await f.delete();
        }
        await root.delete(recursive: true);
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Comparison screen not ready');
}

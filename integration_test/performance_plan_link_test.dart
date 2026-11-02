import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/performance_plan_link_screen.dart';
import 'package:guitar_pal/features/performance/performance_review_screen.dart';
import 'package:guitar_pal/features/performance/performance_route_observer.dart';
import 'package:guitar_pal/features/performance/performance_take_providers.dart';
import 'package:guitar_pal/features/performance/performance_takes_screen.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';
import 'package:guitar_pal/features/recordings/presentation/plan_outcome_recordings_screen.dart';

import '../test/features/performance/performance_comparison_test.dart'
    show comparisonFixture, comparisonRecording;
import '../test/features/performance/performance_plan_link_test.dart'
    show linkedPlan;
import 'support/performance_comparison_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved stage audio links from review, survives resaving, plays from plan and detaches without duplicate audio or practice time',
    (tester) async {
      final database = db.AppDatabase(NativeDatabase.memory());
      final appRoot = (await const AlgorithmStemPlatform().directory()).parent;
      final root = await appRoot.createTemp('plan-link-test-');
      final take = comparisonFixture(root).first.take.update({
        'id': 'plan-native-${DateTime.now().microsecondsSinceEpoch}',
      });
      final recording = comparisonRecording(take, '阶段演奏');
      final file = File('${appRoot.path}/${take.filePath}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(base64Decode(comparisonAudioABase64));
      final original = await file.readAsBytes();
      final now = DateTime.now();
      await database
          .into(database.practiceSources)
          .insert(
            db.PracticeSourcesCompanion.insert(
              id: take.sourceId,
              platform: 'local',
              kind: 'video',
              title: '计划联调曲目',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final repository = DriftPracticeRecordingRepository(database);
      await repository.save(recording);
      await DriftPracticePlanRepository(database).save(linkedPlan());
      final router = GoRouter(
        observers: [performanceRouteObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (c, _) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => c.push('/performance/takes'),
                    child: const Text('进入演奏录音'),
                  ),
                  TextButton(
                    onPressed: () => c.push('/outcomes'),
                    child: const Text('进入计划成果'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/performance/takes',
            builder: (_, _) => PerformanceTakesScreen(sourceId: take.sourceId),
          ),
          GoRoute(
            path: '/performance/review',
            builder: (_, state) => PerformanceReviewRouteScreen(
              takeId: state.uri.queryParameters['takeId']!,
            ),
          ),
          GoRoute(
            path: '/performance/plan',
            builder: (_, state) => PerformancePlanLinkScreen(
              recordingId: state.uri.queryParameters['takeId']!,
            ),
          ),
          GoRoute(
            path: '/outcomes',
            builder: (_, _) =>
                const PlanOutcomeRecordingsScreen(planId: 'whole-plan'),
          ),
        ],
      );
      const audio = MethodChannelPracticeAudioRecorder();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(database),
              performanceTakeStoreProvider.overrideWithValue(
                PerformanceTakeStore(() async => root),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('进入演奏录音'));
        await _until(tester, () => find.text('阶段演奏').evaluate().isNotEmpty);
        await tester.tap(find.text('阶段演奏'));
        await _until(
          tester,
          () =>
              find
                  .byKey(const Key('performance_review_play'))
                  .evaluate()
                  .isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await _tap(tester, const Key('performance_review_play'));
        expect((await audio.playbackSnapshot()).isPlaying, isTrue);
        await _tap(tester, const Key('performance_take_link_plan'));
        await _until(
          tester,
          () => find
              .byKey(const ValueKey('performance_link_plan_whole-plan'))
              .evaluate()
              .isNotEmpty,
        );
        expect((await audio.playbackSnapshot()).isPlaying, isFalse);
        await _tap(tester, const ValueKey('performance_link_plan_whole-plan'));
        await _tap(tester, const Key('performance_link_save'));
        await _until(tester, () => find.text('演奏回听').evaluate().isNotEmpty);
        await _tap(tester, const Key('performance_take_save'));
        await _until(
          tester,
          () => find.text('演奏已保存，可以从同曲演奏录音再次回听').evaluate().isNotEmpty,
        );
        expect((await repository.getById(take.id))!.planId, 'whole-plan');
        await tester.binding.handlePopRoute();
        await _until(
          tester,
          () => find.text('同一首歌，不同时间的你').evaluate().isNotEmpty,
        );
        await tester.binding.handlePopRoute();
        await _until(tester, () => find.text('进入计划成果').evaluate().isNotEmpty);
        await tester.tap(find.text('进入计划成果'));
        await _until(
          tester,
          () => find
              .byKey(ValueKey('plan_performance_${take.id}'))
              .evaluate()
              .isNotEmpty,
        );
        await _tap(tester, ValueKey('review_plan_performance_${take.id}'));
        await _until(
          tester,
          () =>
              find
                  .byKey(const Key('performance_review_play'))
                  .evaluate()
                  .isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await _tap(tester, const Key('performance_review_play'));
        expect((await audio.playbackSnapshot()).isPlaying, isTrue);
        await tester.binding.handlePopRoute();
        await _until(
          tester,
          () => find
              .byKey(ValueKey('plan_performance_${take.id}'))
              .evaluate()
              .isNotEmpty,
        );
        expect((await audio.playbackSnapshot()).isLoaded, isFalse);
        await _tap(tester, ValueKey('manage_plan_performance_${take.id}'));
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_link_remove'))
              .evaluate()
              .isNotEmpty,
        );
        await _tap(tester, const Key('performance_link_remove'));
        await _until(tester, () => find.text('成果时间线').evaluate().isNotEmpty);
        expect((await repository.getById(take.id))!.planId, isNull);
        expect(
          (await repository.getById(take.id))!.kind,
          PracticeRecordingKind.performanceTake,
        );
        expect((await repository.watchAll().first).length, 1);
        expect(await file.readAsBytes(), original);
        expect(await database.select(database.practiceSessions).get(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await audio.stopPlayback();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        router.dispose();
        await database.close();
        if (await file.exists()) await file.delete();
        await root.delete(recursive: true);
      }
    },
  );
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Plan linked playback screen not ready');
}

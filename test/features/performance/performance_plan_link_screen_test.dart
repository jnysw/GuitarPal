import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/features/performance/performance_plan_link_screen.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/recordings/presentation/plan_outcome_recordings_screen.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_comparison_test.dart' show comparisonFixture;
import 'performance_plan_link_test.dart' show linkedPlan, linkedSegment;

void main() {
  testWidgets(
    'large text link picker filters songs, explains invalid segment, links once and plan timeline can detach without deleting audio',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(f.app(scale: 2));
        await tester.tap(find.text('关联演奏'));
        await _until(
          tester,
          () => find
              .byKey(const ValueKey('performance_link_plan_whole-plan'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('performance_link_plan_foreign')),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('performance_link_plan_short-plan')),
          150,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ListTile>(
                find.byKey(const ValueKey('performance_link_plan_short-plan')),
              )
              .enabled,
          isFalse,
        );
        expect(find.text('录制区间超出此片段，可选择整曲计划'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('performance_link_plan_whole-plan')),
          -150,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('performance_link_plan_whole-plan')),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_link_save')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_link_save')));
        await _until(tester, () => find.text('查看成果').evaluate().isNotEmpty);
        expect(
          (await tester.runAsync(() => f.recordings.getById(f.recording.id)))!
              .planId,
          'whole-plan',
        );
        await tester.tap(find.text('查看成果'));
        await _until(tester, () => find.text('成果录音').evaluate().isNotEmpty);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('manage_plan_performance_${f.recording.id}')),
          140,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('manage_plan_performance_${f.recording.id}')),
        );
        await _until(tester, () => find.text('关联练习计划').evaluate().isNotEmpty);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_link_remove')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_link_remove')));
        await _until(tester, () => find.text('成果时间线').evaluate().isNotEmpty);
        final saved = (await tester.runAsync(
          () => f.recordings.getById(f.recording.id),
        ))!;
        expect(saved.planId, isNull);
        expect(saved.kind, PracticeRecordingKind.performanceTake);
        expect(f.mic.files, contains(saved.filePath));
        expect(
          await tester.runAsync(
            () => f.database.select(f.database.practiceSessions).get(),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        f.router.dispose();
        var finished = false;
        final closing = f.close().then((_) => finished = true);
        for (var i = 0; i < 100 && !finished; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(finished, isTrue, reason: 'SQLite stream cleanup must complete');
        await closing;
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Plan association screen not ready');
}

class _Fixture {
  _Fixture(this.root, this.database, this.recording);
  final Directory root;
  final db.AppDatabase database;
  final PracticeRecording recording;
  final mic = FakePerformanceMic();
  late final recordings = DriftPracticeRecordingRepository(database);
  late final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, _) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => c.push('/performance/plan'),
                child: const Text('关联演奏'),
              ),
              TextButton(
                onPressed: () => c.push('/outcomes'),
                child: const Text('查看成果'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/performance/plan',
        builder: (_, _) => PerformancePlanLinkScreen(recordingId: recording.id),
      ),
      GoRoute(
        path: '/outcomes',
        builder: (_, _) =>
            const PlanOutcomeRecordingsScreen(planId: 'whole-plan'),
      ),
    ],
  );
  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('gp_plan_link_ui_');
    final database = db.AppDatabase(NativeDatabase.memory());
    final recording = comparisonFixture(root).first.recording;
    final f = _Fixture(root, database, recording);
    f.mic.files.add(recording.filePath);
    final now = DateTime.utc(2026, 11, 1);
    for (final id in ['source', 'other']) {
      await database
          .into(database.practiceSources)
          .insert(
            db.PracticeSourcesCompanion.insert(
              id: id,
              platform: 'local',
              kind: 'video',
              title: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await f.recordings.save(recording);
    final plans = DriftPracticePlanRepository(database);
    await plans.save(linkedPlan());
    await plans.save(linkedPlan(id: 'foreign', sourceId: 'other'));
    await DriftPracticeSegmentRepository(database)
        .save(linkedSegment(start: 3000, end: 5000));
    await plans.save(linkedPlan(id: 'short-plan', segmentId: 'segment'));
    return f;
  }

  Widget app({double scale = 1}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      practiceAudioRecorderProvider.overrideWithValue(mic),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  Future<void> close() async {
    await database.close();
    await root.delete(recursive: true);
  }
}

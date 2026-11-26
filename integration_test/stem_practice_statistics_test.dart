import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_progress.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/stem_mix_screen.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_session_repository.dart';

import '../test/support/algorithm_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native multi-track practice saves once and updates whole-song plan progress',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      const platform = AlgorithmStemPlatform();
      final root = await platform.directory();
      final store = AlgorithmStemStore(platform.directory);
      const taskId = 'integration-statistics';
      final now = DateTime.now();
      final date = CalendarDate.fromDateTime(now);
      try {
        for (final id in ['guitar', 'vocals']) {
          await File('${root.path}/${taskId}_$id.wav')
              .writeAsBytes(syntheticAlgorithmWav());
        }
        await StemMixPreferences(platform.directory)
            .save(taskId, StemMixSettings(loop: const StemMixLoop(500, 1000)));
        await database
            .into(database.practiceSources)
            .insert(
              PracticeSourcesCompanion.insert(
                id: 'source',
                platform: 'local',
                kind: 'video',
                title: '测试曲目',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.practicePlans)
            .insert(
              PracticePlansCompanion.insert(
                id: 'plan',
                name: '测试计划',
                sourceId: 'source',
                goalType: 'duration',
                targetDurationMilliseconds: const drift.Value(1000),
                startDay: date.dayKey,
                endDay: date.addDays(1).dayKey,
                repeatWeekdayMask: 127,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await AlgorithmTaskRepository(database).insert(
          AlgorithmTaskRecord(
            id: taskId,
            endpoint: 'https://algorithm.example',
            inputPath: '/unused',
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
        final result = LegacySeparationResult.fromJson(
          separationFixture(),
          AlgorithmEndpoint('https://algorithm.example', allowLocalHttp: false),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StemMixScreen(
                          taskId: taskId,
                          title: '实际混音计时',
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
        await tester.tap(find.byKey(const Key('mix_link_target')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('测试曲目'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('测试计划'));
        await tester.pumpAndSettle();
        expect(find.textContaining('统计归属：测试曲目 · 测试计划'), findsOneWidget);
        await tester.tap(find.byKey(const Key('mix_play')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        await tester.tap(find.byKey(const Key('mix_play')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('人声＋伴奏'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(
          const Duration(seconds: 1),
        ); // loading/paused time is excluded.
        await tester.tap(find.byKey(const Key('mix_play')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await tester.pageBack();
        await tester.pumpAndSettle();
        final sessions = await DriftPracticeSessionRepository(database)
            .watchAll()
            .first;
        expect(sessions, hasLength(1));
        expect(sessions.single.completed, isTrue);
        expect(
          sessions.single.activeDuration.inMilliseconds,
          inInclusiveRange(1800, 4000),
        );
        expect(sessions.single.loopCount, greaterThanOrEqualTo(3));
        final plan = (await DriftPracticePlanRepository(database)
            .getById('plan'))!;
        expect(
          PracticePlanProgress(plan: plan, sessions: sessions).isComplete,
          isTrue,
        );
        expect(
          (await database.select(database.syncOutboxEntries).get()).where(
            (r) => r.entityType == 'practiceSession',
          ),
          hasLength(1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await store.deleteTask(taskId);
        await database.close();
      }
    },
  );
}

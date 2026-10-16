import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/player/local_video_player_screen.dart';
import 'package:guitar_pal/features/player/practice_player_screen.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

void main() {
  testWidgets('uses the validated plan target and forwards its plan id', (
    tester,
  ) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seed(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: PracticePlayerRouteScreen(
            sourceId: 'source-1',
            segmentId: 'untrusted-segment',
            planId: 'plan-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final player = tester.widget<LocalVideoPlayerScreen>(
      find.byType(LocalVideoPlayerScreen),
    );
    expect(player.planId, 'plan-1');
    expect(player.initialSegment?.id, 'segment-1');

    await _dispose(tester);
  });

  testWidgets('drops a plan id that belongs to another source', (tester) async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seed(database);
    final now = DateTime.now().toUtc();
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-2',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '另一个视频',
        canonicalUri: Uri.file('/missing/two.mp4'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          home: PracticePlayerRouteScreen(
            sourceId: 'source-2',
            planId: 'plan-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final player = tester.widget<LocalVideoPlayerScreen>(
      find.byType(LocalVideoPlayerScreen),
    );
    expect(player.planId, isNull);
    expect(player.initialSegment, isNull);

    await _dispose(tester);
  });
}

Future<void> _seed(db.AppDatabase database) async {
  final now = DateTime.now().toUtc();
  await DriftPracticeSourceRepository(database).save(
    PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      title: '本地练习',
      canonicalUri: Uri.file('/missing/one.mp4'),
      createdAt: now,
      updatedAt: now,
    ),
  );
  await DriftPracticeSegmentRepository(database).save(
    PracticeSegment(
      id: 'segment-1',
      sourceId: 'source-1',
      title: '目标片段',
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 3),
      createdAt: now,
      updatedAt: now,
    ),
  );
  final today = CalendarDate.fromDateTime(DateTime.now());
  await DriftPracticePlanRepository(database).save(
    PracticePlan(
      id: 'plan-1',
      name: '片段计划',
      sourceId: 'source-1',
      segmentId: 'segment-1',
      goal: const PracticeGoal.loops(3),
      startDate: today,
      endDate: today,
      repeatWeekdays: {today.weekday},
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

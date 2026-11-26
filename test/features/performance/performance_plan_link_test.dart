import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/features/performance/application/performance_take_service.dart';
import 'package:guitar_pal/features/performance/data/performance_plan_links.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/domain/performance_plan_link.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';
import 'package:guitar_pal/features/plans/data/drift_practice_plan_repository.dart';
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_comparison_test.dart' show comparisonFixture;

PracticePlan linkedPlan({
  String id = 'whole-plan',
  String sourceId = 'source',
  String? segmentId,
}) => PracticePlan(
  id: id,
  name: segmentId == null ? '整曲演奏计划' : '片段演奏计划',
  sourceId: sourceId,
  segmentId: segmentId,
  goal: const PracticeGoal.loops(5),
  startDate: CalendarDate(2026, 11, 1),
  endDate: CalendarDate(2026, 11, 30),
  repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

PracticeSegment linkedSegment({
  String id = 'segment',
  int start = 1000,
  int end = 9000,
}) => PracticeSegment(
  id: id,
  sourceId: 'source',
  title: '练习片段',
  start: Duration(milliseconds: start),
  end: Duration(milliseconds: end),
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late Directory root;
  late db.AppDatabase database;
  late DriftPracticeRecordingRepository recordings;
  late DriftPracticePlanRepository plans;
  late PerformancePlanLinks links;
  late PracticeRecording recording;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('gp_plan_link_');
    database = db.AppDatabase(NativeDatabase.memory());
    recordings = DriftPracticeRecordingRepository(database);
    plans = DriftPracticePlanRepository(database);
    links = PerformancePlanLinks(database);
    recording = comparisonFixture(root).first.recording
        .copyWith(note: '保留复盘', sessionId: 'original-session');
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
    await recordings.save(recording);
    await plans.save(linkedPlan());
    await DriftPracticeSegmentRepository(database).save(linkedSegment());
    await plans.save(linkedPlan(id: 'segment-plan', segmentId: 'segment'));
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('attach, move, repeat and remove update one row only; no sessions or sync uploads', () async {
    final before = await database.select(database.syncOutboxEntries).get();
    await links.setPlan(recording.id, 'whole-plan');
    await links.setPlan(recording.id, 'whole-plan');
    var saved = (await recordings.getById(recording.id))!;
    expect(saved.planId, 'whole-plan');
    expect(saved.segmentId, isNull);
    await links.setPlan(recording.id, 'segment-plan');
    saved = (await recordings.getById(recording.id))!;
    expect(saved.segmentId, 'segment');
    expect(saved.performanceContextJson, recording.performanceContextJson);
    expect(saved.filePath, recording.filePath);
    expect(saved.recordedAt, recording.recordedAt);
    expect(saved.kind, PracticeRecordingKind.performanceTake);
    expect(saved.sessionId, recording.sessionId);
    expect(saved.note, recording.note);
    await links.setPlan(recording.id, null);
    saved = (await recordings.getById(recording.id))!;
    expect(saved.planId, isNull);
    expect(saved.segmentId, isNull);
    expect((await recordings.watchAll().first).length, 1);
    expect(await database.select(database.practiceSessions).get(), isEmpty);
    final after = await database.select(database.syncOutboxEntries).get();
    expect(
      after.map((r) => '${r.entityId}:${r.revision}'),
      before.map((r) => '${r.entityId}:${r.revision}'),
    );
  });

  test('transaction revalidates selected plan and actual segment bounds; rejects foreign or removed targets without losing existing link', () async {
    await links.setPlan(recording.id, 'whole-plan');
    await plans.save(linkedPlan(id: 'foreign', sourceId: 'other'));
    await expectLater(
      links.setPlan(recording.id, 'foreign'),
      throwsFormatException,
    );
    await expectLater(
      links.setPlan(recording.id, 'missing'),
      throwsFormatException,
    );
    await DriftPracticeSegmentRepository(database)
        .save(linkedSegment(start: 3000, end: 5000));
    await expectLater(
      links.setPlan(recording.id, 'segment-plan'),
      throwsFormatException,
    );
    expect((await recordings.getById(recording.id))!.planId, 'whole-plan');
    await recordings.delete(recording.id);
    await expectLater(
      links.setPlan(recording.id, 'whole-plan'),
      throwsFormatException,
    );
    expect(await recordings.getById(recording.id), isNull);
  });

  test('saving old review snapshot retains newer link, note and session atomically', () async {
    await links.setPlan(recording.id, 'segment-plan');
    final take = savedPerformanceTake(recording).update({'alignmentMs': 70});
    final mic = FakePerformanceMic()..files.add(take.filePath);
    final service = PerformanceTakeService(
      PerformanceTakeStore(() async => root),
      recordings,
      mic,
      FakePerformanceAudio(mic),
    );
    await service.save(take, '新的标题');
    final saved = (await recordings.getById(recording.id))!;
    expect(saved.planId, 'segment-plan');
    expect(saved.segmentId, 'segment');
    expect(saved.note, '保留复盘');
    expect(saved.sessionId, 'original-session');
    expect(saved.title, '新的标题');
    expect(savedPerformanceTake(saved).alignmentMs, 70);
    expect(mic.files, contains(take.filePath));
  });

  test('plan deletion preserves historical association and recording; explicit detach still works', () async {
    await links.setPlan(recording.id, 'whole-plan');
    await plans.delete('whole-plan');
    final saved = (await recordings.getById(recording.id))!;
    expect(saved.planId, 'whole-plan');
    expect(saved.performanceContextJson, recording.performanceContextJson);
    await links.setPlan(recording.id, null);
    expect((await recordings.getById(recording.id))!.planId, isNull);
  });

  test(
    'failed SQLite write retains old association and a retry is idempotent',
    () async {
      await links.setPlan(recording.id, 'whole-plan');
      await database.customStatement(
        '''CREATE TEMP TRIGGER fail_performance_link
      BEFORE UPDATE OF plan_id ON practice_recordings BEGIN
      SELECT RAISE(ABORT, 'test write failure'); END''',
      );
      await expectLater(
        links.setPlan(recording.id, 'segment-plan'),
        throwsA(isA<Exception>()),
      );
      expect((await recordings.getById(recording.id))!.planId, 'whole-plan');
      await database.customStatement('DROP TRIGGER fail_performance_link');
      await links.setPlan(recording.id, 'segment-plan');
      await links.setPlan(recording.id, 'segment-plan');
      expect((await recordings.getById(recording.id))!.planId, 'segment-plan');
      expect((await recordings.watchAll().first).length, 1);
    },
  );

  test('snapshot identity, trial, missing actual range and segment identity are validated', () async {
    expect(
      () => savedPerformanceTake(
        recording.copyWith(duration: const Duration(seconds: 1)),
      ),
      throwsFormatException,
    );
    final take = savedPerformanceTake(recording);
    expect(
      performancePlanLinkIssue(
        take.update({'endSourceMs': take.preset.startMs}),
        linkedPlan(),
        null,
      ),
      isNotNull,
    );
    expect(
      performancePlanLinkIssue(
        take,
        linkedPlan(segmentId: 'segment'),
        linkedSegment(id: 'wrong'),
      ),
      isNotNull,
    );
    final trial = take.update({'trial': true});
    await recordings.save(
      recording.copyWith(performanceContextJson: _json(trial)),
    );
    await expectLater(
      links.setPlan(recording.id, 'whole-plan'),
      throwsFormatException,
    );
  });
}

String _json(PerformanceTake t) => jsonEncode(t.toJson());

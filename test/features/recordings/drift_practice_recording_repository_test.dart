import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart'
    as domain;
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';

void main() {
  late AppDatabase database;
  late DriftPracticeRecordingRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftPracticeRecordingRepository(database);
  });

  tearDown(() => database.close());

  test('saves, watches, updates, and deletes source recordings', () async {
    final recording = _recording(id: 'take-1', recordedHour: 9);
    final newer = _recording(id: 'take-2', recordedHour: 10);

    await repository.save(recording);
    await repository.save(newer);

    final values = await repository.watchBySource('source-1').first;
    expect(values.map((value) => value.id), ['take-2', 'take-1']);
    expect(values.first.referenceSpeed, 0.83);

    await repository.save(newer.copyWith(title: '保留为成果候选', note: '节奏稳定'));
    expect((await repository.getById('take-2'))?.title, '保留为成果候选');
    expect((await repository.getById('take-2'))?.note, '节奏稳定');

    await repository.delete('take-1');
    expect(await repository.getById('take-1'), isNull);
  });

  test('keeps a plan outcome snapshot after its plan is deleted', () async {
    final now = DateTime.utc(2026, 10, 14, 10);
    await database
        .into(database.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source-1',
            platform: 'local',
            kind: 'video',
            title: '成果练习',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.practicePlans)
        .insert(
          PracticePlansCompanion.insert(
            id: 'plan-1',
            name: '主歌成果',
            sourceId: 'source-1',
            goalType: 'loops',
            targetLoops: const Value(5),
            startDay: 20261014,
            endDay: 20261031,
            repeatWeekdayMask: 0x7f,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final outcome = domain.PracticeRecording(
      id: 'outcome-1',
      sourceId: 'source-1',
      planId: 'plan-1',
      kind: domain.PracticeRecordingKind.planOutcome,
      filePath: 'practice_recordings/outcome-1.m4a',
      duration: const Duration(seconds: 10),
      referenceStart: Duration.zero,
      referenceSpeed: 1,
      title: '第一周成果',
      recordedAt: now,
    );
    await repository.save(outcome);

    expect(
      (await repository.watchByPlan('plan-1').first).single.id,
      'outcome-1',
    );
    await (database.delete(
      database.practicePlans,
    )..where((row) => row.id.equals('plan-1'))).go();

    final stored = await repository.getById('outcome-1');
    expect(stored?.planId, 'plan-1');
    expect(stored?.kind, domain.PracticeRecordingKind.planOutcome);
  });
}

domain.PracticeRecording _recording({
  required String id,
  required int recordedHour,
}) {
  return domain.PracticeRecording(
    id: id,
    sourceId: 'source-1',
    segmentId: 'segment-1',
    kind: domain.PracticeRecordingKind.segmentTake,
    filePath: 'practice_recordings/$id.m4a',
    duration: const Duration(seconds: 8),
    referenceStart: const Duration(seconds: 12),
    referenceEnd: const Duration(seconds: 20),
    referenceSpeed: 0.83,
    title: '片段试录',
    recordedAt: DateTime.utc(2026, 10, 14, recordedHour),
  );
}

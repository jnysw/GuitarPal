import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart'
    hide PracticeRecording;
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/application/performance_take_service.dart';
import 'package:guitar_pal/features/recordings/data/drift_practice_recording_repository.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;

void main() {
  late Directory root;
  late PerformanceTake take;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_take_');
    final c = fixtureCandidate(root);
    take = PerformanceTake.begin(
      'take-1',
      c,
      BackingPreset.forCandidate(c, {'drums', 'bass'}),
      trial: false,
    ).update({'durationMs': 2500, 'endSourceMs': 4500, 'leadMs': 120});
  });
  tearDown(() => root.deleteSync(recursive: true));
  test('immutable snapshot round trip preserves exact preset and rejects unrelated source or invalid times', () {
    final m = take.toJson();
    (m['preset'] as Map)['master'] = .1;
    expect(take.preset.master, .8);
    final round = PerformanceTake.fromJson(
      jsonDecode(jsonEncode(take.toJson())) as Map<String, Object?>,
    );
    expect(round.preset.toJson(), take.preset.toJson());
    expect(round.leadMs, 120);
    expect(round.filePath, 'practice_recordings/take-1.m4a');
    expect(() => round.update({'alignmentMs': 2001}), throwsFormatException);
    expect(() => round.update({'endSourceMs': 12000}), throwsFormatException);
    expect(() => round.update({'id': '../bad'}), throwsFormatException);
    expect(() => round.update({'version': 9}), throwsFormatException);
    expect(
      () => round
          .update({'sourceBytes': 9})
          .verifyCandidate(fixtureCandidate(root)),
      throwsFormatException,
    );
  });
  test('atomic journal survives restart, serialized saves and delete without changing backing preferences', () async {
    final store = PerformanceTakeStore(() async => root);
    await Future.wait([
      store.save(take),
      store.save(take.update({'alignmentMs': 90})),
    ]);
    final restarted = PerformanceTakeStore(() async => root);
    expect((await restarted.load(take.id))!.alignmentMs, 90);
    expect((await restarted.list(take.sourceId)).single.id, take.id);
    expect(await restarted.list('other-source'), isEmpty);
    await store.delete(take.id);
    await expectLater(store.save(take), throwsStateError);
    expect(await restarted.load(take.id), isNull);
  });
  test('save failure retains draft, retry is idempotent and committed audio is not discardable', () async {
    final store = PerformanceTakeStore(() async => root),
        repo = MemoryPerformanceRecordings();
    final mic = FakePerformanceMic()..files.add(take.filePath);
    final service = PerformanceTakeService(
      store,
      repo,
      mic,
      FakePerformanceAudio(mic),
    );
    await store.save(take);
    repo.fail = true;
    await expectLater(service.save(take, '我的演奏'), throwsStateError);
    expect(await store.load(take.id), isNotNull);
    expect(mic.files, contains(take.filePath));
    repo.fail = false;
    await service.save(take, '我的演奏');
    await service.save(take, '我的演奏');
    expect(repo.rows.length, 1);
    expect(repo.rows[take.id]!.kind, PracticeRecordingKind.performanceTake);
    expect(await store.load(take.id), isNull);
    expect((await service.recover(take.id)).leadMs, 120);
    await expectLater(service.discard(take), throwsStateError);
    expect(mic.files, contains(take.filePath));
    await repo.changes.close();
  });
  test('committed interrupted capture recovers from journal and missing file remains explicitly discardable', () async {
    final store = PerformanceTakeStore(() async => root),
        repo = MemoryPerformanceRecordings();
    final mic = FakePerformanceMic()..files.add(take.filePath);
    final service = PerformanceTakeService(
      store,
      repo,
      mic,
      FakePerformanceAudio(mic),
    );
    await store.save(take.update({'durationMs': 0, 'reason': 'capturing'}));
    final recovered = await service.recover(take.id);
    expect(recovered.durationMs, 2000);
    expect(recovered.reason, 'recovered');
    mic.files.clear();
    await expectLater(service.recover(take.id), throwsStateError);
    await service.discard(recovered);
    expect(await store.load(take.id), isNull);
    await repo.changes.close();
  });
  test('v13 recording rows survive v14 nullable context migration and new kind round-trips after reopen', () async {
    final file = File('${root.path}/migration.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    var repo = DriftPracticeRecordingRepository(db);
    final legacy = PracticeRecording(
      id: 'old',
      sourceId: take.sourceId,
      kind: PracticeRecordingKind.segmentTake,
      filePath: 'practice_recordings/old.m4a',
      duration: const Duration(seconds: 3),
      referenceStart: Duration.zero,
      referenceSpeed: 1,
      title: '旧录音',
      recordedAt: DateTime.now(),
    );
    await repo.save(legacy);
    await db.close();
    db = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'ALTER TABLE practice_recordings DROP COLUMN performance_context_json',
          );
          raw.execute('PRAGMA user_version = 13');
        },
      ),
    );
    repo = DriftPracticeRecordingRepository(db);
    expect((await repo.getById('old'))!.performanceContextJson, isNull);
    final mic = FakePerformanceMic()..files.add(take.filePath);
    await PerformanceTakeService(
      PerformanceTakeStore(() async => root),
      repo,
      mic,
      FakePerformanceAudio(mic),
    ).save(take, '新演奏');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    repo = DriftPracticeRecordingRepository(db);
    final rows = await repo.watchAll().first;
    expect(rows.length, 2);
    final saved = rows.singleWhere(
      (r) => r.kind == PracticeRecordingKind.performanceTake,
    );
    expect(
      PerformanceTake.fromJson(
        jsonDecode(saved.performanceContextJson!) as Map<String, Object?>,
      ).preset.manifestHash,
      take.preset.manifestHash,
    );
    expect(rows.singleWhere((r) => r.id == 'old').title, '旧录音');
    await db.close();
  });
}

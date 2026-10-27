import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart'
    as domain;
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/segments/data/drift_practice_segment_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftPracticeSegmentRepository repository;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftPracticeSegmentRepository(database);
    final now = DateTime.utc(2026, 10, 12);
    await DriftPracticeSourceRepository(database).save(
      PracticeSource(
        id: 'source-1',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: 'Blues lesson',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() => database.close());

  test('stores segments and watches them in timeline order', () async {
    final now = DateTime.utc(2026, 10, 12);
    for (final seconds in [20, 5]) {
      await repository.save(
        domain.PracticeSegment(
          id: 'segment-$seconds',
          sourceId: 'source-1',
          title: '片段 $seconds',
          start: Duration(seconds: seconds),
          end: Duration(seconds: seconds + 4),
          note: seconds == 5 ? '保持手腕放松' : null,
          preferredSpeed: seconds == 5 ? 0.75 : 1.25,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final segments = await repository.watchBySource('source-1').first;
    expect(segments.map((segment) => segment.id), ['segment-5', 'segment-20']);
    expect((await repository.watchAll().first).map((segment) => segment.id), [
      'segment-5',
      'segment-20',
    ]);
    expect(segments.first.note, '保持手腕放松');
    expect(segments.first.preferredSpeed, 0.75);
    expect(segments.last.note, isNull);
    expect(segments.last.preferredSpeed, 1.25);
  });

  test('updates note and preferred speed for an existing segment', () async {
    final now = DateTime.utc(2026, 10, 12);
    final original = domain.PracticeSegment(
      id: 'segment-editable',
      sourceId: 'source-1',
      title: '原片段',
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 4),
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(original);

    final updated = original.copyWith(
      title: '新片段',
      note: '弱拍上不要抢拍',
      preferredSpeed: 0.5,
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    await repository.save(updated);

    final stored = await repository.watchBySource('source-1').first;
    expect(stored, hasLength(1));
    expect(stored.single.title, '新片段');
    expect(stored.single.note, '弱拍上不要抢拍');
    expect(stored.single.preferredSpeed, 0.5);
    expect(stored.single.createdAt, now);
    expect(stored.single.updatedAt, now.add(const Duration(minutes: 1)));
  });

  test('deletes the selected segment', () async {
    final now = DateTime.utc(2026, 10, 12);
    await repository.save(
      domain.PracticeSegment(
        id: 'segment-to-delete',
        sourceId: 'source-1',
        title: '待删除',
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 3),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.delete('segment-to-delete');
    expect(await repository.watchBySource('source-1').first, isEmpty);
  });
}

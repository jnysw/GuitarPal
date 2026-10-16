import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';

void main() {
  late db.AppDatabase database;
  late DriftPracticeSourceRepository repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = DriftPracticeSourceRepository(database);
  });

  tearDown(() => database.close());

  test('saves and restores a domain PracticeSource', () async {
    final createdAt = DateTime.utc(2026, 10, 12, 8);
    final source = domain.PracticeSource(
      id: 'source-1',
      platform: domain.SourcePlatform.youtube,
      kind: domain.SourceKind.webReference,
      originalUri: Uri.parse('https://youtu.be/abc?utm_source=share'),
      canonicalUri: Uri.parse('https://youtu.be/abc'),
      externalId: 'abc',
      title: '右手节奏练习',
      thumbnailUri: Uri.parse('https://example.com/cover.jpg'),
      note: '先慢速练习，再逐步提速',
      completedAt: DateTime.utc(2026, 10, 13, 9),
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.save(source);
    final restored = await repository.getById(source.id);

    expect(restored?.platform, domain.SourcePlatform.youtube);
    expect(restored?.canonicalUri, Uri.parse('https://youtu.be/abc'));
    expect(restored?.title, '右手节奏练习');
    expect(restored?.note, '先慢速练习，再逐步提速');
    expect(restored?.thumbnailUri, Uri.parse('https://example.com/cover.jpg'));
    expect(restored?.isCompleted, isTrue);
    expect(restored?.completedAt, DateTime.utc(2026, 10, 13, 9));

    await repository.save(restored!.copyWith(completedAt: null));
    expect((await repository.getById(source.id))?.isCompleted, isFalse);

    await repository.save(restored.copyWith(note: null));
    expect((await repository.getById(source.id))?.note, isNull);
  });

  test('watchAll returns newest sources first', () async {
    for (var index = 0; index < 2; index++) {
      final time = DateTime.utc(2026, 10, 12, index);
      await repository.save(
        domain.PracticeSource(
          id: 'source-$index',
          platform: domain.SourcePlatform.genericWeb,
          kind: domain.SourceKind.webReference,
          title: 'Source $index',
          createdAt: time,
          updatedAt: time,
        ),
      );
    }

    final sources = await repository.watchAll().first;
    expect(sources.map((source) => source.id), ['source-1', 'source-0']);
  });
}

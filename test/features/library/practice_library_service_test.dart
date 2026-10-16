import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/local_video_gateway.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/library/application/practice_library_service.dart';
import 'package:guitar_pal/media/metadata/source_metadata.dart';

void main() {
  late _MemoryRepository repository;
  late PracticeLibraryService service;
  late PracticeSource source;

  setUp(() {
    repository = _MemoryRepository();
    source = PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.webReference,
      title: '旧名称',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    repository.sources.add(source);
    service = PracticeLibraryService(
      repository,
      clock: () => DateTime.utc(2026, 10, 12, 9, 30),
    );
  });

  test('rename trims the title and updates the source timestamp', () async {
    await service.rename(source, '  新的练习名称  ');

    expect(repository.sources.single.title, '新的练习名称');
    expect(
      repository.sources.single.updatedAt,
      DateTime.utc(2026, 10, 12, 9, 30),
    );
  });

  test('rename rejects a blank title', () async {
    expect(
      () => service.rename(source, '   '),
      throwsA(isA<FormatException>()),
    );
  });

  test('recordDuration preserves a newer title from the repository', () async {
    await repository.save(
      source.copyWith(
        title: '已被其他操作重命名',
        updatedAt: DateTime.utc(2026, 10, 12, 8),
      ),
    );

    await service.recordDuration(source, const Duration(minutes: 3));

    expect(repository.sources.single.title, '已被其他操作重命名');
    expect(repository.sources.single.duration, const Duration(minutes: 3));
    expect(
      repository.sources.single.updatedAt,
      DateTime.utc(2026, 10, 12, 9, 30),
    );
  });

  test('recordDuration ignores invalid or deleted sources', () async {
    await service.recordDuration(source, Duration.zero);
    expect(repository.sources.single.duration, isNull);

    repository.sources.clear();
    await service.recordDuration(source, const Duration(minutes: 3));
    expect(repository.sources, isEmpty);
  });

  test('setCompleted marks and reopens the latest source safely', () async {
    await repository.save(
      source.copyWith(
        title: '并发更新后的名称',
        updatedAt: DateTime.utc(2026, 10, 12, 8),
      ),
    );

    await service.setCompleted(source, true);
    expect(repository.sources.single.title, '并发更新后的名称');
    expect(repository.sources.single.isCompleted, isTrue);
    expect(
      repository.sources.single.completedAt,
      DateTime.utc(2026, 10, 12, 9, 30),
    );

    await service.setCompleted(repository.sources.single, false);
    expect(repository.sources.single.isCompleted, isFalse);
    expect(repository.sources.single.completedAt, isNull);
  });

  test('updateNote trims, clears, and preserves concurrent edits', () async {
    await repository.save(
      source.copyWith(
        title: '并发更新后的名称',
        updatedAt: DateTime.utc(2026, 10, 12, 8),
      ),
    );

    await service.updateNote(source, '  保持右手放松\n下次提高 0.05x  ');
    expect(repository.sources.single.title, '并发更新后的名称');
    expect(repository.sources.single.note, '保持右手放松\n下次提高 0.05x');
    expect(
      repository.sources.single.updatedAt,
      DateTime.utc(2026, 10, 12, 9, 30),
    );

    await service.updateNote(repository.sources.single, '   ');
    expect(repository.sources.single.note, isNull);
  });

  test('updateNote rejects notes longer than 4000 characters', () async {
    expect(
      () => service.updateNote(source, List.filled(4001, 'x').join()),
      throwsA(isA<FormatException>()),
    );
  });

  test('refreshMetadata upgrades placeholder title and stores cover', () async {
    final placeholder = PracticeSource(
      id: 'placeholder-source',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.webReference,
      canonicalUri: Uri.parse('https://www.bilibili.com/video/BV1metadata'),
      title: 'Bilibili 练习内容',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    repository.sources.add(placeholder);
    final metadataService = PracticeLibraryService(
      repository,
      metadataLoader: _FakeMetadataLoader(
        SourceMetadata(
          title: '页面里的真实标题',
          thumbnailUri: Uri.parse('https://example.com/cover.jpg'),
        ),
      ),
      clock: () => DateTime.utc(2026, 10, 12, 9, 30),
    );

    expect(await metadataService.refreshMetadata(placeholder), isTrue);
    final refreshed = await repository.getById(placeholder.id);
    expect(refreshed?.title, '页面里的真实标题');
    expect(refreshed?.thumbnailUri, Uri.parse('https://example.com/cover.jpg'));
  });

  test('refreshMetadata preserves a user-selected title', () async {
    final renamed = PracticeSource(
      id: 'renamed-source',
      platform: SourcePlatform.youtube,
      kind: SourceKind.webReference,
      canonicalUri: Uri.parse('https://youtube.com/watch?v=abc'),
      title: '我的名称',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    repository.sources.add(renamed);
    final metadataService = PracticeLibraryService(
      repository,
      metadataLoader: _FakeMetadataLoader(
        SourceMetadata(
          title: '网页名称',
          thumbnailUri: Uri.parse('https://example.com/cover.jpg'),
        ),
      ),
    );

    await metadataService.refreshMetadata(renamed);
    final refreshed = await repository.getById(renamed.id);
    expect(refreshed?.title, '我的名称');
    expect(refreshed?.thumbnailUri, isNotNull);
  });

  test('delete removes the selected source', () async {
    await service.delete(source);
    expect(repository.sources, isEmpty);
  });

  test('delete removes the managed copy for a local video source', () async {
    final gateway = _FakeLocalVideoGateway();
    final localSource = PracticeSource(
      id: 'local-source',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      canonicalUri: Uri.file('/files/guitarpal_videos/local-source.mp4'),
      title: '本地视频',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    repository.sources.add(localSource);
    final localService = PracticeLibraryService(
      repository,
      localVideoGateway: gateway,
    );

    await localService.delete(localSource);

    expect(repository.sources, isNot(contains(localSource)));
    expect(gateway.deletedManagedPaths, [
      '/files/guitarpal_videos/local-source.mp4',
    ]);
  });
}

final class _FakeMetadataLoader implements SourceMetadataLoader {
  const _FakeMetadataLoader(this.metadata);

  final SourceMetadata metadata;

  @override
  Future<SourceMetadata?> load(Uri uri) async => metadata;
}

final class _FakeLocalVideoGateway implements LocalVideoGateway {
  final List<String> deletedManagedPaths = [];

  @override
  Future<LocalVideoFileInfo> commitDraft({
    required String draftPath,
    required String sourceId,
  }) {
    throw UnsupportedError('Not used by this test');
  }

  @override
  Future<void> deleteManagedVideo(String path) async {
    deletedManagedPaths.add(path);
  }

  @override
  Future<void> discardDraft(String draftPath) async {}

  @override
  Future<LocalVideoFileInfo?> pickVideo(LocalVideoPickOrigin origin) {
    throw UnsupportedError('Not used by this test');
  }
}

final class _MemoryRepository implements PracticeSourceRepository {
  final List<PracticeSource> sources = [];

  @override
  Future<void> delete(String id) async {
    sources.removeWhere((source) => source.id == id);
  }

  @override
  Future<PracticeSource?> getById(String id) async {
    return sources.where((source) => source.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSource source) async {
    final index = sources.indexWhere((item) => item.id == source.id);
    if (index == -1) {
      sources.add(source);
    } else {
      sources[index] = source;
    }
  }

  @override
  Stream<List<PracticeSource>> watchAll() => Stream.value(List.of(sources));
}

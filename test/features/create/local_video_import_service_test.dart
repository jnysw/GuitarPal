import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/local_video_gateway.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/create/application/local_video_import_service.dart';
import 'package:guitar_pal/features/create/domain/local_video_draft.dart';
import 'package:uuid/uuid.dart';

void main() {
  late _MemoryPracticeSourceRepository repository;
  late _FakeLocalVideoGateway gateway;
  late LocalVideoImportService service;
  late LocalVideoDraft draft;

  setUp(() {
    repository = _MemoryPracticeSourceRepository();
    gateway = _FakeLocalVideoGateway();
    service = LocalVideoImportService(repository, gateway, const Uuid());
    draft = LocalVideoDraft(
      id: 'draft-1',
      origin: LocalVideoPickOrigin.gallery,
      file: const LocalVideoFileInfo(
        path: '/cache/guitarpal_video_drafts/draft.mp4',
        displayName: 'lesson.mp4',
        sizeBytes: 4096,
        duration: Duration(seconds: 75),
      ),
      createdAt: DateTime.utc(2026, 10, 12, 8),
    );
  });

  test(
    'commits the draft and persists a local video practice source',
    () async {
      final beforeSave = DateTime.now().toUtc();

      final source = await service.save(
        draft: draft,
        requestedTitle: '  Alternate picking  ',
      );

      final afterSave = DateTime.now().toUtc();
      expect(gateway.committedDraftPath, draft.file.path);
      expect(gateway.committedSourceId, source.id);
      expect(repository.sources, [same(source)]);
      expect(source.platform, SourcePlatform.local);
      expect(source.kind, SourceKind.video);
      expect(source.title, 'Alternate picking');
      expect(source.canonicalUri?.toFilePath(), gateway.committedFile.path);
      expect(source.duration, gateway.committedFile.duration);
      expect(source.createdAt, draft.createdAt);
      expect(source.updatedAt.isUtc, isTrue);
      expect(source.updatedAt.isBefore(beforeSave), isFalse);
      expect(source.updatedAt.isAfter(afterSave), isFalse);
    },
  );

  test(
    'falls back to draft duration when committed metadata has no duration',
    () async {
      gateway.committedFile = const LocalVideoFileInfo(
        path: '/files/guitarpal_videos/source.mp4',
        displayName: 'source.mp4',
        sizeBytes: 4096,
        duration: Duration.zero,
      );

      final source = await service.save(draft: draft, requestedTitle: 'Lesson');

      expect(source.duration, draft.file.duration);
    },
  );

  test('rejects an empty title before committing the draft', () async {
    await expectLater(
      service.save(draft: draft, requestedTitle: '   '),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '练习名称不能为空',
        ),
      ),
    );

    expect(gateway.commitCalls, 0);
    expect(repository.sources, isEmpty);
  });

  test(
    'rejects a title longer than 300 characters before committing',
    () async {
      await expectLater(
        service.save(draft: draft, requestedTitle: 'a' * 301),
        throwsA(isA<FormatException>()),
      );

      expect(gateway.commitCalls, 0);
      expect(repository.sources, isEmpty);
    },
  );

  test('deletes the managed copy when repository persistence fails', () async {
    final failure = StateError('database unavailable');
    repository.saveError = failure;

    await expectLater(
      service.save(draft: draft, requestedTitle: 'Lesson'),
      throwsA(same(failure)),
    );

    expect(gateway.deletedManagedPaths, [gateway.committedFile.path]);
  });

  test(
    'preserves repository failure when rollback cleanup also fails',
    () async {
      final failure = StateError('database unavailable');
      repository.saveError = failure;
      gateway.deleteError = StateError('filesystem unavailable');

      await expectLater(
        service.save(draft: draft, requestedTitle: 'Lesson'),
        throwsA(same(failure)),
      );

      expect(gateway.deletedManagedPaths, [gateway.committedFile.path]);
    },
  );

  test('discard delegates cleanup of the selected cache draft', () async {
    await service.discard(draft);

    expect(gateway.discardedDraftPaths, [draft.file.path]);
  });
}

final class _FakeLocalVideoGateway implements LocalVideoGateway {
  LocalVideoFileInfo committedFile = const LocalVideoFileInfo(
    path: '/files/guitarpal_videos/source.mp4',
    displayName: 'source.mp4',
    sizeBytes: 4096,
    duration: Duration(seconds: 80),
  );
  int commitCalls = 0;
  String? committedDraftPath;
  String? committedSourceId;
  final List<String> discardedDraftPaths = [];
  final List<String> deletedManagedPaths = [];
  Object? deleteError;

  @override
  Future<LocalVideoFileInfo> commitDraft({
    required String draftPath,
    required String sourceId,
  }) async {
    commitCalls += 1;
    committedDraftPath = draftPath;
    committedSourceId = sourceId;
    return committedFile;
  }

  @override
  Future<void> deleteManagedVideo(String path) async {
    deletedManagedPaths.add(path);
    if (deleteError case final error?) throw error;
  }

  @override
  Future<void> discardDraft(String draftPath) async {
    discardedDraftPaths.add(draftPath);
  }

  @override
  Future<LocalVideoFileInfo?> pickVideo(LocalVideoPickOrigin origin) async {
    throw UnsupportedError('Not used by these tests');
  }
}

final class _MemoryPracticeSourceRepository
    implements PracticeSourceRepository {
  final List<PracticeSource> sources = [];
  Object? saveError;

  @override
  Future<void> delete(String id) async {
    sources.removeWhere((source) => source.id == id);
  }

  @override
  Future<PracticeSource?> getById(String id) async {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  @override
  Future<void> save(PracticeSource source) async {
    if (saveError case final error?) throw error;
    sources.add(source);
  }

  @override
  Stream<List<PracticeSource>> watchAll() => Stream.value(List.of(sources));
}

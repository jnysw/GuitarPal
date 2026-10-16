import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/local_video_gateway.dart';
import 'package:guitar_pal/features/create/application/local_video_draft_store.dart';
import 'package:guitar_pal/features/create/domain/local_video_draft.dart';

void main() {
  group('LocalVideoDraft', () {
    test('derives a friendly title from the selected file name', () {
      final draft = _draft(displayName: '  Little Wing practice.mp4  ');

      expect(draft.suggestedTitle, 'Little Wing practice');
    });

    test('uses a fallback title when the selected file has no usable name', () {
      final draft = _draft(displayName: '   ');

      expect(draft.suggestedTitle, '本地视频练习');
    });

    test('only removes the final extension from names containing dots', () {
      final draft = _draft(displayName: 'lesson.take.02.mov');

      expect(draft.suggestedTitle, 'lesson.take.02');
    });
  });

  group('LocalVideoDraftStore', () {
    test('stores, retrieves, and removes a newly-created draft', () {
      final store = LocalVideoDraftStore(
        clock: () => DateTime.utc(2026, 10, 12, 9, 30),
      );
      const file = LocalVideoFileInfo(
        path: '/cache/draft.mp4',
        displayName: 'draft.mp4',
        sizeBytes: 1024,
        duration: Duration(seconds: 42),
      );

      final draft = store.create(
        origin: LocalVideoPickOrigin.gallery,
        file: file,
      );

      expect(draft.id, isNotEmpty);
      expect(draft.origin, LocalVideoPickOrigin.gallery);
      expect(draft.file, same(file));
      expect(draft.createdAt, DateTime.utc(2026, 10, 12, 9, 30));
      expect(store.getById(draft.id), same(draft));
      expect(store.remove(draft.id), same(draft));
      expect(store.getById(draft.id), isNull);
      expect(store.remove(draft.id), isNull);
    });

    test('creates a distinct id for every draft', () {
      final store = LocalVideoDraftStore();

      final first = store.create(
        origin: LocalVideoPickOrigin.files,
        file: _file('/cache/first.mp4'),
      );
      final second = store.create(
        origin: LocalVideoPickOrigin.files,
        file: _file('/cache/second.mp4'),
      );

      expect(first.id, isNot(second.id));
      expect(store.getById(first.id), same(first));
      expect(store.getById(second.id), same(second));
    });
  });
}

LocalVideoDraft _draft({required String displayName}) {
  return LocalVideoDraft(
    id: 'draft-1',
    origin: LocalVideoPickOrigin.gallery,
    file: LocalVideoFileInfo(
      path: '/cache/video.mp4',
      displayName: displayName,
      sizeBytes: 2048,
      duration: const Duration(seconds: 12),
    ),
    createdAt: DateTime.utc(2026, 10, 12),
  );
}

LocalVideoFileInfo _file(String path) {
  return LocalVideoFileInfo(
    path: path,
    displayName: path.split('/').last,
    sizeBytes: 1024,
    duration: const Duration(seconds: 10),
  );
}

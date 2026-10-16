import 'package:uuid/uuid.dart';

import '../../../core/platform/local_video_gateway.dart';
import '../../../domain/practice_source/practice_source.dart';
import '../../../domain/practice_source/practice_source_repository.dart';
import '../domain/local_video_draft.dart';

class LocalVideoImportService {
  const LocalVideoImportService(this._repository, this._gateway, this._uuid);

  final PracticeSourceRepository _repository;
  final LocalVideoGateway _gateway;
  final Uuid _uuid;

  Future<PracticeSource> save({
    required LocalVideoDraft draft,
    required String requestedTitle,
  }) async {
    final title = requestedTitle.trim();
    if (title.isEmpty) {
      throw const FormatException('练习名称不能为空');
    }
    if (title.length > 300) {
      throw const FormatException('练习名称不能超过 300 个字符');
    }

    final sourceId = _uuid.v4();
    final committed = await _gateway.commitDraft(
      draftPath: draft.file.path,
      sourceId: sourceId,
    );
    final now = DateTime.now().toUtc();
    final source = PracticeSource(
      id: sourceId,
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      canonicalUri: Uri.file(committed.path),
      title: title,
      duration: committed.duration > Duration.zero
          ? committed.duration
          : draft.file.duration,
      createdAt: draft.createdAt,
      updatedAt: now,
    );

    try {
      await _repository.save(source);
      return source;
    } on Object catch (error, stackTrace) {
      try {
        await _gateway.deleteManagedVideo(committed.path);
      } on Object {
        // Preserve the repository failure; private-file cleanup is best effort.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> discard(LocalVideoDraft draft) {
    return _gateway.discardDraft(draft.file.path);
  }
}

import 'package:uuid/uuid.dart';

import '../../../domain/practice_source/practice_source.dart';
import '../../../domain/practice_source/practice_source_repository.dart';
import '../../../media/adapters/practice_source_adapter.dart';
import '../../../media/adapters/source_resolver.dart';
import '../domain/shared_item.dart';

class SourceImportService {
  const SourceImportService(this._resolver, this._repository, this._uuid);

  final SourceResolver _resolver;
  final PracticeSourceRepository _repository;
  final Uuid _uuid;

  Future<ResolvedSource> prepare(SharedItem item) {
    final uri = item.detectedUri;
    if (uri == null) {
      throw const FormatException('分享内容中没有可识别的 URL');
    }
    return _resolver.resolve(uri);
  }

  Future<PracticeSource> save({
    required SharedItem item,
    required ResolvedSource resolved,
    required String title,
  }) async {
    final now = DateTime.now().toUtc();
    final source = PracticeSource(
      id: _uuid.v4(),
      platform: resolved.platform,
      kind: resolved.kind,
      originalUri: resolved.originalUri,
      canonicalUri: resolved.canonicalUri,
      externalId: resolved.externalId,
      title: title.trim().isEmpty ? resolved.title : title.trim(),
      thumbnailUri: resolved.thumbnailUri,
      createdAt: item.receivedAt,
      updatedAt: now,
    );
    await _repository.save(source);
    return source;
  }
}

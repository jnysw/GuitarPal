import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/url/source_url_normalizer.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/domain/practice_source/source_capabilities.dart';
import 'package:guitar_pal/features/inbox/application/source_import_service.dart';
import 'package:guitar_pal/features/inbox/domain/shared_item.dart';
import 'package:guitar_pal/media/adapters/adapter_registry.dart';
import 'package:guitar_pal/media/adapters/practice_source_adapter.dart';
import 'package:guitar_pal/media/adapters/reference_source_adapters.dart';
import 'package:guitar_pal/media/adapters/source_resolver.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('save persists resolved title and thumbnail metadata', () async {
    final repository = _MemoryRepository();
    final service = SourceImportService(
      SourceResolver(
        AdapterRegistry(const [GenericWebAdapter()]),
        SourceUrlNormalizer(),
      ),
      repository,
      const Uuid(),
    );
    final receivedAt = DateTime.utc(2026, 10, 14, 9);
    final canonicalUri = Uri.parse('https://example.com/lesson');
    final thumbnailUri = Uri.parse('https://example.com/cover.jpg');
    final item = SharedItem(
      id: 'shared-1',
      rawText: canonicalUri.toString(),
      detectedUri: canonicalUri,
      receivedAt: receivedAt,
    );
    final resolved = ResolvedSource(
      platform: SourcePlatform.genericWeb,
      kind: SourceKind.webReference,
      originalUri: canonicalUri,
      canonicalUri: canonicalUri,
      title: '页面标题',
      thumbnailUri: thumbnailUri,
      capabilities: SourceCapabilities.reference,
    );

    final saved = await service.save(item: item, resolved: resolved, title: '');

    expect(saved.title, '页面标题');
    expect(saved.thumbnailUri, thumbnailUri);
    expect(repository.source?.thumbnailUri, thumbnailUri);
    expect(saved.createdAt, receivedAt);
  });
}

final class _MemoryRepository implements PracticeSourceRepository {
  PracticeSource? source;

  @override
  Future<void> delete(String id) async => source = null;

  @override
  Future<PracticeSource?> getById(String id) async => source;

  @override
  Future<void> save(PracticeSource source) async => this.source = source;

  @override
  Stream<List<PracticeSource>> watchAll() {
    return Stream.value(source == null ? const [] : [source!]);
  }
}

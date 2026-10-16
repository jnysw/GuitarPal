import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/url/source_url_normalizer.dart';
import '../../core/url/uri_redirect_resolver.dart';
import '../../media/adapters/adapter_registry.dart';
import '../../media/adapters/practice_source_adapter.dart';
import '../../media/adapters/reference_source_adapters.dart';
import '../../media/adapters/source_resolver.dart';
import '../../media/metadata/source_metadata_providers.dart';
import '../library/practice_source_providers.dart';
import 'application/source_import_service.dart';
import 'domain/shared_item.dart';

final sourceUrlNormalizerProvider = Provider<SourceUrlNormalizer>((ref) {
  return SourceUrlNormalizer();
});

final sourceAdapterRegistryProvider = Provider<AdapterRegistry>((ref) {
  return AdapterRegistry(const [
    YouTubeAdapter(),
    BilibiliAdapter(),
    DouyinAdapter(),
    XiaohongshuAdapter(),
    GenericWebAdapter(),
  ]);
});

final sourceResolverProvider = Provider<SourceResolver>((ref) {
  return SourceResolver(
    ref.watch(sourceAdapterRegistryProvider),
    ref.watch(sourceUrlNormalizerProvider),
    redirectResolver: BilibiliShareRedirectResolver(),
    metadataLoader: ref.watch(sourceMetadataLoaderProvider),
  );
});

final sharedItemParserProvider = Provider<SharedItemParser>((ref) {
  return SharedItemParser(ref.watch(sourceUrlNormalizerProvider));
});

final sourceImportServiceProvider = Provider<SourceImportService>((ref) {
  return SourceImportService(
    ref.watch(sourceResolverProvider),
    ref.watch(practiceSourceRepositoryProvider),
    const Uuid(),
  );
});

final resolvedSourceProvider = FutureProvider.autoDispose
    .family<ResolvedSource, Uri>((ref, uri) {
      return ref.watch(sourceResolverProvider).resolve(uri);
    });

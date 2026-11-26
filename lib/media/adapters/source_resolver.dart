import '../../core/url/source_url_normalizer.dart';
import '../../core/url/uri_redirect_resolver.dart';
import '../metadata/source_metadata.dart';
import 'adapter_registry.dart';
import 'practice_source_adapter.dart';

class SourceResolver {
  const SourceResolver(
    this._registry,
    this._normalizer, {
    this.redirectResolver,
    this.metadataLoader,
  });

  final AdapterRegistry _registry;
  final SourceUrlNormalizer _normalizer;
  final UriRedirectResolver? redirectResolver;
  final SourceMetadataLoader? metadataLoader;

  Future<ResolvedSource> resolve(Uri originalUri) async {
    final original = _normalizer.normalize(originalUri);
    final host = original.canonicalUri.host;
    if (host == 'douyin.com' ||
        host.endsWith('.douyin.com') ||
        host == 'iesdouyin.com' ||
        host.endsWith('.iesdouyin.com')) {
      throw const FormatException('已停止导入抖音链接。可以导入本地视频，或使用其他支持的链接。');
    }
    var playableUri = original.canonicalUri;
    final redirectExpander = redirectResolver;
    if (redirectExpander != null) {
      playableUri = await redirectExpander.resolve(playableUri);
    }
    final canonical = _normalizer.normalize(playableUri).canonicalUri;
    final adapter = _registry.adapterFor(canonical);
    final resolved = await adapter.resolve(canonical);
    SourceMetadata? metadata;
    try {
      metadata = await metadataLoader?.load(resolved.canonicalUri);
    } on Object {
      // Preview metadata is optional and must never block importing a source.
    }
    return resolved.copyWith(
      originalUri: original.originalUri,
      title: metadata?.title,
      thumbnailUri: metadata?.thumbnailUri,
    );
  }
}

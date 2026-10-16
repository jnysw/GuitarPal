import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/url/source_url_normalizer.dart';
import 'package:guitar_pal/core/url/uri_redirect_resolver.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/media/adapters/adapter_registry.dart';
import 'package:guitar_pal/media/adapters/reference_source_adapters.dart';
import 'package:guitar_pal/media/adapters/source_resolver.dart';
import 'package:guitar_pal/media/metadata/source_metadata.dart';

void main() {
  final resolver = SourceResolver(
    AdapterRegistry(const [
      YouTubeAdapter(),
      BilibiliAdapter(),
      DouyinAdapter(),
      XiaohongshuAdapter(),
      GenericWebAdapter(),
    ]),
    SourceUrlNormalizer(),
  );

  test('resolves supported platforms before generic web', () async {
    final cases = <Uri, (SourcePlatform, bool)>{
      Uri.parse('https://youtu.be/video123'): (SourcePlatform.youtube, false),
      Uri.parse('https://www.bilibili.com/video/BV1test123'): (
        SourcePlatform.bilibili,
        true,
      ),
      Uri.parse('https://www.douyin.com/video/7390123'): (
        SourcePlatform.douyin,
        false,
      ),
      Uri.parse('https://www.xiaohongshu.com/explore/66abc'): (
        SourcePlatform.xiaohongshu,
        false,
      ),
      Uri.parse('https://example.com/lesson'): (
        SourcePlatform.genericWeb,
        false,
      ),
    };

    for (final entry in cases.entries) {
      final source = await resolver.resolve(entry.key);
      expect(source.platform, entry.value.$1);
      expect(source.capabilities.canOpen, isTrue);
      expect(source.capabilities.canPlayInline, entry.value.$2);
    }
  });

  test('extracts public external ids without network requests', () async {
    final youtube = await resolver.resolve(
      Uri.parse('https://www.youtube.com/watch?v=abc123&utm_source=share'),
    );
    final bilibili = await resolver.resolve(
      Uri.parse('https://www.bilibili.com/video/BV1xyZ987'),
    );

    expect(youtube.externalId, 'abc123');
    expect(bilibili.externalId, 'BV1xyZ987');
    expect(
      youtube.canonicalUri.toString(),
      'https://www.youtube.com/watch?v=abc123',
    );
  });

  test('expands a Bilibili short share link before adapting it', () async {
    final resolverWithRedirect = SourceResolver(
      AdapterRegistry(const [BilibiliAdapter(), GenericWebAdapter()]),
      SourceUrlNormalizer(),
      redirectResolver: _FakeRedirectResolver(
        Uri.parse('https://www.bilibili.com/video/BV1redirected'),
      ),
    );

    final source = await resolverWithRedirect.resolve(
      Uri.parse('https://b23.tv/abc123'),
    );

    expect(source.originalUri.toString(), 'https://b23.tv/abc123');
    expect(
      source.canonicalUri.toString(),
      'https://www.bilibili.com/video/BV1redirected',
    );
    expect(source.externalId, 'BV1redirected');
    expect(source.capabilities.canPlayInline, isTrue);
  });

  test('enriches resolved sources with optional public metadata', () async {
    final enrichedResolver = SourceResolver(
      AdapterRegistry(const [GenericWebAdapter()]),
      SourceUrlNormalizer(),
      metadataLoader: _FakeMetadataLoader(
        const SourceMetadata(title: '公开页面标题', thumbnailUri: null),
      ),
    );

    final source = await enrichedResolver.resolve(
      Uri.parse('https://example.com/lesson'),
    );

    expect(source.title, '公开页面标题');
  });

  test('metadata failures do not block source resolution', () async {
    final resilientResolver = SourceResolver(
      AdapterRegistry(const [GenericWebAdapter()]),
      SourceUrlNormalizer(),
      metadataLoader: const _ThrowingMetadataLoader(),
    );

    final source = await resilientResolver.resolve(
      Uri.parse('https://example.com/lesson'),
    );

    expect(source.title, '网页练习内容');
  });
}

final class _FakeMetadataLoader implements SourceMetadataLoader {
  const _FakeMetadataLoader(this.metadata);

  final SourceMetadata metadata;

  @override
  Future<SourceMetadata?> load(Uri uri) async => metadata;
}

final class _ThrowingMetadataLoader implements SourceMetadataLoader {
  const _ThrowingMetadataLoader();

  @override
  Future<SourceMetadata?> load(Uri uri) {
    throw StateError('metadata unavailable');
  }
}

final class _FakeRedirectResolver implements UriRedirectResolver {
  const _FakeRedirectResolver(this.result);

  final Uri result;

  @override
  Future<Uri> resolve(Uri uri) async => result;
}

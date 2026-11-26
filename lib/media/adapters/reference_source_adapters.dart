import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_source/source_capabilities.dart';
import 'online_video_links.dart';
import 'practice_source_adapter.dart';

abstract base class ReferenceSourceAdapter implements PracticeSourceAdapter {
  const ReferenceSourceAdapter();

  SourcePlatform get platform;

  String get defaultTitle;

  SourceCapabilities get capabilities => SourceCapabilities.reference;

  String? extractExternalId(Uri uri) => null;

  Uri canonicalUri(Uri uri) => uri;

  SourceCapabilities capabilitiesFor(Uri uri) => capabilities;

  @override
  Future<ResolvedSource> resolve(Uri uri) async {
    return ResolvedSource(
      platform: platform,
      kind: SourceKind.webReference,
      originalUri: uri,
      canonicalUri: canonicalUri(uri),
      externalId: extractExternalId(uri),
      title: defaultTitle,
      capabilities: capabilitiesFor(uri),
    );
  }

  @override
  Future<SourceCapabilities> getCapabilities(PracticeSource source) async {
    final uri = source.canonicalUri ?? source.originalUri;
    return uri == null ? capabilities : capabilitiesFor(uri);
  }
}

final class YouTubeAdapter extends ReferenceSourceAdapter {
  const YouTubeAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.youtube;

  @override
  String get defaultTitle => 'YouTube 练习内容';

  @override
  bool canHandle(Uri uri) => isYouTubeHost(uri.host);

  @override
  String? extractExternalId(Uri uri) => youtubeVideoId(uri);

  @override
  SourceCapabilities capabilitiesFor(Uri uri) => youtubeVideoId(uri) == null
      ? SourceCapabilities.reference
      : SourceCapabilities.controlledWeb;

  @override
  Uri canonicalUri(Uri uri) {
    final id = youtubeVideoId(uri);
    if (id == null) return uri;
    final start = uri.queryParameters['t'] ?? uri.queryParameters['start'];
    return Uri.https('www.youtube.com', '/watch', {'v': id, 't': ?start});
  }
}

final class BilibiliAdapter extends ReferenceSourceAdapter {
  const BilibiliAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.bilibili;

  @override
  String get defaultTitle => 'Bilibili 练习内容';

  @override
  SourceCapabilities get capabilities => SourceCapabilities.controlledWeb;

  @override
  bool canHandle(Uri uri) {
    final host = _normalizedHost(uri);
    return host == 'b23.tv' ||
        host == 'bilibili.com' ||
        host.endsWith('.bilibili.com');
  }

  @override
  String? extractExternalId(Uri uri) {
    for (final segment in uri.pathSegments) {
      if (RegExp(r'^(BV[0-9A-Za-z]+|av\d+)$').hasMatch(segment)) {
        return segment;
      }
    }
    return null;
  }
}

final class DouyinAdapter extends ReferenceSourceAdapter {
  const DouyinAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.douyin;

  @override
  String get defaultTitle => '抖音练习内容';

  @override
  bool canHandle(Uri uri) {
    final host = _normalizedHost(uri);
    return host == 'douyin.com' ||
        host.endsWith('.douyin.com') ||
        host == 'iesdouyin.com' ||
        host.endsWith('.iesdouyin.com');
  }

  @override
  String? extractExternalId(Uri uri) {
    final id = _segmentAfter(uri, const {'video', 'note'});
    return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
  }

  @override
  Uri canonicalUri(Uri uri) {
    final id = extractExternalId(uri);
    if (id == null) return uri;
    final kind = uri.pathSegments.contains('note') ? 'note' : 'video';
    return Uri.https('www.douyin.com', '/$kind/$id');
  }
}

final class InstagramAdapter extends ReferenceSourceAdapter {
  const InstagramAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.instagram;

  @override
  String get defaultTitle => 'Instagram 练习内容';

  @override
  bool canHandle(Uri uri) => isInstagramHost(uri.host);

  @override
  Uri canonicalUri(Uri uri) => instagramPostUri(uri) ?? uri;

  @override
  String? extractExternalId(Uri uri) => instagramPostUri(uri)?.pathSegments[1];

  @override
  SourceCapabilities capabilitiesFor(Uri uri) => instagramPostUri(uri) == null
      ? SourceCapabilities.reference
      : SourceCapabilities.embeddedPreview;
}

final class XiaohongshuAdapter extends ReferenceSourceAdapter {
  const XiaohongshuAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.xiaohongshu;

  @override
  String get defaultTitle => '小红书练习内容';

  @override
  bool canHandle(Uri uri) {
    final host = _normalizedHost(uri);
    return host == 'xhslink.com' ||
        host == 'xiaohongshu.com' ||
        host.endsWith('.xiaohongshu.com');
  }

  @override
  String? extractExternalId(Uri uri) {
    return _segmentAfter(uri, const {'explore', 'discovery', 'item'});
  }
}

final class GenericWebAdapter extends ReferenceSourceAdapter {
  const GenericWebAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.genericWeb;

  @override
  String get defaultTitle => '网页练习内容';

  @override
  bool canHandle(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';
}

String _normalizedHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host.startsWith('www.') ? host.substring(4) : host;
}

String? _segmentAfter(Uri uri, Set<String> markers) {
  for (var index = 0; index < uri.pathSegments.length - 1; index++) {
    if (markers.contains(uri.pathSegments[index])) {
      final value = uri.pathSegments[index + 1];
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

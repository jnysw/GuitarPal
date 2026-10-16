import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_source/source_capabilities.dart';
import 'practice_source_adapter.dart';

abstract base class ReferenceSourceAdapter implements PracticeSourceAdapter {
  const ReferenceSourceAdapter();

  SourcePlatform get platform;

  String get defaultTitle;

  SourceCapabilities get capabilities => SourceCapabilities.reference;

  String? extractExternalId(Uri uri) => null;

  @override
  Future<ResolvedSource> resolve(Uri uri) async {
    return ResolvedSource(
      platform: platform,
      kind: SourceKind.webReference,
      originalUri: uri,
      canonicalUri: uri,
      externalId: extractExternalId(uri),
      title: defaultTitle,
      capabilities: capabilities,
    );
  }

  @override
  Future<SourceCapabilities> getCapabilities(PracticeSource source) async {
    return capabilities;
  }
}

final class YouTubeAdapter extends ReferenceSourceAdapter {
  const YouTubeAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.youtube;

  @override
  String get defaultTitle => 'YouTube 练习内容';

  @override
  bool canHandle(Uri uri) {
    final host = _normalizedHost(uri);
    return host == 'youtu.be' ||
        host == 'youtube.com' ||
        host == 'm.youtube.com';
  }

  @override
  String? extractExternalId(Uri uri) {
    if (_normalizedHost(uri) == 'youtu.be') {
      return uri.pathSegments.firstOrNull;
    }
    final queryId = uri.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) return queryId;
    return _segmentAfter(uri, const {'shorts', 'embed', 'live'});
  }
}

final class BilibiliAdapter extends ReferenceSourceAdapter {
  const BilibiliAdapter();

  @override
  SourcePlatform get platform => SourcePlatform.bilibili;

  @override
  String get defaultTitle => 'Bilibili 练习内容';

  @override
  SourceCapabilities get capabilities => SourceCapabilities.bilibiliWeb;

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
        host.endsWith('.iesdouyin.com');
  }

  @override
  String? extractExternalId(Uri uri) {
    return _segmentAfter(uri, const {'video'});
  }
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

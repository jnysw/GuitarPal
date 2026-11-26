import '../../domain/practice_source/practice_source.dart';

bool isYouTubeHost(String host) => const {
  'youtu.be',
  'www.youtu.be',
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
}.contains(host);

final _youtubeId = RegExp(r'^[a-zA-Z0-9_-]{11}$');

String? youtubeVideoId(Uri uri) {
  if (!isYouTubeHost(uri.host) ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final path = uri.pathSegments;
  final String? candidate;
  if (uri.host == 'youtu.be' || uri.host == 'www.youtu.be') {
    candidate = path.firstOrNull;
  } else if (path.firstOrNull == 'watch') {
    candidate = uri.queryParameters['v'];
  } else if (path.length >= 2 &&
      const {'shorts', 'embed', 'live'}.contains(path.first)) {
    candidate = path[1];
  } else {
    return null;
  }
  return candidate != null && _youtubeId.hasMatch(candidate) ? candidate : null;
}

bool isInstagramHost(String host) => const {
  'instagram.com',
  'www.instagram.com',
  'm.instagram.com',
}.contains(host);

final _instagramCode = RegExp(r'^[a-zA-Z0-9_-]{1,32}$');

Uri? instagramPostUri(Uri uri) {
  final path = uri.pathSegments;
  if (!isInstagramHost(uri.host) ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      path.length < 2 ||
      !const {'p', 'reel', 'tv'}.contains(path.first) ||
      !_instagramCode.hasMatch(path[1])) {
    return null;
  }
  return Uri.https('www.instagram.com', '/${path.first}/${path[1]}/');
}

extension SourcePlaybackSupport on PracticeSource {
  String? get youtubeId {
    if (platform != SourcePlatform.youtube &&
        platform != SourcePlatform.genericWeb) {
      return null;
    }
    return [
      canonicalUri,
      originalUri,
    ].nonNulls.map(youtubeVideoId).nonNulls.firstOrNull;
  }

  int get youtubeStartSeconds {
    final query = (canonicalUri ?? originalUri)?.queryParameters;
    final raw = query?['t'] ?? query?['start'] ?? '';
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed.clamp(0, 2147483647);
    final units = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$')
        .firstMatch(raw);
    if (units == null) return 0;
    int value(int group) =>
        (int.tryParse(units.group(group) ?? '') ?? 0).clamp(0, 2147483647);
    return (value(1) * 3600 + value(2) * 60 + value(3)).clamp(0, 2147483647);
  }

  Uri? get instagramPreview {
    if (platform != SourcePlatform.instagram &&
        platform != SourcePlatform.genericWeb) {
      return null;
    }
    return [
      canonicalUri,
      originalUri,
    ].nonNulls.map(instagramPostUri).nonNulls.firstOrNull;
  }

  bool get canPracticeInApp =>
      (platform == SourcePlatform.bilibili && externalId != null) ||
      youtubeId != null ||
      (platform == SourcePlatform.local &&
          kind == SourceKind.video &&
          canonicalUri?.scheme == 'file');
}

class NormalizedSourceUrl {
  const NormalizedSourceUrl({
    required this.originalUri,
    required this.canonicalUri,
  });

  final Uri originalUri;
  final Uri canonicalUri;
}

class SourceUrlNormalizer {
  static const _trackingKeys = {
    'from',
    'share_medium',
    'share_plat',
    'share_source',
    'spm_id_from',
    'utm_campaign',
    'utm_content',
    'utm_medium',
    'utm_source',
    'utm_term',
  };

  static final RegExp _urlPattern = RegExp(r'https?://[^\s<>]+');
  static final RegExp _trailingPunctuation = RegExp(
    r'''[\]\[(){}。，、；;！!？?'"”’]+$''',
  );

  Uri? detectUri(String rawText) {
    final match = _urlPattern.firstMatch(rawText);
    if (match == null) return null;

    final candidate = match.group(0)!.replaceFirst(_trailingPunctuation, '');
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  NormalizedSourceUrl normalize(Uri uri) {
    final filteredQuery = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      if (!_trackingKeys.contains(entry.key.toLowerCase())) {
        filteredQuery[entry.key] = entry.value;
      }
    }

    final canonicalUri = Uri(
      scheme: uri.scheme.toLowerCase(),
      userInfo: uri.userInfo,
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );

    return NormalizedSourceUrl(originalUri: uri, canonicalUri: canonicalUri);
  }
}

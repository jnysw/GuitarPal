import 'source_metadata.dart';

class OpenGraphMetadataParser {
  const OpenGraphMetadataParser();

  SourceMetadata? parse(String html, {required Uri baseUri}) {
    final values = <String, String>{};
    final metaTags = RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in metaTags) {
      final attributes = _parseAttributes(match.group(0)!);
      final key = (attributes['property'] ?? attributes['name'])
          ?.trim()
          .toLowerCase();
      final content = attributes['content'];
      if (key == null || content == null || content.trim().isEmpty) continue;
      values.putIfAbsent(key, () => _decodeHtml(content).trim());
    }

    final rawTitle =
        values['og:title'] ?? values['twitter:title'] ?? _documentTitle(html);
    final title = _normalizeTitle(rawTitle);
    final rawImage =
        values['og:image:secure_url'] ??
        values['og:image'] ??
        values['twitter:image'];
    final thumbnailUri = _safeImageUri(rawImage, baseUri);
    final metadata = SourceMetadata(title: title, thumbnailUri: thumbnailUri);
    return metadata.isEmpty ? null : metadata;
  }

  Map<String, String> _parseAttributes(String tag) {
    final attributes = <String, String>{};
    final pattern = RegExp(
      r'''([^\s=/>]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(tag)) {
      final name = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes.putIfAbsent(name, () => value);
    }
    return attributes;
  }

  String? _documentTitle(String html) {
    final match = RegExp(
      r'<title\b[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    return match == null ? null : _decodeHtml(match.group(1)!);
  }

  String? _normalizeTitle(String? value) {
    if (value == null) return null;
    final normalized = value
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;
    return normalized.length <= 300
        ? normalized
        : normalized.substring(0, 300).trimRight();
  }

  Uri? _safeImageUri(String? value, Uri baseUri) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null) return null;
    final resolved = baseUri.resolveUri(parsed);
    if (resolved.scheme != 'https' ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    return resolved;
  }

  String _decodeHtml(String value) {
    final numericDecoded = value.replaceAllMapped(
      RegExp(r'&#(x?[0-9a-fA-F]+);'),
      (match) {
        final raw = match.group(1)!;
        final radix = raw.startsWith('x') || raw.startsWith('X') ? 16 : 10;
        final digits = radix == 16 ? raw.substring(1) : raw;
        final codePoint = int.tryParse(digits, radix: radix);
        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return match.group(0)!;
        }
        return String.fromCharCode(codePoint);
      },
    );
    const namedEntities = <String, String>{
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    var decoded = numericDecoded;
    for (final entry in namedEntities.entries) {
      decoded = decoded.replaceAll(entry.key, entry.value);
    }
    return decoded;
  }
}

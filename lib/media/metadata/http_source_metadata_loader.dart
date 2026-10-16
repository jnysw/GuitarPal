import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'open_graph_metadata_parser.dart';
import 'source_metadata.dart';

/// Reads standard Open Graph metadata from an ordinary public web page.
///
/// This loader deliberately avoids platform-private APIs. All failures are
/// converted to `null`, so a source can still be imported in reference mode.
final class HttpSourceMetadataLoader implements SourceMetadataLoader {
  const HttpSourceMetadataLoader({
    this.timeout = const Duration(seconds: 6),
    this.maximumBytes = 512 * 1024,
  });

  final Duration timeout;
  final int maximumBytes;

  static const _maximumRedirects = 3;

  @override
  Future<SourceMetadata?> load(Uri uri) async {
    try {
      return await _load(uri).timeout(timeout);
    } on Object {
      return null;
    }
  }

  Future<SourceMetadata?> _load(Uri uri) async {
    if (!await _isSafePublicUri(uri)) return null;

    final client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = timeout
      ..userAgent = 'GuitarPal/1.0 (source preview)';
    try {
      var current = uri;
      for (var redirects = 0; redirects <= _maximumRedirects; redirects++) {
        final request = await client.getUrl(current);
        request
          ..followRedirects = false
          ..headers.set(
            HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml;q=0.9',
          );
        final response = await request.close();

        if (_isRedirect(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || redirects == _maximumRedirects) return null;
          final next = current.resolve(location);
          if (!await _isSafePublicUri(next)) return null;
          current = next;
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final contentType = response.headers.contentType;
        if (contentType != null &&
            contentType.mimeType != 'text/html' &&
            contentType.mimeType != 'application/xhtml+xml') {
          return null;
        }
        final declaredLength = response.contentLength;
        if (declaredLength > maximumBytes) return null;

        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(timeout)) {
          final remaining = maximumBytes - bytes.length;
          if (remaining <= 0) break;
          bytes.add(
            chunk.length <= remaining
                ? chunk
                : Uint8List.fromList(chunk.sublist(0, remaining)),
          );
          if (bytes.length >= maximumBytes) break;
        }
        final html = utf8.decode(bytes.takeBytes(), allowMalformed: true);
        return const OpenGraphMetadataParser().parse(html, baseUri: current);
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _isSafePublicUri(Uri uri) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      return false;
    }
    final addresses = await InternetAddress.lookup(host).timeout(timeout);
    return addresses.isNotEmpty && addresses.every(_isPublicAddress);
  }

  bool _isPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isPublicIpv4(bytes);
    }
    if (bytes.length != 16) return false;
    if (bytes.every((byte) => byte == 0)) return false;
    if (bytes.take(15).every((byte) => byte == 0) && bytes.last == 1) {
      return false;
    }
    if ((bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) ||
        bytes[0] == 0xff) {
      return false;
    }
    final isIpv4Mapped =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    return !isIpv4Mapped || _isPublicIpv4(bytes.sublist(12));
  }

  bool _isPublicIpv4(List<int> bytes) {
    if (bytes.length != 4) return false;
    final first = bytes[0];
    final second = bytes[1];
    return first != 0 &&
        first != 10 &&
        first != 127 &&
        !(first == 100 && second >= 64 && second <= 127) &&
        !(first == 169 && second == 254) &&
        !(first == 172 && second >= 16 && second <= 31) &&
        !(first == 192 && second == 168) &&
        first < 224;
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }
}

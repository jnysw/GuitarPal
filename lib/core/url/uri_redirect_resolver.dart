import 'dart:async';
import 'dart:io';

abstract interface class UriRedirectResolver {
  Future<Uri> resolve(Uri uri);
}

/// Expands public Bilibili share links using ordinary HTTPS redirects only.
///
/// Redirects are kept inside Bilibili-owned hosts and response bodies are not
/// consumed as content. Any network or validation failure returns the input so
/// importing a source still works in offline/reference mode.
final class BilibiliShareRedirectResolver implements UriRedirectResolver {
  BilibiliShareRedirectResolver({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  static const _maximumRedirects = 5;
  static const _timeout = Duration(seconds: 8);

  @override
  Future<Uri> resolve(Uri uri) async {
    if (!_isShortShareUri(uri)) return uri;

    var current = uri;
    try {
      for (
        var redirectCount = 0;
        redirectCount < _maximumRedirects;
        redirectCount++
      ) {
        final request = await _client.getUrl(current).timeout(_timeout);
        request
          ..followRedirects = false
          ..headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        final response = await request.close().timeout(_timeout);
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>().timeout(_timeout);

        if (!_isRedirect(response.statusCode) || location == null) {
          return current;
        }

        final next = current.resolve(location);
        if (!_isAllowedDestination(next)) return uri;
        current = next;
      }
      return current;
    } on Object {
      return uri;
    }
  }

  bool _isShortShareUri(Uri uri) {
    return uri.scheme == 'https' && _normalizedHost(uri) == 'b23.tv';
  }

  bool _isAllowedDestination(Uri uri) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
    final host = _normalizedHost(uri);
    return host == 'b23.tv' ||
        host == 'bilibili.com' ||
        host.endsWith('.bilibili.com');
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }
}

String _normalizedHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host.startsWith('www.') ? host.substring(4) : host;
}

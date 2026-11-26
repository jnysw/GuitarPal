import 'dart:async';
import 'dart:io';

abstract interface class UriRedirectResolver {
  Future<Uri> resolve(Uri uri);
}

/// Expands public share links using ordinary HTTPS redirects only.
///
/// Redirects stay within the original platform and response bodies are not
/// consumed as content. Any network or validation failure returns the input so
/// importing a source still works in offline/reference mode.
final class PlatformShareRedirectResolver implements UriRedirectResolver {
  PlatformShareRedirectResolver({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  static const _maximumRedirects = 5;
  static const _timeout = Duration(seconds: 8);

  @override
  Future<Uri> resolve(Uri uri) async {
    final hosts = _redirectHosts(uri);
    if (hosts == null || !_isAllowedDestination(uri, hosts)) return uri;

    var current = uri;
    final budget = Stopwatch()..start();
    try {
      for (
        var redirectCount = 0;
        redirectCount < _maximumRedirects;
        redirectCount++
      ) {
        final request = await _client
            .getUrl(current)
            .timeout(_timeout - budget.elapsed);
        request
          ..followRedirects = false
          ..headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
        final response = await request.close().timeout(
          _timeout - budget.elapsed,
        );
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.listen((_) {}).cancel();

        if (!_isRedirect(response.statusCode) || location == null) {
          return current;
        }

        final next = current.resolve(location);
        if (!_isAllowedDestination(next, hosts)) return uri;
        current = next;
      }
      return uri;
    } on Object {
      return uri;
    }
  }

  Set<String>? _redirectHosts(Uri uri) => switch (uri.host) {
    'b23.tv' || 'www.b23.tv' => const {
      'b23.tv',
      'www.b23.tv',
      'bilibili.com',
      'www.bilibili.com',
      'm.bilibili.com',
    },
    'www.instagram.com' || 'instagram.com' || 'm.instagram.com'
        when uri.pathSegments.firstOrNull == 'share' =>
      const {'www.instagram.com', 'instagram.com', 'm.instagram.com'},
    _ => null,
  };

  bool _isAllowedDestination(Uri uri, Set<String> hosts) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      (hosts.contains(uri.host) ||
          (hosts.contains('b23.tv') && uri.host.endsWith('.bilibili.com')));

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }
}

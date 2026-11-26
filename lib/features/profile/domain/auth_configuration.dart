import 'account_session.dart';

class AuthConfiguration {
  AuthConfiguration({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.redirectUri,
    required Iterable<String> scopes,
    required Iterable<AccountSignInMethod> methods,
  }) : scopes = Set.unmodifiable(scopes.map((scope) => scope.trim())),
       methods = Set.unmodifiable(methods) {
    if (!_isSecureWebEndpoint(authorizationEndpoint)) {
      throw ArgumentError.value(
        authorizationEndpoint,
        'authorizationEndpoint',
        'must be an HTTPS URL without credentials',
      );
    }
    if (!_isSecureWebEndpoint(tokenEndpoint)) {
      throw ArgumentError.value(
        tokenEndpoint,
        'tokenEndpoint',
        'must be an HTTPS URL without credentials',
      );
    }
    if (clientId.trim().isEmpty) {
      throw ArgumentError.value(clientId, 'clientId', 'must not be empty');
    }
    if (!_isSafeRedirect(redirectUri)) {
      throw ArgumentError.value(
        redirectUri,
        'redirectUri',
        'must be a custom app URI or HTTPS URL without credentials',
      );
    }
    if (this.scopes.isEmpty || this.scopes.any((scope) => scope.isEmpty)) {
      throw ArgumentError.value(scopes, 'scopes', 'must not be empty');
    }
    if (!this.scopes.contains('openid')) {
      throw ArgumentError.value(scopes, 'scopes', 'must include openid');
    }
    if (this.methods.isEmpty) {
      throw ArgumentError.value(methods, 'methods', 'must not be empty');
    }
  }

  final Uri authorizationEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final Uri redirectUri;
  final Set<String> scopes;
  final Set<AccountSignInMethod> methods;
}

bool _isSecureWebEndpoint(Uri value) {
  return value.scheme == 'https' &&
      value.host.isNotEmpty &&
      value.userInfo.isEmpty &&
      !value.hasFragment;
}

bool _isSafeRedirect(Uri value) {
  if (value.userInfo.isNotEmpty || value.hasFragment) return false;
  if (value.scheme == 'https') return value.host.isNotEmpty;
  return value.scheme.isNotEmpty && value.scheme != 'http';
}

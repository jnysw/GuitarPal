import 'account_session.dart';

class AuthenticatedIdentity {
  AuthenticatedIdentity({
    required String subject,
    required this.method,
    String? email,
    String? displayName,
  }) : subject = subject.trim(),
       email = _normalizeOptional(email),
       displayName = _normalizeOptional(displayName) {
    if (this.subject.isEmpty) {
      throw ArgumentError.value(subject, 'subject', 'must not be empty');
    }
  }

  final String subject;
  final AccountSignInMethod method;
  final String? email;
  final String? displayName;

  AccountSession toSession() {
    return AccountSession.signedIn(
      userId: subject,
      email: email,
      displayName: displayName,
      signInMethod: method,
    );
  }
}

class AuthFlowRequest {
  const AuthFlowRequest({
    required this.method,
    required this.authorizationUri,
    required this.redirectUri,
    required this.state,
    required this.nonce,
    required this.codeVerifier,
  });

  final AccountSignInMethod method;
  final Uri authorizationUri;
  final Uri redirectUri;
  final String state;
  final String nonce;
  final String codeVerifier;
}

sealed class AuthCallbackResult {
  const AuthCallbackResult();

  factory AuthCallbackResult.parse({
    required Uri callbackUri,
    required Uri expectedRedirectUri,
    required String expectedState,
  }) {
    if (!_sameRedirect(callbackUri, expectedRedirectUri)) {
      throw const FormatException('登录回调地址不匹配');
    }
    final state = callbackUri.queryParameters['state'];
    if (state == null ||
        state.isEmpty ||
        !_constantTimeEquals(state, expectedState)) {
      throw const FormatException('登录回调状态校验失败');
    }
    final error = callbackUri.queryParameters['error']?.trim();
    if (error != null && error.isNotEmpty) {
      return AuthCallbackFailure(
        error: error,
        description: _normalizeOptional(
          callbackUri.queryParameters['error_description'],
        ),
      );
    }
    final code = callbackUri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) {
      throw const FormatException('登录回调缺少授权码');
    }
    return AuthCallbackSuccess(code: code);
  }
}

final class AuthCallbackSuccess extends AuthCallbackResult {
  const AuthCallbackSuccess({required this.code});

  final String code;
}

final class AuthCallbackFailure extends AuthCallbackResult {
  const AuthCallbackFailure({required this.error, this.description});

  final String error;
  final String? description;
}

bool _sameRedirect(Uri actual, Uri expected) {
  return actual.scheme == expected.scheme &&
      actual.host == expected.host &&
      actual.port == expected.port &&
      actual.path == expected.path;
}

bool _constantTimeEquals(String left, String right) {
  final leftBytes = left.codeUnits;
  final rightBytes = right.codeUnits;
  var difference = leftBytes.length ^ rightBytes.length;
  final length = leftBytes.length > rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < length; index++) {
    final leftValue = index < leftBytes.length ? leftBytes[index] : 0;
    final rightValue = index < rightBytes.length ? rightBytes[index] : 0;
    difference |= leftValue ^ rightValue;
  }
  return difference == 0;
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

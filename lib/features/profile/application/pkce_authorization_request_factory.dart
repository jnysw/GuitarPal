import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../domain/account_session.dart';
import '../domain/auth_configuration.dart';
import '../domain/auth_flow.dart';

typedef SecureBytesGenerator = List<int> Function(int length);

class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  factory PkcePair.fromVerifier(String verifier) {
    if (verifier.length < 43 || verifier.length > 128) {
      throw ArgumentError.value(
        verifier,
        'verifier',
        'must contain 43 to 128 characters',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(verifier)) {
      throw ArgumentError.value(
        verifier,
        'verifier',
        'contains unsupported characters',
      );
    }
    final digest = sha256.convert(ascii.encode(verifier));
    return PkcePair(
      verifier: verifier,
      challenge: _base64UrlWithoutPadding(digest.bytes),
    );
  }

  final String verifier;
  final String challenge;
}

class PkceAuthorizationRequestFactory {
  PkceAuthorizationRequestFactory({SecureBytesGenerator? generateBytes})
    : _generateBytes = generateBytes ?? _secureBytes;

  final SecureBytesGenerator _generateBytes;

  AuthFlowRequest create({
    required AuthConfiguration configuration,
    required AccountSignInMethod method,
    String? email,
  }) {
    if (!configuration.methods.contains(method)) {
      throw ArgumentError.value(method, 'method', 'is not configured');
    }
    final normalizedEmail = email?.trim();
    if (method == AccountSignInMethod.emailLink &&
        (normalizedEmail == null || normalizedEmail.isEmpty)) {
      throw ArgumentError.value(email, 'email', 'must not be empty');
    }
    final pkce = PkcePair.fromVerifier(
      _base64UrlWithoutPadding(_generateCheckedBytes(32)),
    );
    final state = _base64UrlWithoutPadding(_generateCheckedBytes(24));
    final nonce = _base64UrlWithoutPadding(_generateCheckedBytes(24));
    final query = <String, String>{
      ...configuration.authorizationEndpoint.queryParameters,
      'response_type': 'code',
      'client_id': configuration.clientId,
      'redirect_uri': configuration.redirectUri.toString(),
      'scope': configuration.scopes.join(' '),
      'state': state,
      'nonce': nonce,
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
      if (normalizedEmail != null && normalizedEmail.isNotEmpty)
        'login_hint': normalizedEmail,
    };
    return AuthFlowRequest(
      method: method,
      authorizationUri: configuration.authorizationEndpoint.replace(
        queryParameters: query,
      ),
      redirectUri: configuration.redirectUri,
      state: state,
      nonce: nonce,
      codeVerifier: pkce.verifier,
    );
  }

  List<int> _generateCheckedBytes(int length) {
    final bytes = _generateBytes(length);
    if (bytes.length != length || bytes.any((value) => value < 0 || value > 255)) {
      throw StateError('secure byte generator returned invalid bytes');
    }
    return bytes;
  }
}

List<int> _secureBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256), growable: false);
}

String _base64UrlWithoutPadding(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

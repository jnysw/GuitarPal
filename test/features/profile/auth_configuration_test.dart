import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';
import 'package:guitar_pal/features/profile/domain/auth_configuration.dart';

void main() {
  test('accepts HTTPS endpoints and a custom native redirect', () {
    final configuration = AuthConfiguration(
      authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
      tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      clientId: 'guitarpal-mobile',
      redirectUri: Uri.parse('guitarpal://auth/callback'),
      scopes: const {'openid', 'profile'},
      methods: const {AccountSignInMethod.google},
    );

    expect(configuration.scopes, contains('openid'));
    expect(configuration.methods, {AccountSignInMethod.google});
  });

  test('rejects insecure endpoints and incomplete OpenID configuration', () {
    AuthConfiguration create({
      Uri? authorizationEndpoint,
      Iterable<String> scopes = const {'openid'},
    }) {
      return AuthConfiguration(
        authorizationEndpoint:
            authorizationEndpoint ?? Uri.parse('https://auth.example.com/a'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
        clientId: 'guitarpal-mobile',
        redirectUri: Uri.parse('guitarpal://auth/callback'),
        scopes: scopes,
        methods: const {AccountSignInMethod.google},
      );
    }

    expect(
      () => create(authorizationEndpoint: Uri.parse('http://example.com/a')),
      throwsArgumentError,
    );
    expect(() => create(scopes: const {'profile'}), throwsArgumentError);
  });
}

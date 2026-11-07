import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/application/pkce_authorization_request_factory.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';
import 'package:guitar_pal/features/profile/domain/auth_configuration.dart';
import 'package:guitar_pal/features/profile/domain/auth_flow.dart';

void main() {
  test('derives the RFC 7636 S256 example challenge', () {
    final pair = PkcePair.fromVerifier(
      'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
    );

    expect(pair.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });

  test('creates a complete authorization request with one-time secrets', () {
    var call = 0;
    final factory = PkceAuthorizationRequestFactory(
      generateBytes: (length) {
        call += 1;
        return List<int>.filled(length, call);
      },
    );
    final configuration = AuthConfiguration(
      authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
      tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      clientId: 'guitarpal-mobile',
      redirectUri: Uri.parse('guitarpal://auth/callback'),
      scopes: const {'openid', 'profile', 'email'},
      methods: const {
        AccountSignInMethod.emailLink,
        AccountSignInMethod.google,
      },
    );

    final request = factory.create(
      configuration: configuration,
      method: AccountSignInMethod.emailLink,
      email: ' player@example.com ',
    );
    final query = request.authorizationUri.queryParameters;

    expect(request.codeVerifier, hasLength(43));
    expect(request.state, hasLength(32));
    expect(request.nonce, hasLength(32));
    expect(query['response_type'], 'code');
    expect(query['client_id'], 'guitarpal-mobile');
    expect(query['redirect_uri'], 'guitarpal://auth/callback');
    expect(query['scope'], 'openid profile email');
    expect(query['state'], request.state);
    expect(query['nonce'], request.nonce);
    expect(query['code_challenge_method'], 'S256');
    expect(query['code_challenge'], isNotEmpty);
    expect(query['login_hint'], 'player@example.com');
  });

  test('rejects an unconfigured method and an invalid email request', () {
    final configuration = AuthConfiguration(
      authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
      tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      clientId: 'guitarpal-mobile',
      redirectUri: Uri.parse('guitarpal://auth/callback'),
      scopes: const {'openid'},
      methods: const {AccountSignInMethod.emailLink},
    );
    final factory = PkceAuthorizationRequestFactory(
      generateBytes: (length) => List<int>.filled(length, 1),
    );

    expect(
      () => factory.create(
        configuration: configuration,
        method: AccountSignInMethod.google,
      ),
      throwsArgumentError,
    );
    expect(
      () => factory.create(
        configuration: configuration,
        method: AccountSignInMethod.emailLink,
      ),
      throwsArgumentError,
    );
  });

  test('validates callback redirect and state before accepting a code', () {
    final success = AuthCallbackResult.parse(
      callbackUri: Uri.parse(
        'guitarpal://auth/callback?code=code-1&state=state-1',
      ),
      expectedRedirectUri: Uri.parse('guitarpal://auth/callback'),
      expectedState: 'state-1',
    );
    expect(success, isA<AuthCallbackSuccess>());
    expect((success as AuthCallbackSuccess).code, 'code-1');

    final failure = AuthCallbackResult.parse(
      callbackUri: Uri.parse(
        'guitarpal://auth/callback?error=access_denied&'
        'error_description=User%20cancelled&state=state-1',
      ),
      expectedRedirectUri: Uri.parse('guitarpal://auth/callback'),
      expectedState: 'state-1',
    );
    expect(failure, isA<AuthCallbackFailure>());
    expect((failure as AuthCallbackFailure).error, 'access_denied');
    expect(failure.description, 'User cancelled');

    expect(
      () => AuthCallbackResult.parse(
        callbackUri: Uri.parse(
          'guitarpal://auth/callback?code=code-1&state=wrong',
        ),
        expectedRedirectUri: Uri.parse('guitarpal://auth/callback'),
        expectedState: 'state-1',
      ),
      throwsFormatException,
    );
  });

  test('converts a provider identity into the app session boundary', () {
    final identity = AuthenticatedIdentity(
      subject: ' user-42 ',
      method: AccountSignInMethod.google,
      email: ' player@example.com ',
      displayName: ' 练习者 ',
    );

    final session = identity.toSession();
    expect(session.userId, 'user-42');
    expect(session.email, 'player@example.com');
    expect(session.displayName, '练习者');
    expect(session.signInMethod, AccountSignInMethod.google);
  });
}

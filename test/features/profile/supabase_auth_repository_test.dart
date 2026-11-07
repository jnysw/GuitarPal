import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/application/auth_repository.dart';
import 'package:guitar_pal/features/profile/data/supabase_auth_gateway.dart';
import 'package:guitar_pal/features/profile/data/supabase_auth_repository.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';

void main() {
  late _FakeSupabaseAuthGateway gateway;
  late SupabaseAuthRepository repository;

  setUp(() {
    gateway = _FakeSupabaseAuthGateway();
    repository = SupabaseAuthRepository(
      gateway: gateway,
      redirectUri: Uri.parse('com.guitarpal.app://login-callback/'),
      enabledMethods: const {
        AccountSignInMethod.emailLink,
        AccountSignInMethod.google,
      },
    );
  });

  tearDown(() async {
    await repository.dispose();
    await gateway.dispose();
  });

  test('sends a magic link and maps the returned Supabase identity', () async {
    final sessions = <AccountSession>[];
    final subscription = repository.watchSession().listen(sessions.add);
    await Future<void>.delayed(Duration.zero);

    final result = await repository.beginSignIn(
      AccountSignInMethod.emailLink,
      email: ' player@example.com ',
    );
    await Future<void>.delayed(Duration.zero);

    expect(result, AuthStartResult.emailLinkSent);
    expect(gateway.sentEmail, 'player@example.com');
    expect(
      gateway.redirectUri,
      Uri.parse('com.guitarpal.app://login-callback/'),
    );
    expect(sessions.last.status, AccountSessionStatus.authenticating);
    expect(sessions.last.signInMethod, AccountSignInMethod.emailLink);

    gateway.emit(
      const SupabaseAuthIdentity(
        userId: 'user-1',
        email: 'player@example.com',
        displayName: '练习者',
        signInMethod: AccountSignInMethod.emailLink,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(sessions.last.status, AccountSessionStatus.signedIn);
    expect(sessions.last.userId, 'user-1');
    expect(sessions.last.displayName, '练习者');
    await subscription.cancel();
  });

  test('opens Google OAuth and restores local state after a failure', () async {
    final success = await repository.beginSignIn(AccountSignInMethod.google);
    expect(success, AuthStartResult.browserOpened);
    expect(gateway.googleOpenCount, 1);

    gateway.failGoogle = true;
    await expectLater(
      repository.beginSignIn(AccountSignInMethod.google),
      throwsA(isA<AuthOperationException>()),
    );
    expect(
      (await repository.watchSession().first).status,
      AccountSessionStatus.local,
    );
  });

  test('rejects methods that are not enabled', () async {
    await expectLater(
      repository.beginSignIn(AccountSignInMethod.apple),
      throwsA(isA<AuthUnavailableException>()),
    );
  });
}

final class _FakeSupabaseAuthGateway implements SupabaseAuthGateway {
  final _identities = StreamController<SupabaseAuthIdentity?>.broadcast();
  SupabaseAuthIdentity? _currentIdentity;
  String? sentEmail;
  Uri? redirectUri;
  int googleOpenCount = 0;
  bool failGoogle = false;

  @override
  SupabaseAuthIdentity? get currentIdentity => _currentIdentity;

  @override
  Future<void> openGoogleSignIn({required Uri redirectUri}) async {
    googleOpenCount += 1;
    this.redirectUri = redirectUri;
    if (failGoogle) throw StateError('provider disabled');
  }

  @override
  Future<void> sendEmailLink({
    required String email,
    required Uri redirectUri,
  }) async {
    sentEmail = email;
    this.redirectUri = redirectUri;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }

  @override
  Stream<SupabaseAuthIdentity?> watchIdentity() => _identities.stream;

  void emit(SupabaseAuthIdentity? identity) {
    _currentIdentity = identity;
    _identities.add(identity);
  }

  Future<void> dispose() => _identities.close();
}

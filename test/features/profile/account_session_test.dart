import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/data/local_only_auth_repository.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';

void main() {
  test('local-only repository exposes an explicit local session', () async {
    const repository = LocalOnlyAuthRepository();

    final session = await repository.watchSession().first;

    expect(session.status, AccountSessionStatus.local);
    expect(session.isSignedIn, isFalse);
    expect(session.label, '本地模式');
    expect(repository.availableMethods, isEmpty);
  });

  test('signed-in session normalizes identity fields', () {
    final session = AccountSession.signedIn(
      userId: '  user-1  ',
      email: '  player@example.com ',
      displayName: '  木吉他练习者  ',
      signInMethod: AccountSignInMethod.google,
    );

    expect(session.status, AccountSessionStatus.signedIn);
    expect(session.isSignedIn, isTrue);
    expect(session.userId, 'user-1');
    expect(session.email, 'player@example.com');
    expect(session.label, '木吉他练习者');
    expect(session.signInMethod, AccountSignInMethod.google);
  });

  test('account identity rejects an empty stable user id', () {
    expect(() => AccountSession.signedIn(userId: '   '), throwsArgumentError);
    expect(() => AccountSession.expired(userId: ''), throwsArgumentError);
  });
}

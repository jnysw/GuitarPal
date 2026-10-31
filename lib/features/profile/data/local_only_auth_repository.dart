import '../application/auth_repository.dart';
import '../domain/account_session.dart';

class LocalOnlyAuthRepository implements AuthRepository {
  const LocalOnlyAuthRepository();

  @override
  Set<AccountSignInMethod> get availableMethods => const {};

  @override
  Stream<AccountSession> watchSession() =>
      Stream.value(const AccountSession.local());

  @override
  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  }) {
    throw const AuthUnavailableException();
  }

  @override
  Future<void> signOut() async {}
}

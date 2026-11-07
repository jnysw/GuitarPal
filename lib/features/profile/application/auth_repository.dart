import '../domain/account_session.dart';

abstract interface class AuthRepository {
  Stream<AccountSession> watchSession();

  Set<AccountSignInMethod> get availableMethods;

  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  });

  Future<void> signOut();
}

enum AuthStartResult { emailLinkSent, browserOpened }

class AuthUnavailableException implements Exception {
  const AuthUnavailableException([this.message = '登录服务尚未配置']);

  final String message;

  @override
  String toString() => message;
}

class AuthOperationException implements Exception {
  const AuthOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

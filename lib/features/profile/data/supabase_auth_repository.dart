import 'dart:async';

import '../application/auth_repository.dart';
import '../domain/account_session.dart';
import 'supabase_auth_gateway.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseAuthGateway gateway,
    required this._redirectUri,
    required Set<AccountSignInMethod> enabledMethods,
  }) : _gateway = gateway,
       _availableMethods = Set.unmodifiable(enabledMethods),
       _current = _toSession(gateway.currentIdentity) {
    _subscription = _gateway.watchIdentity().listen(
      (identity) => _setSession(_toSession(identity)),
      onError: (_) {
        if (_current.isSignedIn) {
          _setSession(
            AccountSession.expired(
              userId: _current.userId!,
              email: _current.email,
              displayName: _current.displayName,
              signInMethod: _current.signInMethod,
            ),
          );
        }
      },
    );
  }

  final SupabaseAuthGateway _gateway;
  final Uri _redirectUri;
  final Set<AccountSignInMethod> _availableMethods;
  final _sessions = StreamController<AccountSession>.broadcast();
  late final StreamSubscription<SupabaseAuthIdentity?> _subscription;
  AccountSession _current;

  @override
  Set<AccountSignInMethod> get availableMethods => _availableMethods;

  @override
  Stream<AccountSession> watchSession() async* {
    yield _current;
    yield* _sessions.stream;
  }

  @override
  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  }) async {
    if (!_availableMethods.contains(method)) {
      throw const AuthUnavailableException('该登录方式尚未配置');
    }
    _setSession(AccountSession.authenticating(signInMethod: method));
    try {
      switch (method) {
        case AccountSignInMethod.emailLink:
          final normalizedEmail = email?.trim();
          if (normalizedEmail == null || normalizedEmail.isEmpty) {
            throw const AuthOperationException('请输入邮箱地址');
          }
          await _gateway.sendEmailLink(
            email: normalizedEmail,
            redirectUri: _redirectUri,
          );
          return AuthStartResult.emailLinkSent;
        case AccountSignInMethod.google:
          await _gateway.openGoogleSignIn(redirectUri: _redirectUri);
          return AuthStartResult.browserOpened;
        case AccountSignInMethod.apple:
          throw const AuthUnavailableException('Apple 登录尚未配置');
      }
    } on AuthUnavailableException {
      _restoreCurrentIdentity();
      rethrow;
    } on AuthOperationException {
      _restoreCurrentIdentity();
      rethrow;
    } on Object {
      _restoreCurrentIdentity();
      throw const AuthOperationException('登录请求失败，请检查网络或认证服务配置');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _gateway.signOut();
      _setSession(const AccountSession.local());
    } on Object {
      throw const AuthOperationException('退出登录失败，请稍后重试');
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _sessions.close();
  }

  void _restoreCurrentIdentity() {
    _setSession(_toSession(_gateway.currentIdentity));
  }

  void _setSession(AccountSession value) {
    _current = value;
    if (!_sessions.isClosed) _sessions.add(value);
  }
}

AccountSession _toSession(SupabaseAuthIdentity? identity) {
  if (identity == null) return const AccountSession.local();
  return AccountSession.signedIn(
    userId: identity.userId,
    email: identity.email,
    displayName: identity.displayName,
    signInMethod: identity.signInMethod,
  );
}

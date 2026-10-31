import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_session.dart';

class SupabaseAuthIdentity {
  const SupabaseAuthIdentity({
    required this.userId,
    required this.signInMethod,
    this.email,
    this.displayName,
  });

  final String userId;
  final String? email;
  final String? displayName;
  final AccountSignInMethod? signInMethod;
}

abstract interface class SupabaseAuthGateway {
  SupabaseAuthIdentity? get currentIdentity;

  Stream<SupabaseAuthIdentity?> watchIdentity();

  Future<void> sendEmailLink({required String email, required Uri redirectUri});

  Future<void> openGoogleSignIn({required Uri redirectUri});

  Future<void> signOut();
}

class SupabaseSdkAuthGateway implements SupabaseAuthGateway {
  const SupabaseSdkAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  SupabaseAuthIdentity? get currentIdentity =>
      _toIdentity(_client.auth.currentSession);

  @override
  Stream<SupabaseAuthIdentity?> watchIdentity() {
    return _client.auth.onAuthStateChange.map(
      (state) => _toIdentity(state.session),
    );
  }

  @override
  Future<void> sendEmailLink({
    required String email,
    required Uri redirectUri,
  }) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectUri.toString(),
    );
  }

  @override
  Future<void> openGoogleSignIn({required Uri redirectUri}) async {
    final opened = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUri.toString(),
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('无法打开系统浏览器');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

SupabaseAuthIdentity? _toIdentity(Session? session) {
  if (session == null) return null;
  final user = session.user;
  final metadata = user.userMetadata ?? const <String, dynamic>{};
  final displayName = _firstNonEmpty([
    metadata['full_name'],
    metadata['name'],
    metadata['preferred_username'],
  ]);
  return SupabaseAuthIdentity(
    userId: user.id,
    email: user.email,
    displayName: displayName,
    signInMethod: _methodFromProvider(user.appMetadata['provider']),
  );
}

String? _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = value?.toString().trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

AccountSignInMethod? _methodFromProvider(Object? provider) {
  return switch (provider?.toString()) {
    'email' => AccountSignInMethod.emailLink,
    'google' => AccountSignInMethod.google,
    'apple' => AccountSignInMethod.apple,
    _ => null,
  };
}

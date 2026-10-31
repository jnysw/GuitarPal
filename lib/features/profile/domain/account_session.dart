enum AccountSessionStatus { local, authenticating, signedIn, expired }

enum AccountSignInMethod { emailLink, google, apple }

class AccountSession {
  const AccountSession._({
    required this.status,
    this.userId,
    this.email,
    this.displayName,
    this.signInMethod,
  });

  const AccountSession.local() : this._(status: AccountSessionStatus.local);

  const AccountSession.authenticating({AccountSignInMethod? signInMethod})
    : this._(
        status: AccountSessionStatus.authenticating,
        signInMethod: signInMethod,
      );

  factory AccountSession.signedIn({
    required String userId,
    String? email,
    String? displayName,
    AccountSignInMethod? signInMethod,
  }) {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    return AccountSession._(
      status: AccountSessionStatus.signedIn,
      userId: normalizedId,
      email: _normalizeOptional(email),
      displayName: _normalizeOptional(displayName),
      signInMethod: signInMethod,
    );
  }

  factory AccountSession.expired({
    required String userId,
    String? email,
    String? displayName,
    AccountSignInMethod? signInMethod,
  }) {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    return AccountSession._(
      status: AccountSessionStatus.expired,
      userId: normalizedId,
      email: _normalizeOptional(email),
      displayName: _normalizeOptional(displayName),
      signInMethod: signInMethod,
    );
  }

  final AccountSessionStatus status;
  final String? userId;
  final String? email;
  final String? displayName;
  final AccountSignInMethod? signInMethod;

  bool get isSignedIn => status == AccountSessionStatus.signedIn;

  String get label => switch (status) {
    AccountSessionStatus.local => '本地模式',
    AccountSessionStatus.authenticating => '正在登录',
    AccountSessionStatus.signedIn => displayName ?? email ?? 'GuitarPal 用户',
    AccountSessionStatus.expired => '登录已过期',
  };
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

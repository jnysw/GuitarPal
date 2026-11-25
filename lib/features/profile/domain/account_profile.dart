class AccountProfile {
  const AccountProfile({
    required this.userId,
    this.handle,
    this.avatarPath,
    this.revision,
  });

  final String userId;
  final String? handle;
  final String? avatarPath;
  final int? revision;

  static const handleHint = '3–20 位字母、数字或下划线，首位用字母或数字';
  static final _handlePattern = RegExp(r'^[a-z0-9][a-z0-9_]{2,19}$');

  static String normalizeHandle(String value) => value.trim().toLowerCase();

  static String? validateHandle(String value) {
    final handle = normalizeHandle(value);
    return handle.isEmpty || _handlePattern.hasMatch(handle)
        ? null
        : handleHint;
  }
}

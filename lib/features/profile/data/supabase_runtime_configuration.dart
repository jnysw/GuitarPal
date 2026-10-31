import '../domain/account_session.dart';

class SupabaseRuntimeConfiguration {
  const SupabaseRuntimeConfiguration({
    required this.projectUrl,
    required this.publishableKey,
    required this.enableGoogle,
  });

  factory SupabaseRuntimeConfiguration.fromEnvironment() {
    return const SupabaseRuntimeConfiguration(
      projectUrl: String.fromEnvironment('SUPABASE_URL'),
      publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      enableGoogle: bool.fromEnvironment('SUPABASE_ENABLE_GOOGLE'),
    );
  }

  static final Uri redirectUri = Uri.parse(
    'com.guitarpal.app://login-callback/',
  );

  final String projectUrl;
  final String publishableKey;
  final bool enableGoogle;

  bool get isConfigured =>
      projectUrl.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  Set<AccountSignInMethod> get enabledMethods => {
    AccountSignInMethod.emailLink,
    if (enableGoogle) AccountSignInMethod.google,
  };

  void validate() {
    final normalizedUrl = Uri.tryParse(projectUrl.trim());
    if (normalizedUrl == null ||
        normalizedUrl.scheme != 'https' ||
        normalizedUrl.host.isEmpty ||
        normalizedUrl.userInfo.isNotEmpty ||
        normalizedUrl.hasFragment) {
      throw const FormatException('SUPABASE_URL 必须是有效的 HTTPS 项目地址');
    }
    if (!publishableKey.trim().startsWith('sb_publishable_')) {
      throw const FormatException('必须使用 Supabase publishable key');
    }
  }
}

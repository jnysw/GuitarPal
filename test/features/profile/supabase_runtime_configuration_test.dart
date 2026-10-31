import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';
import 'package:guitar_pal/features/profile/data/supabase_runtime_configuration.dart';

void main() {
  test('enables email and only explicitly configured social providers', () {
    const emailOnly = SupabaseRuntimeConfiguration(
      projectUrl: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_example',
      enableGoogle: false,
    );
    const withGoogle = SupabaseRuntimeConfiguration(
      projectUrl: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_example',
      enableGoogle: true,
    );

    emailOnly.validate();
    withGoogle.validate();
    expect(emailOnly.enabledMethods, {AccountSignInMethod.emailLink});
    expect(withGoogle.enabledMethods, {
      AccountSignInMethod.emailLink,
      AccountSignInMethod.google,
    });
  });

  test('rejects database URLs and non-publishable keys', () {
    const databaseUrl = SupabaseRuntimeConfiguration(
      projectUrl: 'postgresql://db.example.com/postgres',
      publishableKey: 'sb_publishable_example',
      enableGoogle: false,
    );
    const secretKey = SupabaseRuntimeConfiguration(
      projectUrl: 'https://project.supabase.co',
      publishableKey: 'sb_secret_example',
      enableGoogle: false,
    );

    expect(databaseUrl.validate, throwsFormatException);
    expect(secretKey.validate, throwsFormatException);
  });
}

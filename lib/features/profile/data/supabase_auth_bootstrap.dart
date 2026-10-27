import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_supabase_storage.dart';
import 'supabase_auth_gateway.dart';
import 'supabase_auth_repository.dart';
import 'supabase_runtime_configuration.dart';

class SupabaseAuthBootstrap {
  const SupabaseAuthBootstrap._();

  static Future<SupabaseAuthRepository?> initialize(
    SupabaseRuntimeConfiguration configuration,
  ) async {
    if (!configuration.isConfigured) return null;
    configuration.validate();
    final redirectUri = SupabaseRuntimeConfiguration.redirectUri;
    await Supabase.initialize(
      url: configuration.projectUrl.trim(),
      publishableKey: configuration.publishableKey.trim(),
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: const SecureSupabaseLocalStorage(),
        pkceAsyncStorage: const SecureSupabasePkceStorage(),
        detectSessionInUriPredicate: (uri) =>
            uri.scheme == redirectUri.scheme &&
            uri.host == redirectUri.host &&
            uri.path == redirectUri.path,
      ),
    );
    return SupabaseAuthRepository(
      gateway: SupabaseSdkAuthGateway(Supabase.instance.client),
      redirectUri: redirectUri,
      enabledMethods: configuration.enabledMethods,
    );
  }
}

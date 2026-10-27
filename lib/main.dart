import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/profile/account_providers.dart';
import 'features/profile/data/supabase_auth_bootstrap.dart';
import 'features/profile/data/supabase_auth_repository.dart';
import 'features/profile/data/supabase_runtime_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseAuthRepository? authRepository;
  try {
    authRepository = await SupabaseAuthBootstrap.initialize(
      SupabaseRuntimeConfiguration.fromEnvironment(),
    );
  } on Object {
    debugPrint('Supabase authentication is unavailable; using local mode.');
  }
  final configuredAuthRepository = authRepository;
  // run 用于启动Flutter UI，GuitarPalApp是整颗界面树的根。
  // ProviderScope 是Riverpod的状态管理容器，类似一个带自动刷新能力的依赖注入容器
  // const表示对象内容在编译时确定，可以减少不必要对象创建。提升性能。
  runApp(
    ProviderScope(
      overrides: [
        if (configuredAuthRepository != null)
          authRepositoryProvider.overrideWith((ref) {
            ref.onDispose(configuredAuthRepository.dispose);
            return configuredAuthRepository;
          }),
      ],
      child: const GuitarPalApp(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inbox/share_intent_coordinator.dart';
import '../features/plans/practice_reminder_providers.dart';
import '../features/profile/app_settings_providers.dart';
import '../features/profile/domain/app_settings.dart';
import 'router.dart';
import 'theme/app_theme.dart';

// 定义全局应用
class GuitarPalApp extends ConsumerWidget {
  const GuitarPalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? AppSettings.defaults;
    return MaterialApp.router(
      title: 'GuitarPal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (settings.themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      routerConfig: appRouter,
      builder: (context, child) => PracticeReminderCoordinator(
        child: ShareIntentCoordinator(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

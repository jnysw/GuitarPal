import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/app_settings_controller.dart';
import 'application/app_settings_repository.dart';
import 'data/method_channel_app_settings_repository.dart';
import 'domain/app_settings.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return const MethodChannelAppSettingsRepository();
});

final appSettingsControllerProvider = Provider<AppSettingsController>((ref) {
  final controller = AppSettingsController(
    ref.watch(appSettingsRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(appSettingsControllerProvider).watch();
});

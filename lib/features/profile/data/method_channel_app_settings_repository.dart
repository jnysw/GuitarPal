import 'package:flutter/services.dart';

import '../application/app_settings_repository.dart';
import '../domain/app_settings.dart';

class MethodChannelAppSettingsRepository implements AppSettingsRepository {
  const MethodChannelAppSettingsRepository([
    this._channel = const MethodChannel('com.guitarpal/app_settings'),
  ]);

  final MethodChannel _channel;

  @override
  Future<AppSettings> load() async {
    try {
      final values = await _channel.invokeMapMethod<String, Object?>('load');
      if (values == null) return AppSettings.defaults;
      final themeName = values['themeMode'];
      final speed = values['defaultPlaybackSpeed'];
      return AppSettings(
        themePreference: AppThemePreference.values.firstWhere(
          (value) => value.name == themeName,
          orElse: () => AppThemePreference.system,
        ),
        defaultPlaybackSpeed: speed is num && speed.isFinite
            ? speed.toDouble()
            : AppSettings.defaults.defaultPlaybackSpeed,
      );
    } on MissingPluginException {
      return AppSettings.defaults;
    } on PlatformException {
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _channel.invokeMethod<void>('save', {
        'themeMode': settings.themePreference.name,
        'defaultPlaybackSpeed': settings.defaultPlaybackSpeed,
      });
    } on MissingPluginException {
      // Non-Android builds retain the in-memory value for this app session.
    }
  }
}

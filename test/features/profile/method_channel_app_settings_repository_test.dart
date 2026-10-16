import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/data/method_channel_app_settings_repository.dart';
import 'package:guitar_pal/features/profile/domain/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guitarpal/app_settings_test');
  const repository = MethodChannelAppSettingsRepository(channel);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('loads native theme and precise playback speed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'load');
          return <String, Object?>{
            'themeMode': 'dark',
            'defaultPlaybackSpeed': 0.87,
          };
        });

    final settings = await repository.load();

    expect(settings.themePreference, AppThemePreference.dark);
    expect(settings.defaultPlaybackSpeed, 0.87);
  });

  test('sends both settings to native storage', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    await repository.save(
      AppSettings(
        themePreference: AppThemePreference.light,
        defaultPlaybackSpeed: 1.237,
      ),
    );

    expect(received?.method, 'save');
    expect(received?.arguments, {
      'themeMode': 'light',
      'defaultPlaybackSpeed': 1.24,
    });
  });

  test('falls back safely when native values are invalid', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'themeMode': 'unknown',
            'defaultPlaybackSpeed': 'fast',
          };
        });

    expect(await repository.load(), AppSettings.defaults);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/precise_playback_speed_control.dart';
import 'package:guitar_pal/features/profile/app_settings_providers.dart';
import 'package:guitar_pal/features/profile/app_settings_screen.dart';
import 'package:guitar_pal/features/profile/application/app_settings_repository.dart';
import 'package:guitar_pal/features/profile/domain/app_settings.dart';

void main() {
  testWidgets('edits theme, exact default speed, and restores defaults', (
    tester,
  ) async {
    final repository = _FakeAppSettingsRepository(
      AppSettings(
        themePreference: AppThemePreference.light,
        defaultPlaybackSpeed: 0.87,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AppSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('0.87x'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(repository.value.themePreference, AppThemePreference.dark);

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(PrecisePlaybackSpeedControlKeys.input),
      '0.83',
    );
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
    await tester.pumpAndSettle();

    expect(repository.value.defaultPlaybackSpeed, 0.83);
    expect(find.text('默认倍速已设为 0.83x'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('settings_restore_defaults')),
    );
    await tester.tap(find.byKey(const Key('settings_restore_defaults')));
    await tester.pumpAndSettle();

    expect(repository.value, AppSettings.defaults);
    expect(find.text('1.00x'), findsWidgets);
  });
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  _FakeAppSettingsRepository(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}

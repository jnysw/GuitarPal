import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/profile/application/app_settings_controller.dart';
import 'package:guitar_pal/features/profile/application/app_settings_repository.dart';
import 'package:guitar_pal/features/profile/domain/app_settings.dart';

void main() {
  test('loads saved settings and normalizes the default speed', () async {
    final repository = _FakeAppSettingsRepository(
      AppSettings(
        themePreference: AppThemePreference.dark,
        defaultPlaybackSpeed: 0.873,
      ),
    );
    final controller = AppSettingsController(repository);
    addTearDown(controller.dispose);

    await _waitFor(() => controller.current.themePreference.isDark);

    expect(controller.current.themePreference, AppThemePreference.dark);
    expect(controller.current.defaultPlaybackSpeed, 0.87);
  });

  test('persists precise changes and restores defaults', () async {
    final repository = _FakeAppSettingsRepository(AppSettings.defaults);
    final controller = AppSettingsController(repository);
    addTearDown(controller.dispose);
    await _waitFor(() => repository.loadCompleted);

    await controller.updateTheme(AppThemePreference.light);
    await controller.updateDefaultPlaybackSpeed(1.237);

    expect(repository.saved, hasLength(2));
    expect(repository.saved.last.themePreference, AppThemePreference.light);
    expect(repository.saved.last.defaultPlaybackSpeed, 1.24);

    await controller.restoreDefaults();
    expect(controller.current, AppSettings.defaults);
    expect(repository.saved.last, AppSettings.defaults);
  });

  test('rolls an optimistic change back when persistence fails', () async {
    final repository = _FakeAppSettingsRepository(AppSettings.defaults)
      ..saveError = StateError('disk unavailable');
    final controller = AppSettingsController(repository);
    addTearDown(controller.dispose);
    await _waitFor(() => repository.loadCompleted);

    await expectLater(
      controller.updateTheme(AppThemePreference.dark),
      throwsStateError,
    );

    expect(controller.current, AppSettings.defaults);
  });
}

extension on AppThemePreference {
  bool get isDark => this == AppThemePreference.dark;
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not reached');
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  _FakeAppSettingsRepository(this.value);

  AppSettings value;
  Object? saveError;
  bool loadCompleted = false;
  final List<AppSettings> saved = [];

  @override
  Future<AppSettings> load() async {
    loadCompleted = true;
    return value;
  }

  @override
  Future<void> save(AppSettings settings) async {
    final error = saveError;
    if (error != null) throw error;
    value = settings;
    saved.add(settings);
  }
}

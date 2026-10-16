import '../domain/app_settings.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

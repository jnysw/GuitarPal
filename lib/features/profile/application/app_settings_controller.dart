import 'dart:async';

import 'app_settings_repository.dart';
import '../domain/app_settings.dart';

class AppSettingsController {
  AppSettingsController(this._repository) {
    unawaited(_load());
  }

  final AppSettingsRepository _repository;
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();
  AppSettings _value = AppSettings.defaults;
  int _revision = 0;
  bool _disposed = false;

  AppSettings get current => _value;

  Stream<AppSettings> watch() async* {
    yield _value;
    yield* _changes.stream;
  }

  Future<void> updateTheme(AppThemePreference preference) {
    return _save(_value.copyWith(themePreference: preference));
  }

  Future<void> updateDefaultPlaybackSpeed(double speed) {
    return _save(_value.copyWith(defaultPlaybackSpeed: speed));
  }

  Future<void> restoreDefaults() => _save(AppSettings.defaults);

  Future<void> _load() async {
    final revision = _revision;
    final loaded = await _repository.load();
    if (_disposed || revision != _revision || loaded == _value) return;
    _value = loaded;
    _changes.add(loaded);
  }

  Future<void> _save(AppSettings next) async {
    if (next == _value) return;
    final previous = _value;
    final revision = ++_revision;
    _value = next;
    if (!_disposed) _changes.add(next);
    try {
      await _repository.save(next);
    } on Object {
      if (!_disposed && revision == _revision) {
        _value = previous;
        _changes.add(previous);
      }
      rethrow;
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_changes.close());
  }
}

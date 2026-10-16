import '../../../media/playback/playback_speed.dart';

enum AppThemePreference { system, light, dark }

class AppSettings {
  const AppSettings._({
    required this.themePreference,
    required this.defaultPlaybackSpeed,
  });

  factory AppSettings({
    AppThemePreference themePreference = AppThemePreference.system,
    double defaultPlaybackSpeed = 1.0,
  }) {
    return AppSettings._(
      themePreference: themePreference,
      defaultPlaybackSpeed: normalizePlaybackSpeed(defaultPlaybackSpeed),
    );
  }

  static const defaults = AppSettings._(
    themePreference: AppThemePreference.system,
    defaultPlaybackSpeed: 1.0,
  );

  final AppThemePreference themePreference;
  final double defaultPlaybackSpeed;

  AppSettings copyWith({
    AppThemePreference? themePreference,
    double? defaultPlaybackSpeed,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.themePreference == themePreference &&
        other.defaultPlaybackSpeed == defaultPlaybackSpeed;
  }

  @override
  int get hashCode => Object.hash(themePreference, defaultPlaybackSpeed);
}

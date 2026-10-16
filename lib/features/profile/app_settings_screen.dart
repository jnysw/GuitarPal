import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/playback/playback_speed.dart';
import '../player/widgets/precise_playback_speed_control.dart';
import 'app_settings_providers.dart';
import 'domain/app_settings.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  Future<void> _updateTheme(
    BuildContext context,
    WidgetRef ref,
    AppThemePreference preference,
  ) async {
    try {
      await ref.read(appSettingsControllerProvider).updateTheme(preference);
    } on Object {
      if (context.mounted) _showMessage(context, '主题设置保存失败，请稍后重试');
    }
  }

  Future<void> _updateSpeed(
    BuildContext context,
    WidgetRef ref,
    double speed,
  ) async {
    try {
      await ref
          .read(appSettingsControllerProvider)
          .updateDefaultPlaybackSpeed(speed);
      if (context.mounted) {
        _showMessage(context, '默认倍速已设为 ${formatPlaybackSpeed(speed)}');
      }
    } on Object {
      if (context.mounted) _showMessage(context, '默认倍速保存失败，请稍后重试');
    }
  }

  Future<void> _restoreDefaults(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appSettingsControllerProvider).restoreDefaults();
      if (context.mounted) _showMessage(context, '已恢复默认设置');
    } on Object {
      if (context.mounted) _showMessage(context, '恢复默认设置失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('暂时无法读取应用设置')),
          data: (value) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '外观',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '主题模式',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '跟随系统会随设备的浅色或深色外观自动切换。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<AppThemePreference>(
                              key: const Key('settings_theme_mode'),
                              segments: const [
                                ButtonSegment(
                                  value: AppThemePreference.system,
                                  label: Text('系统'),
                                ),
                                ButtonSegment(
                                  value: AppThemePreference.light,
                                  label: Text('浅色'),
                                ),
                                ButtonSegment(
                                  value: AppThemePreference.dark,
                                  label: Text('深色'),
                                ),
                              ],
                              selected: {value.themePreference},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) {
                                unawaited(
                                  _updateTheme(context, ref, selection.single),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '播放器',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '默认练习倍速',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '打开整曲练习时使用；打开已保存片段时仍优先使用片段自己的倍速。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            PrecisePlaybackSpeedControl(
                              key: const Key('settings_default_speed'),
                              enabled: true,
                              value: value.defaultPlaybackSpeed,
                              onChanged: (_) {},
                              onChangeEnd: (speed) =>
                                  unawaited(_updateSpeed(context, ref, speed)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      key: const Key('settings_restore_defaults'),
                      onPressed: () =>
                          unawaited(_restoreDefaults(context, ref)),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('恢复默认设置'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

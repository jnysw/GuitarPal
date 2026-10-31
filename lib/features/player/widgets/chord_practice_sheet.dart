import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media/playback/local_video_playback_controller.dart';
import '../../audio_tools/domain/video_chord_playback.dart';
import '../../chords/chord_providers.dart';
import '../../chords/data/chord_preferences.dart';
import 'guitar_chord_diagram.dart';

Future<void> saveChordPreferences(
  BuildContext context,
  WidgetRef ref,
  ChordPreferences value,
) async {
  final ok = await ref.read(chordPreferencesProvider.notifier).save(value);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('指法设置保存失败，本次显示仍有效'),
        action: SnackBarAction(
          label: '重试',
          onPressed: () => saveChordPreferences(
            context,
            ref,
            ref.read(chordPreferencesProvider).asData!.value,
          ),
        ),
      ),
    );
  }
}

class ChordPracticeSheet extends ConsumerWidget {
  const ChordPracticeSheet({
    super.key,
    required this.playback,
    required this.controller,
  });
  final VideoChordPlayback playback;
  final LocalVideoPlaybackController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chordPreferencesProvider);
    final prefs = state.asData?.value ?? ChordPreferences();
    return FractionallySizedBox(
      heightFactor: .85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '练习指法',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭指法设置',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.hasError)
                  Row(
                    children: [
                      const Expanded(child: Text('指法设置读取失败')),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(chordPreferencesProvider),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                SwitchListTile(
                  key: const Key('chord_show_diagrams'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示指法图'),
                  subtitle: const Text('开启后在视频旁显示，后续练习沿用'),
                  value: prefs.showDiagrams,
                  onChanged: state.hasValue
                      ? (v) => saveChordPreferences(
                          context,
                          ref,
                          prefs.copyWith(showDiagrams: v),
                        )
                      : null,
                ),
                SwitchListTile(
                  key: const Key('chord_left_handed'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('左手显示'),
                  subtitle: const Text('仅镜像图形，六弦仍为低音 E'),
                  value: prefs.leftHanded,
                  onChanged: state.hasValue
                      ? (v) => saveChordPreferences(
                          context,
                          ref,
                          prefs.copyWith(leftHanded: v),
                        )
                      : null,
                ),
                const Text(
                  '推荐指法使用标准定弦 E A D G B e，不代表原视频的演奏手型。切换指法不会修改识别结果或音频。',
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final current = playback.current(
                      controller.position.inMilliseconds,
                    );
                    return ChordVoicingCard(
                      rawLabel: current?.rawLabel,
                      displayLabel: current?.displayLabel ?? '—',
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '切换后的指法会记为该和弦的常用指法；点星标可恢复推荐。没有精确匹配时显示“暂未收录”，不自动替换为简化和弦。',
                ),
                TextButton(
                  onPressed: () async {
                    final license = await rootBundle.loadString(
                      'third_party/chords-db/LICENSE',
                    );
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('指法库来源与许可'),
                        content: SingleChildScrollView(
                          child: Text(
                            'chords-db · David Rubert\n固定版本 df06fa7b425cf5fd29485ff6591236b3557e3fac\n\n$license',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('数据来源与 MIT 许可'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChordVoicingCard extends ConsumerWidget {
  const ChordVoicingCard({
    super.key,
    required this.rawLabel,
    required this.displayLabel,
    this.compact = false,
    this.thumbnail = false,
  });
  final String? rawLabel;
  final String displayLabel;
  final bool compact, thumbnail;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chordPreferencesProvider);
    final prefs = state.asData?.value ?? ChordPreferences();
    final library = ref.watch(guitarChordLibraryProvider);
    if (thumbnail) {
      return SizedBox(
        width: compact ? 48 : 70,
        height: compact ? 57 : 83,
        child: library.when(
          loading: () => const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => IconButton(
            tooltip: '重试载入指法库',
            onPressed: () => ref.invalidate(guitarChordLibraryProvider),
            icon: const Icon(Icons.refresh),
          ),
          data: (data) {
            if (rawLabel == null || rawLabel == 'N' || rawLabel == 'X') {
              return const SizedBox.shrink();
            }
            final values = data.lookup(rawLabel!);
            if (values.isEmpty) {
              return Tooltip(
                message: '$displayLabel · 暂未收录精确指法',
                child: const Center(
                  child: Text('暂无指法', style: TextStyle(fontSize: 11)),
                ),
              );
            }
            final preferred = prefs.preferred[values.first.chordKey];
            final selected =
                values.where((v) => v.id == preferred).firstOrNull ??
                values.first;
            return Semantics(
              label: displayLabel,
              child: GuitarChordDiagram(
                voicing: selected,
                leftHanded: prefs.leftHanded,
                size: compact ? const Size(48, 57) : const Size(70, 83),
              ),
            );
          },
        ),
      );
    }
    return library.when(
      loading: () => const Text('正在载入离线指法…'),
      error: (_, _) => Row(
        children: [
          const Expanded(child: Text('指法库载入失败')),
          TextButton(
            onPressed: () => ref.invalidate(guitarChordLibraryProvider),
            child: const Text('重试'),
          ),
        ],
      ),
      data: (data) {
        if (rawLabel == null || rawLabel == 'N' || rawLabel == 'X') {
          return Text(
            rawLabel == 'N'
                ? '无和弦，不显示指法'
                : rawLabel == 'X'
                ? '未知和弦，不推荐指法'
                : '当前位置没有和弦',
          );
        }
        final values = data.lookup(rawLabel!);
        if (values.isEmpty) return Text('$displayLabel · 暂未收录精确指法');
        final key = values.first.chordKey;
        final saved = prefs.preferred[key];
        final found = values.indexWhere((v) => v.id == saved);
        final index = found < 0 ? 0 : found;
        final selected = values[index];
        Future<void> choose(int target) => saveChordPreferences(
          context,
          ref,
          prefs.copyWith(
            preferred: {...prefs.preferred, key: values[target].id},
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '推荐指法 · $displayLabel',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  key: const Key('chord_previous_voicing'),
                  tooltip: '上一种指法',
                  onPressed: state.hasValue && values.length > 1
                      ? () => choose((index - 1) % values.length)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${index + 1} / ${values.length}',
                  key: const Key('chord_voicing_index'),
                ),
                IconButton(
                  key: const Key('chord_next_voicing'),
                  tooltip: '下一种指法',
                  onPressed: state.hasValue && values.length > 1
                      ? () => choose((index + 1) % values.length)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  key: const Key('chord_favorite_voicing'),
                  tooltip: found >= 0 ? '恢复推荐指法' : '设为常用指法',
                  onPressed: state.hasValue
                      ? () {
                          final preferred = {...prefs.preferred};
                          if (found >= 0) {
                            preferred.remove(key);
                          } else {
                            preferred[key] = selected.id;
                          }
                          saveChordPreferences(
                            context,
                            ref,
                            prefs.copyWith(preferred: preferred),
                          );
                        }
                      : null,
                  icon: Icon(found >= 0 ? Icons.star : Icons.star_border),
                ),
              ],
            ),
            GuitarChordDiagram(
              voicing: selected,
              leftHanded: prefs.leftHanded,
              size: compact ? const Size(70, 83) : const Size(112, 132),
            ),
            if (!compact)
              Text(
                selected.description.isEmpty ? '标准定弦' : selected.description,
              ),
          ],
        );
      },
    );
  }
}

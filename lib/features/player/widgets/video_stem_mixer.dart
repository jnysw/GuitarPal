import 'package:flutter/material.dart';

import '../../audio_tools/domain/stem_mix_settings.dart';

/// Controls actual downloaded stems; transport remains owned by the video.
class VideoStemMixer extends StatelessWidget {
  const VideoStemMixer({
    super.key,
    required this.controls,
    required this.master,
    required this.enabled,
    required this.onMaster,
    required this.onChange,
    required this.onReset,
    this.supportsPan = true,
  });
  final Map<String, StemMixControl> controls;
  final double master;
  final bool enabled, supportsPan;
  final ValueChanged<double> onMaster;
  final void Function(String, StemMixControl) onChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              '播放混音台',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: enabled ? onReset : null,
            child: const Text('重置音轨'),
          ),
        ],
      ),
      Text('总音量 ${(master * 100).round()}%'),
      Slider(
        key: const Key('video_mix_master'),
        value: master,
        divisions: 100,
        label: '${(master * 100).round()}%',
        onChanged: enabled ? onMaster : null,
      ),
      const Text('静音关闭该轨；独奏仅播放选中的轨道，可同时选择多轨。'),
      for (final entry in controls.entries)
        _track(context, entry.key, entry.value),
    ],
  );

  Widget _track(BuildContext context, String id, StemMixControl c) {
    final soloElsewhere = controls.values.any((v) => v.solo) && !c.solo;
    final silent = c.muted || soloElsewhere || c.volume == 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(silent ? Icons.volume_off : Icons.multitrack_audio),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stemDisplayName(id),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${(c.volume * 100).round()}%'),
              ],
            ),
            Slider(
              key: Key('video_stem_volume_$id'),
              value: c.volume,
              divisions: 100,
              label: '${(c.volume * 100).round()}%',
              onChanged: enabled
                  ? (v) => onChange(id, c.copyWith(volume: v))
                  : null,
            ),
            Row(
              children: [
                FilterChip(
                  key: Key('video_stem_mute_$id'),
                  label: const Text('静音'),
                  selected: c.muted,
                  onSelected: enabled
                      ? (v) => onChange(id, c.copyWith(muted: v))
                      : null,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  key: Key('video_stem_solo_$id'),
                  label: const Text('独奏'),
                  selected: c.solo,
                  onSelected: enabled
                      ? (v) => onChange(
                          id,
                          c.copyWith(solo: v, muted: v ? false : c.muted),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                if (silent)
                  const Expanded(child: Text('当前无声', textAlign: TextAlign.end)),
              ],
            ),
            if (supportsPan)
              Row(
                children: [
                  const Text('左'),
                  Expanded(
                    child: Slider(
                      key: Key('video_stem_pan_$id'),
                      min: -1,
                      max: 1,
                      divisions: 100,
                      value: c.pan,
                      label: panLabel(c.pan),
                      onChanged: enabled
                          ? (v) => onChange(id, c.copyWith(pan: v))
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(panLabel(c.pan), textAlign: TextAlign.end),
                  ),
                  const Text(' 右'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String panLabel(double value) => value.abs() < .01
    ? '居中'
    : '${value < 0 ? '左' : '右'} ${(value.abs() * 100).round()}%';
String stemDisplayName(String id) =>
    const {
      'vocals': '人声',
      'drums': '鼓',
      'bass': '贝斯',
      'guitar': '吉他',
      'piano': '钢琴',
      'other': '其他',
      'instrumental': '伴奏',
    }[id] ??
    id;

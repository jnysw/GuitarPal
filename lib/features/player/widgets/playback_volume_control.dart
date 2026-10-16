import 'package:flutter/material.dart';

import '../../../media/playback/playback_volume.dart';

abstract final class PlaybackVolumeControlKeys {
  static const control = Key('playback_volume_control');
  static const mute = Key('playback_volume_mute');
  static const slider = Key('playback_volume_slider');
  static const value = Key('playback_volume_value');
}

/// Per-player volume control with one-percent precision and mute restore.
class PlaybackVolumeControl extends StatefulWidget {
  const PlaybackVolumeControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onChangeEnd,
    this.compact = false,
    this.sliderKey,
    super.key,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool compact;
  final Key? sliderKey;

  @override
  State<PlaybackVolumeControl> createState() => _PlaybackVolumeControlState();
}

class _PlaybackVolumeControlState extends State<PlaybackVolumeControl> {
  late double _draftValue = normalizePlaybackVolume(widget.value);
  double _lastAudibleValue = 1;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (_draftValue > 0) _lastAudibleValue = _draftValue;
  }

  @override
  void didUpdateWidget(covariant PlaybackVolumeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = normalizePlaybackVolume(widget.value);
    if (!_isDragging && next != _draftValue) {
      _draftValue = next;
      if (next > 0) _lastAudibleValue = next;
    }
  }

  void _preview(double value) {
    final normalized = normalizePlaybackVolume(value);
    setState(() {
      _draftValue = normalized;
      if (normalized > 0) _lastAudibleValue = normalized;
    });
    widget.onChanged(normalized);
  }

  void _finishDrag(double value) {
    final normalized = normalizePlaybackVolume(value);
    setState(() {
      _isDragging = false;
      _draftValue = normalized;
      if (normalized > 0) _lastAudibleValue = normalized;
    });
    widget.onChangeEnd?.call(normalized);
  }

  void _toggleMute() {
    final next = _draftValue == 0 ? _lastAudibleValue : 0.0;
    final normalized = normalizePlaybackVolume(next);
    setState(() => _draftValue = normalized);
    widget.onChanged(normalized);
    widget.onChangeEnd?.call(normalized);
  }

  IconData get _icon {
    if (_draftValue == 0) return Icons.volume_off_rounded;
    if (_draftValue < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final label = '媒体音量 ${formatPlaybackVolume(_draftValue)}';
    return Semantics(
      key: PlaybackVolumeControlKeys.control,
      container: true,
      explicitChildNodes: true,
      label: '媒体音量控制',
      child: Row(
        children: [
          IconButton(
            key: PlaybackVolumeControlKeys.mute,
            tooltip: _draftValue == 0 ? '恢复声音' : '静音',
            onPressed: widget.enabled ? _toggleMute : null,
            icon: Icon(_icon),
          ),
          Expanded(
            child: Slider(
              key: widget.sliderKey ?? PlaybackVolumeControlKeys.slider,
              value: _draftValue,
              min: minPlaybackVolume,
              max: maxPlaybackVolume,
              divisions: playbackVolumeDivisions,
              label: formatPlaybackVolume(_draftValue),
              semanticFormatterCallback: (value) =>
                  '媒体音量 ${formatPlaybackVolume(value)}',
              onChangeStart: widget.enabled
                  ? (_) => setState(() => _isDragging = true)
                  : null,
              onChanged: widget.enabled ? _preview : null,
              onChangeEnd: widget.enabled ? _finishDrag : null,
            ),
          ),
          if (!widget.compact)
            SizedBox(
              width: 48,
              child: Text(
                formatPlaybackVolume(_draftValue),
                key: PlaybackVolumeControlKeys.value,
                textAlign: TextAlign.end,
                semanticsLabel: label,
              ),
            ),
        ],
      ),
    );
  }
}

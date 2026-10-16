import 'package:flutter/material.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import '../../segments/presentation/practice_segment_progress_slider.dart';
import '../widgets/playback_volume_control.dart';

/// Compact transport controls shown over a local video in fullscreen mode.
class FullscreenLocalVideoControls extends StatelessWidget {
  const FullscreenLocalVideoControls({
    required this.position,
    required this.duration,
    required this.segments,
    required this.isPlaying,
    required this.enabled,
    required this.onPreviewPosition,
    required this.onSeek,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    this.onSegmentTap,
    this.volume = 1,
    this.volumeEnabled,
    this.onPreviewVolume,
    this.onVolumeChangeEnd,
    super.key,
  });

  static const containerKey = Key('local_video_fullscreen_controls');
  static const progressKey = Key('local_video_fullscreen_position_slider');
  static const playPauseKey = Key('local_video_fullscreen_play_pause');
  static const currentTimeKey = Key('local_video_fullscreen_current_time');
  static const durationKey = Key('local_video_fullscreen_duration');
  static const volumeKey = Key('local_video_fullscreen_volume_slider');

  final Duration position;
  final Duration duration;
  final List<PracticeSegment> segments;
  final bool isPlaying;
  final bool enabled;
  final ValueChanged<Duration> onPreviewPosition;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final ValueChanged<PracticeSegment>? onSegmentTap;
  final double volume;
  final bool? volumeEnabled;
  final ValueChanged<double>? onPreviewVolume;
  final ValueChanged<double>? onVolumeChangeEnd;

  @override
  Widget build(BuildContext context) {
    final overlayTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFB6C4FF),
        tertiary: Color(0xFFFFB77A),
        surface: Color(0xFF151515),
      ),
    );

    return Theme(
      data: overlayTheme,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Material(
            key: containerKey,
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PracticeSegmentProgressSlider(
                    duration: duration,
                    position: position,
                    segments: segments,
                    enabled: enabled,
                    sliderKey: progressKey,
                    semanticLabel: '全屏播放进度',
                    onChanged: (value) => onPreviewPosition(
                      Duration(milliseconds: value.round()),
                    ),
                    onChangeEnd: (value) =>
                        onSeek(Duration(milliseconds: value.round())),
                    onSegmentTap: onSegmentTap,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          key: currentTimeKey,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(duration),
                          key: durationKey,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: '后退 5 秒',
                        color: Colors.white,
                        onPressed: enabled ? onSeekBackward : null,
                        icon: const Icon(Icons.replay_5_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: playPauseKey,
                        tooltip: isPlaying ? '暂停' : '播放',
                        color: Colors.white,
                        onPressed: enabled ? onPlayPause : null,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 38,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '前进 5 秒',
                        color: Colors.white,
                        onPressed: enabled ? onSeekForward : null,
                        icon: const Icon(Icons.forward_5_rounded),
                      ),
                    ],
                  ),
                  PlaybackVolumeControl(
                    value: volume,
                    enabled:
                        (volumeEnabled ?? enabled) &&
                        onPreviewVolume != null &&
                        onVolumeChangeEnd != null,
                    compact: true,
                    sliderKey: volumeKey,
                    onChanged: onPreviewVolume ?? (_) {},
                    onChangeEnd: onVolumeChangeEnd,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final totalSeconds = safeDuration.inSeconds;
  final hours = totalSeconds ~/ Duration.secondsPerHour;
  final minutes =
      (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

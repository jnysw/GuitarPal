import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/presentation/fullscreen_local_video_controls.dart';

void main() {
  testWidgets('fullscreen controls expose time and a draggable progress bar', (
    tester,
  ) async {
    Duration? previewed;
    Duration? sought;
    double? previewedVolume;
    double? committedVolume;
    var playPauseCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullscreenLocalVideoControls(
            position: const Duration(seconds: 25),
            duration: const Duration(seconds: 100),
            segments: const [],
            isPlaying: false,
            enabled: true,
            onPreviewPosition: (value) => previewed = value,
            onSeek: (value) => sought = value,
            onPlayPause: () => playPauseCount++,
            onSeekBackward: () {},
            onSeekForward: () {},
            volume: 0.5,
            onPreviewVolume: (value) => previewedVolume = value,
            onVolumeChangeEnd: (value) => committedVolume = value,
          ),
        ),
      ),
    );

    expect(
      find.byKey(FullscreenLocalVideoControls.progressKey),
      findsOneWidget,
    );
    expect(find.text('0:25'), findsOneWidget);
    expect(find.text('1:40'), findsOneWidget);

    final sliderRect = tester.getRect(
      find.byKey(FullscreenLocalVideoControls.progressKey),
    );
    await tester.tapAt(
      Offset(sliderRect.left + sliderRect.width * 0.75, sliderRect.center.dy),
    );
    await tester.pumpAndSettle();

    expect(previewed, isNotNull);
    expect(sought, isNotNull);
    expect(sought!.inSeconds, inInclusiveRange(70, 80));

    await tester.tap(find.byKey(FullscreenLocalVideoControls.playPauseKey));
    expect(playPauseCount, 1);

    final volumeRect = tester.getRect(
      find.byKey(FullscreenLocalVideoControls.volumeKey),
    );
    await tester.tapAt(
      Offset(volumeRect.left + volumeRect.width * 0.25, volumeRect.center.dy),
    );
    await tester.pump();
    expect(previewedVolume, isNotNull);
    expect(committedVolume, isNotNull);
  });

  testWidgets('fullscreen progress and transport are disabled until ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullscreenLocalVideoControls(
            position: Duration.zero,
            duration: Duration.zero,
            segments: const [],
            isPlaying: false,
            enabled: false,
            onPreviewPosition: (_) => fail('preview should remain disabled'),
            onSeek: (_) => fail('seek should remain disabled'),
            onPlayPause: () => fail('play should remain disabled'),
            onSeekBackward: () => fail('rewind should remain disabled'),
            onSeekForward: () => fail('forward should remain disabled'),
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(FullscreenLocalVideoControls.progressKey),
    );
    expect(slider.onChanged, isNull);
    final playButton = tester.widget<IconButton>(
      find.byKey(FullscreenLocalVideoControls.playPauseKey),
    );
    expect(playButton.onPressed, isNull);
  });

  testWidgets('volume can remain available before media duration is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullscreenLocalVideoControls(
            position: Duration.zero,
            duration: Duration.zero,
            segments: const [],
            isPlaying: false,
            enabled: false,
            volume: 0.4,
            volumeEnabled: true,
            onPreviewVolume: (_) {},
            onVolumeChangeEnd: (_) {},
            onPreviewPosition: (_) {},
            onSeek: (_) {},
            onPlayPause: () {},
            onSeekBackward: () {},
            onSeekForward: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<Slider>(find.byKey(FullscreenLocalVideoControls.volumeKey))
          .onChanged,
      isNotNull,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(FullscreenLocalVideoControls.progressKey))
          .onChanged,
      isNull,
    );
  });
}

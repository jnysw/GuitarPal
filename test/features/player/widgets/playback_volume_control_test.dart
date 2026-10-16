import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/playback_volume_control.dart';

void main() {
  testWidgets('slider previews and commits one-percent volume', (tester) async {
    final previews = <double>[];
    final commits = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackVolumeControl(
            value: 0.5,
            enabled: true,
            onChanged: previews.add,
            onChangeEnd: commits.add,
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(PlaybackVolumeControlKeys.slider),
    );
    expect(slider.divisions, 100);
    expect(slider.semanticFormatterCallback!(0.236), '媒体音量 24%');

    final rect = tester.getRect(find.byKey(PlaybackVolumeControlKeys.slider));
    await tester.tapAt(Offset(rect.left + rect.width * 0.73, rect.center.dy));
    await tester.pump();

    expect(previews, isNotEmpty);
    expect(commits, isNotEmpty);
    expect(commits.last, closeTo(0.73, 0.03));
  });

  testWidgets('mute restores the last audible value', (tester) async {
    double? value;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PlaybackVolumeControl(
                value: value ?? 0.37,
                enabled: true,
                onChanged: (next) {
                  value = next;
                  rebuild(() {});
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(PlaybackVolumeControlKeys.mute));
    await tester.pump();
    expect(value, 0);
    expect(find.byTooltip('恢复声音'), findsOneWidget);

    await tester.tap(find.byKey(PlaybackVolumeControlKeys.mute));
    await tester.pump();
    expect(value, 0.37);
  });

  testWidgets('disabled volume cannot be changed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackVolumeControl(
            value: 1,
            enabled: false,
            onChanged: (_) => fail('volume should remain disabled'),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<Slider>(find.byKey(PlaybackVolumeControlKeys.slider))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(PlaybackVolumeControlKeys.mute))
          .onPressed,
      isNull,
    );
  });
}

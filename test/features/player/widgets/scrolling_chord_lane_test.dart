import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_chord_playback.dart';
import 'package:guitar_pal/features/player/widgets/scrolling_chord_lane.dart';

void main() {
  VideoChordPlayback data({int? zero, int count = 30, int stepMs = 1000}) =>
      VideoChordPlayback(
        LegacyChordResult.fromJson({
          'job_id': 'chords',
          'status': 'completed',
          'duration_seconds': count * stepMs / 1000,
          'key': 'C',
          'progression': '',
          'segments': [
            for (var i = 0; i < count; i++)
              {
                'chord': i.isEven ? 'C:maj' : 'A:min',
                'roman': '',
                'start': i * stepMs / 1000,
                'end': (i + 1) * stepMs / 1000,
              },
          ],
        }),
        VideoAnalysisBinding(
          sourceId: 's',
          path: '/video',
          sourceBytes: 1,
          modifiedMs: 1,
          sourceDurationMs: 700000,
          startMs: 3000,
          durationMs: count * stepMs + 2000,
          inputSha256: 'a' * 64,
          waveform: [],
          manualChordZeroMs: zero,
        ),
      );
  Widget app(
    VideoChordPlayback playback,
    int ms, {
    bool playing = false,
    bool compact = false,
    double scale = 1,
    ValueChanged<int>? seek,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: ScrollingChordLane(
              playback: playback,
              positionMs: ms,
              playing: playing,
              compact: compact,
              onSeek: seek ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  double offset(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(
        find.byKey(const Key('chord_follow_scroll')),
      )
      .controller!
      .offset;
  testWidgets(
    'scrolls within a held chord and snaps back on seek or A-B wrap using source time',
    (tester) async {
      final p = data();
      await tester.pumpWidget(app(p, 3250));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(10, .01));
      await tester.pumpWidget(app(p, 3500, playing: true));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(20, .01));
      await tester.pumpWidget(app(p, 11000));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(320, .01));
      await tester.pumpWidget(app(p, 3250));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(10, .01));
      final active = tester.widget<Material>(
        find.byKey(const Key('chord_follow_cell_0')),
      );
      expect(
        active.color,
        Theme.of(tester.element(find.byKey(const Key('chord_follow_cell_0'))))
            .colorScheme
            .primaryContainer,
      );
    },
  );
  testWidgets(
    'manual browsing pauses follow, new equivalent results preserve browsing, resume returns to playback',
    (tester) async {
      await tester.pumpWidget(app(data(), 4000));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('chord_follow_scroll')),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('回到当前'), findsOneWidget);
      final browsing = offset(tester);
      await tester.pumpWidget(app(data(), 4500));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(browsing, .01));
      await tester.tap(find.byKey(const Key('chord_lane_follow')));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(60, .01));
    },
  );
  testWidgets(
    'calibration adds source offset once, tapping a visible chord seeks original time',
    (tester) async {
      int? target;
      final p = data(zero: 4000);
      await tester.pumpWidget(app(p, 4500, seek: (ms) => target = ms));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(60, .01));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('chord_follow_cell_1')),
          matching: find.byType(InkWell),
        ),
      );
      expect(target, 5000);
    },
  );
  testWidgets(
    'long results render only the visible window and remain legible on compact large text',
    (tester) async {
      final p = data(count: 20000, stepMs: 29);
      await tester.pumpWidget(app(p, 303000, compact: true, scale: 2));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(12000, .01));
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'chord_follow_cell_',
                  ),
            )
            .evaluate()
            .length,
        lessThan(300),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

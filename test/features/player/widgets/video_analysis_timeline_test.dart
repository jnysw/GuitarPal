import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/video_analysis_timeline.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

void main() {
  testWidgets('waveform seek uses original video offset at every zoom', (
    tester,
  ) async {
    int? seek;
    await tester.pumpWidget(
      _host(
        VideoAnalysisTimeline(
          startMs: 3000,
          endMs: 11000,
          positionMs: 3000,
          waveform: const [.2, .8],
          onSeek: (v) => seek = v,
          onLoop: (_) {},
        ),
      ),
    );
    final waveform = find.byKey(const Key('video_analysis_waveform'));
    var rect = tester.getRect(waveform);
    await tester.tapAt(Offset(rect.left + rect.width / 2, rect.top + 85));
    expect(seek, 7000);
    await tester.tap(find.byTooltip('放大时间轴'));
    await tester.pumpAndSettle();
    rect = tester.getRect(waveform);
    await tester.tapAt(Offset(rect.left + 100, rect.top + 85));
    expect(seek, 4000); // 100px / 800px over the same 8s source interval.
    expect(find.text('2×'), findsOneWidget);
  });

  testWidgets(
    'chord range selection is explicit and preserves gaps in source time',
    (tester) async {
      int? seek;
      LoopRange? loop;
      await tester.pumpWidget(
        _host(
          VideoAnalysisTimeline(
            startMs: 3000,
            endMs: 11000,
            positionMs: 4500,
            waveform: const [.2],
            chords: const [
              VideoTimelineChord(startMs: 3250, endMs: 5000, label: 'C'),
              VideoTimelineChord(startMs: 7000, endMs: 10000, label: 'Am'),
            ],
            onSeek: (v) => seek = v,
            onLoop: (v) => loop = v,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('video_analysis_chord_3250')));
      await tester.pump();
      expect(seek, 3250);
      expect(loop, isNull); // Seeking does not silently change the user's A-B.
      await tester.longPress(
        find.byKey(const Key('video_analysis_chord_7000')),
      );
      await tester.pump();
      expect(seek, 3250);
      await tester.tap(find.byKey(const Key('video_analysis_selection_loop')));
      expect(loop!.start.inMilliseconds, 3250);
      expect(loop!.end.inMilliseconds, 10000);
    },
  );

  testWidgets('A-B handles preview then commit once and cannot cross', (
    tester,
  ) async {
    var commits = 0;
    LoopRange? updated;
    await tester.pumpWidget(
      _host(
        VideoAnalysisTimeline(
          startMs: 3000,
          endMs: 11000,
          positionMs: 3000,
          waveform: const [.2],
          loop: LoopRange(
            start: const Duration(milliseconds: 4000),
            end: const Duration(milliseconds: 8000),
          ),
          onSeek: (_) {},
          onLoop: (v) {
            commits++;
            updated = v;
          },
        ),
      ),
    );
    final a = find.byKey(const Key('video_analysis_handle_a'));
    final gesture = await tester.startGesture(tester.getCenter(a));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(commits, 0);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(commits, 1);
    expect(updated!.start.inMilliseconds, greaterThan(4000));
    expect(updated!.start, lessThan(updated!.end));
    expect(updated!.end.inMilliseconds, 8000);
  });

  testWidgets(
    'late chords remain reachable after 80 and user scroll suspends following',
    (tester) async {
      int? seek;
      var position = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return VideoAnalysisTimeline(
                startMs: 0,
                endMs: 100000,
                positionMs: position,
                waveform: const [.2],
                chords: List.generate(
                  100,
                  (i) => VideoTimelineChord(
                    startMs: i * 1000,
                    endMs: (i + 1) * 1000,
                    label: 'C$i',
                  ),
                ),
                onSeek: (v) => seek = v,
                onLoop: (_) {},
              );
            },
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('放大时间轴'));
        await tester.pumpAndSettle();
      }
      update(() => position = 91000);
      await tester.pumpAndSettle();
      final lateChord = find.byKey(const Key('video_analysis_chord_91000'));
      expect(lateChord, findsOneWidget);
      await tester.tap(lateChord);
      expect(seek, 91000);
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('video_analysis_timeline_scroll')),
          )
          .controller!;
      await tester.drag(
        find.byKey(const Key('video_analysis_timeline_scroll')),
        const Offset(180, 0),
      );
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isFalse,
      );
      update(() => position = 1000);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, 1));
    },
  );

  testWidgets('disabled timeline cannot seek or change a loop', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _host(
        VideoAnalysisTimeline(
          startMs: 0,
          endMs: 8000,
          positionMs: 0,
          waveform: const [.3],
          enabled: false,
          chords: const [
            VideoTimelineChord(startMs: 0, endMs: 8000, label: 'C'),
          ],
          onSeek: (_) => changes++,
          onLoop: (_) => changes++,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('video_analysis_chord_0')));
    final rect = tester.getRect(
      find.byKey(const Key('video_analysis_waveform')),
    );
    await tester.tapAt(Offset(rect.center.dx, rect.top + 85));
    expect(changes, 0);
  });
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

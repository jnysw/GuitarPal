import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_progress_slider.dart';

void main() {
  testWidgets('paints clipped ranges and exposes segment semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const sliderKey = Key('test_progress_slider');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: PracticeSegmentProgressSlider(
                duration: const Duration(seconds: 100),
                position: const Duration(seconds: 50),
                segments: [
                  _segment(
                    id: 'inside',
                    title: '完整片段',
                    start: const Duration(seconds: 10),
                    end: const Duration(seconds: 20),
                  ),
                  _segment(
                    id: 'clipped',
                    title: '末尾片段',
                    start: const Duration(seconds: 90),
                    end: const Duration(seconds: 120),
                  ),
                  _segment(
                    id: 'outside',
                    title: '范围外片段',
                    start: const Duration(seconds: 120),
                    end: const Duration(seconds: 130),
                  ),
                ],
                enabled: true,
                sliderKey: sliderKey,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byKey(sliderKey));
    expect(slider.value, 50000);
    expect(slider.max, 100000);
    expect(slider.label, '播放进度');
    expect(slider.semanticFormatterCallback!(50000), '0:50 / 1:40');

    expect(
      tester.widget<CustomPaint>(
        find.byKey(PracticeSegmentProgressSlider.markerLayerKey),
      ),
      isA<CustomPaint>(),
    );
    expect(find.semantics.byLabel('练习片段：完整片段，0:10 到 0:20'), findsOne);
    expect(find.semantics.byLabel('练习片段：末尾片段，1:30 到 1:40'), findsOne);
    expect(find.semantics.byLabel(RegExp('范围外片段')), findsNothing);
    semantics.dispose();
  });

  testWidgets('marker layer does not prevent slider interaction', (
    tester,
  ) async {
    const sliderKey = Key('interactive_progress_slider');
    double? changedValue;
    double? startValue;
    double? endValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: PracticeSegmentProgressSlider(
                duration: const Duration(seconds: 100),
                position: const Duration(seconds: 20),
                segments: [
                  _segment(
                    id: 'drag-through',
                    title: '拖动区域',
                    start: const Duration(seconds: 30),
                    end: const Duration(seconds: 80),
                  ),
                ],
                enabled: true,
                sliderKey: sliderKey,
                onChangeStart: (value) => startValue = value,
                onChanged: (value) => changedValue = value,
                onChangeEnd: (value) => endValue = value,
              ),
            ),
          ),
        ),
      ),
    );

    final sliderRect = tester.getRect(find.byKey(sliderKey));
    await tester.tapAt(
      Offset(sliderRect.left + sliderRect.width * 0.7, sliderRect.center.dy),
    );
    await tester.pumpAndSettle();

    expect(startValue, isNotNull);
    expect(changedValue, isNotNull);
    expect(endValue, isNotNull);
    expect(changedValue!, greaterThan(50000));
  });

  testWidgets('tapping a marker activates its segment without breaking drag', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const sliderKey = Key('clickable_segment_progress_slider');
    final segment = _segment(
      id: 'clickable',
      title: '可点击片段',
      start: const Duration(seconds: 30),
      end: const Duration(seconds: 40),
    );
    PracticeSegment? activated;
    var seekCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: PracticeSegmentProgressSlider(
                duration: const Duration(seconds: 100),
                position: const Duration(seconds: 10),
                segments: [segment],
                enabled: true,
                sliderKey: sliderKey,
                onChanged: (_) {},
                onChangeEnd: (_) => seekCount++,
                onSegmentTap: (value) => activated = value,
              ),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(sliderKey));
    final markerCenterX = rect.left + 24 + (rect.width - 48) * 0.35;
    await tester.tapAt(Offset(markerCenterX, rect.center.dy));
    await tester.pump();
    expect(activated?.id, 'clickable');
    expect(seekCount, 0);

    activated = null;
    await tester.dragFrom(
      Offset(markerCenterX, rect.center.dy),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(activated, isNull);

    final markerFinder = find.semantics.byLabel('练习片段：可点击片段，0:30 到 0:40');
    final markerSemantics = markerFinder.evaluate().single;
    expect(
      markerSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    activated = null;
    tester.semantics.tap(markerFinder);
    expect(activated?.id, 'clickable');
    semantics.dispose();
  });

  testWidgets('zero or negative duration is safe and disables callbacks', (
    tester,
  ) async {
    const zeroKey = Key('zero_duration_slider');
    const negativeKey = Key('negative_duration_slider');
    var callbackCount = 0;
    final segment = _segment(
      id: 'hidden',
      title: '不应绘制',
      start: Duration.zero,
      end: const Duration(seconds: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PracticeSegmentProgressSlider(
                duration: Duration.zero,
                position: const Duration(seconds: 10),
                segments: [segment],
                enabled: true,
                sliderKey: zeroKey,
                onChanged: (_) => callbackCount++,
              ),
              PracticeSegmentProgressSlider(
                duration: const Duration(seconds: -10),
                position: const Duration(seconds: -2),
                segments: [segment],
                enabled: true,
                sliderKey: negativeKey,
                onChanged: (_) => callbackCount++,
              ),
            ],
          ),
        ),
      ),
    );

    for (final key in [zeroKey, negativeKey]) {
      final slider = tester.widget<Slider>(find.byKey(key));
      expect(slider.value, 0);
      expect(slider.max, 1);
      expect(slider.onChanged, isNull);
      expect(slider.semanticFormatterCallback!(0), '0:00 / 0:00');
      await tester.tap(find.byKey(key));
    }
    await tester.pump();

    expect(callbackCount, 0);
  });

  testWidgets('position is clamped to the valid slider range', (tester) async {
    const beforeKey = Key('before_progress_slider');
    const afterKey = Key('after_progress_slider');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PracticeSegmentProgressSlider(
                duration: const Duration(seconds: 20),
                position: const Duration(seconds: -5),
                segments: const [],
                enabled: false,
                sliderKey: beforeKey,
                onChanged: (_) {},
              ),
              PracticeSegmentProgressSlider(
                duration: const Duration(seconds: 20),
                position: const Duration(seconds: 25),
                segments: const [],
                enabled: false,
                sliderKey: afterKey,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.widget<Slider>(find.byKey(beforeKey)).value, 0);
    expect(tester.widget<Slider>(find.byKey(afterKey)).value, 20000);
  });
}

PracticeSegment _segment({
  required String id,
  required String title,
  required Duration start,
  required Duration end,
}) {
  final now = DateTime.utc(2026, 10, 13);
  return PracticeSegment(
    id: id,
    sourceId: 'source-1',
    title: title,
    start: start,
    end: end,
    createdAt: now,
    updatedAt: now,
  );
}

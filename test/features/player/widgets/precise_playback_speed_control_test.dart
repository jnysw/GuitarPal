import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/precise_playback_speed_control.dart';
import 'package:guitar_pal/media/playback/playback_speed.dart';

void main() {
  testWidgets('uses the shared range, step, keys, and accessible labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _testApp(
        PrecisePlaybackSpeedControl(
          value: 1.237,
          enabled: true,
          onChanged: (_) {},
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(PrecisePlaybackSpeedControlKeys.slider),
    );
    expect(slider.value, 1.24);
    expect(slider.min, minPlaybackSpeed);
    expect(slider.max, maxPlaybackSpeed);
    expect(slider.divisions, playbackSpeedDivisions);
    expect(find.text('1.24x'), findsOneWidget);
    expect(find.semantics.byLabel('练习倍速控制'), findsOneWidget);
    expect(find.semantics.byLabel('当前倍速 1.24x，输入精确值'), findsOneWidget);
    expect(find.byKey(PrecisePlaybackSpeedControlKeys.decrement), findsOne);
    expect(find.byKey(PrecisePlaybackSpeedControlKeys.increment), findsOne);

    semantics.dispose();
  });

  testWidgets('step buttons and presets preview and commit exact values', (
    tester,
  ) async {
    final changed = <double>[];
    final committed = <double>[];

    await tester.pumpWidget(
      _testApp(
        PrecisePlaybackSpeedControl(
          value: 1,
          enabled: true,
          onChanged: changed.add,
          onChangeEnd: committed.add,
        ),
      ),
    );

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.increment));
    await tester.pump();
    expect(changed.last, 1.01);
    expect(committed.last, 1.01);
    expect(find.text('1.01x'), findsOneWidget);

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.decrement));
    await tester.pump();
    expect(changed.last, 1.00);
    expect(committed.last, 1.00);

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.preset(1.25)));
    await tester.pump();
    expect(changed.last, 1.25);
    expect(committed.last, 1.25);
  });

  testWidgets('slider previews repeatedly but commits only when drag ends', (
    tester,
  ) async {
    final changed = <double>[];
    final committed = <double>[];

    await tester.pumpWidget(
      _testApp(
        PrecisePlaybackSpeedControl(
          value: 1,
          enabled: true,
          presets: const [],
          onChanged: changed.add,
          onChangeEnd: committed.add,
        ),
      ),
    );

    await tester.drag(
      find.byKey(PrecisePlaybackSpeedControlKeys.slider),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(changed, isNotEmpty);
    expect(committed, hasLength(1));
    expect(
      changed.every((value) => value == normalizePlaybackSpeed(value)),
      isTrue,
    );
    expect(committed.single, normalizePlaybackSpeed(committed.single));
  });

  testWidgets('exact-value dialog validates and commits hundredths', (
    tester,
  ) async {
    final changed = <double>[];
    final committed = <double>[];

    await tester.pumpWidget(
      _testApp(
        PrecisePlaybackSpeedControl(
          value: 1,
          enabled: true,
          onChanged: changed.add,
          onChangeEnd: committed.add,
        ),
      ),
    );

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
    await tester.pumpAndSettle();
    expect(find.byKey(PrecisePlaybackSpeedControlKeys.dialog), findsOneWidget);

    await tester.enterText(
      find.byKey(PrecisePlaybackSpeedControlKeys.input),
      '1.378',
    );
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
    await tester.pump();
    expect(find.text('倍速最多保留两位小数'), findsOneWidget);
    expect(changed, isEmpty);

    await tester.enterText(
      find.byKey(PrecisePlaybackSpeedControlKeys.input),
      '1.37',
    );
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
    await tester.pumpAndSettle();

    expect(changed, [1.37]);
    expect(committed, [1.37]);
    expect(find.text('1.37x'), findsOneWidget);
  });

  testWidgets('disabled control cannot change or open exact input', (
    tester,
  ) async {
    final changed = <double>[];
    final committed = <double>[];

    await tester.pumpWidget(
      _testApp(
        PrecisePlaybackSpeedControl(
          value: 1,
          enabled: false,
          onChanged: changed.add,
          onChangeEnd: committed.add,
        ),
      ),
    );

    final slider = tester.widget<Slider>(
      find.byKey(PrecisePlaybackSpeedControlKeys.slider),
    );
    expect(slider.onChanged, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(PrecisePlaybackSpeedControlKeys.decrement),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(PrecisePlaybackSpeedControlKeys.increment),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.preset(1.25)));
    await tester.pump();

    expect(find.byKey(PrecisePlaybackSpeedControlKeys.dialog), findsNothing);
    expect(changed, isEmpty);
    expect(committed, isEmpty);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 440, child: child)),
    ),
  );
}

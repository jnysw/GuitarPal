import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/presentation/fullscreen_controls_visibility.dart';

void main() {
  testWidgets('starts visible and hides after the configured playing delay', (
    tester,
  ) async {
    final visibilityChanges = <bool>[];

    await tester.pumpWidget(
      _buildHost(
        isPlaying: true,
        autoHideDelay: const Duration(seconds: 1),
        onVisibilityChanged: visibilityChanges.add,
      ),
    );

    expect(_controlsOpacity(tester), 1);
    expect(
      find.byKey(FullscreenControlsVisibility.controlsKey),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 999));
    expect(_controlsOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_controlsOpacity(tester), 0);
    expect(visibilityChanges, [false]);
  });

  testWidgets('paused playback reveals controls and keeps them visible', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_VisibilityHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _VisibilityHarness(key: harnessKey, initiallyPlaying: true),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(_controlsOpacity(tester), 0);

    harnessKey.currentState!.setPlaying(false);
    await tester.pump();
    expect(_controlsOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 5));
    expect(_controlsOpacity(tester), 1);

    await tester.tap(find.byKey(FullscreenControlsVisibility.surfaceKey));
    await tester.pump();
    expect(_controlsOpacity(tester), 1);
  });

  testWidgets('video surface toggles controls while playing', (tester) async {
    final visibilityChanges = <bool>[];

    await tester.pumpWidget(
      _buildHost(
        isPlaying: true,
        autoHideDelay: const Duration(seconds: 10),
        onVisibilityChanged: visibilityChanges.add,
      ),
    );

    await tester.tap(find.byKey(FullscreenControlsVisibility.surfaceKey));
    await tester.pump();
    expect(_controlsOpacity(tester), 0);

    await tester.tap(find.byKey(FullscreenControlsVisibility.surfaceKey));
    await tester.pump();
    expect(_controlsOpacity(tester), 1);
    expect(visibilityChanges, [false, true]);
  });

  testWidgets('control interaction restarts the idle timer', (tester) async {
    var controlTapCount = 0;

    await tester.pumpWidget(
      _buildHost(
        isPlaying: true,
        autoHideDelay: const Duration(seconds: 1),
        controls: Align(
          alignment: Alignment.bottomCenter,
          child: ElevatedButton(
            key: const Key('test_fullscreen_control'),
            onPressed: () => controlTapCount++,
            child: const Text('Play control'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('test_fullscreen_control')));
    expect(controlTapCount, 1);

    await tester.pump(const Duration(milliseconds: 700));
    expect(_controlsOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 300));
    expect(_controlsOpacity(tester), 0);
  });

  testWidgets('exposes stable keys and visibility semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildHost(isPlaying: true, autoHideDelay: const Duration(seconds: 10)),
    );

    expect(
      find.byKey(FullscreenControlsVisibility.surfaceSemanticsKey),
      findsOneWidget,
    );
    expect(
      find.byKey(FullscreenControlsVisibility.controlsSemanticsKey),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.byKey(FullscreenControlsVisibility.surfaceSemanticsKey),
      ),
      matchesSemantics(label: '隐藏播放控制', isButton: true, hasTapAction: true),
    );

    await tester.tap(find.byKey(FullscreenControlsVisibility.surfaceKey));
    await tester.pump();

    expect(
      tester.getSemantics(
        find.byKey(FullscreenControlsVisibility.surfaceSemanticsKey),
      ),
      matchesSemantics(label: '显示播放控制', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('cancels pending timers when disposed', (tester) async {
    var visibilityChangeCount = 0;

    await tester.pumpWidget(
      _buildHost(
        isPlaying: true,
        autoHideDelay: const Duration(seconds: 1),
        onVisibilityChanged: (_) => visibilityChangeCount++,
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));

    expect(visibilityChangeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled host keeps controls visible without blocking surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FullscreenControlsVisibility(
            enabled: false,
            isPlaying: true,
            autoHideDelay: const Duration(milliseconds: 10),
            controls: const SizedBox(key: Key('disabled_host_controls')),
            child: const SizedBox(key: Key('disabled_host_media')),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(_controlsOpacity(tester), 1);
    expect(find.byKey(FullscreenControlsVisibility.surfaceKey), findsNothing);
    expect(find.byKey(const Key('disabled_host_media')), findsOneWidget);
  });
}

Widget _buildHost({
  required bool isPlaying,
  required Duration autoHideDelay,
  Widget controls = const Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      width: 200,
      height: 80,
      child: ColoredBox(color: Colors.red),
    ),
  ),
  ValueChanged<bool>? onVisibilityChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: FullscreenControlsVisibility(
        isPlaying: isPlaying,
        autoHideDelay: autoHideDelay,
        animationDuration: Duration.zero,
        onVisibilityChanged: onVisibilityChanged,
        controls: controls,
        child: const ColoredBox(color: Colors.black),
      ),
    ),
  );
}

double _controlsOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(
        find.byKey(FullscreenControlsVisibility.controlsKey),
      )
      .opacity;
}

class _VisibilityHarness extends StatefulWidget {
  const _VisibilityHarness({super.key, required this.initiallyPlaying});

  final bool initiallyPlaying;

  @override
  State<_VisibilityHarness> createState() => _VisibilityHarnessState();
}

class _VisibilityHarnessState extends State<_VisibilityHarness> {
  late bool _isPlaying = widget.initiallyPlaying;

  void setPlaying(bool value) => setState(() => _isPlaying = value);

  @override
  Widget build(BuildContext context) {
    return FullscreenControlsVisibility(
      isPlaying: _isPlaying,
      autoHideDelay: const Duration(seconds: 1),
      animationDuration: Duration.zero,
      controls: const Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: 200, height: 80),
      ),
      child: const ColoredBox(color: Colors.black),
    );
  }
}

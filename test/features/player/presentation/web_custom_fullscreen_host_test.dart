import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/presentation/web_custom_fullscreen_host.dart';

void main() {
  testWidgets('keeps the normal child mounted below the fullscreen overlay', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_FullscreenHarnessState>();
    final lifecycle = _ProbeLifecycle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _FullscreenHarness(key: harnessKey, lifecycle: lifecycle),
        ),
      ),
    );

    expect(lifecycle.initCount, 1);
    expect(lifecycle.disposeCount, 0);
    expect(find.text('normal player'), findsOneWidget);
    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsNothing);

    harnessKey.currentState!.showFullscreen();
    await tester.pump();

    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsOneWidget);
    expect(
      find.byKey(WebCustomFullscreenHost.fullscreenContentKey),
      findsOneWidget,
    );
    expect(find.text('custom web video'), findsOneWidget);
    expect(find.text('normal player'), findsOneWidget);
    expect(lifecycle.initCount, 1);
    expect(lifecycle.disposeCount, 0);

    harnessKey.currentState!.hideFullscreen();
    await tester.pump();

    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsNothing);
    expect(find.text('normal player'), findsOneWidget);
    expect(lifecycle.initCount, 1);
    expect(lifecycle.disposeCount, 0);
  });

  testWidgets('system back requests fullscreen exit without popping the page', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_FullscreenHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _FullscreenHarness(
            key: harnessKey,
            startFullscreen: true,
            clearFullscreenOnExit: true,
          ),
        ),
      ),
    );

    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(harnessKey.currentState!.exitRequestCount, 1);
    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsNothing);
    expect(find.text('normal player'), findsOneWidget);
    expect(find.byType(_FullscreenHarness), findsOneWidget);
  });

  testWidgets('exit button only delegates the exit request', (tester) async {
    final harnessKey = GlobalKey<_FullscreenHarnessState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _FullscreenHarness(key: harnessKey, startFullscreen: true),
        ),
      ),
    );

    await tester.tap(find.byKey(WebCustomFullscreenHost.exitButtonKey));
    await tester.pump();

    expect(harnessKey.currentState!.exitRequestCount, 1);
    expect(find.byType(_FullscreenHarness), findsOneWidget);
    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsOneWidget);
  });

  testWidgets('keeps the exit control inside landscape safe areas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 400),
            padding: EdgeInsets.only(top: 24, right: 20),
          ),
          child: Scaffold(
            body: WebCustomFullscreenHost(
              fullscreenChild: const ColoredBox(color: Colors.blue),
              onExitFullscreen: () {},
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(
      find.byKey(WebCustomFullscreenHost.exitButtonKey),
    );
    expect(buttonRect.top, greaterThanOrEqualTo(24));
    expect(buttonRect.right, lessThanOrEqualTo(780));
  });
}

class _FullscreenHarness extends StatefulWidget {
  const _FullscreenHarness({
    super.key,
    this.lifecycle,
    this.startFullscreen = false,
    this.clearFullscreenOnExit = false,
  });

  final _ProbeLifecycle? lifecycle;
  final bool startFullscreen;
  final bool clearFullscreenOnExit;

  @override
  State<_FullscreenHarness> createState() => _FullscreenHarnessState();
}

class _FullscreenHarnessState extends State<_FullscreenHarness> {
  late bool _isFullscreen = widget.startFullscreen;
  int exitRequestCount = 0;

  void showFullscreen() => setState(() => _isFullscreen = true);

  void hideFullscreen() => setState(() => _isFullscreen = false);

  void _requestExit() {
    exitRequestCount++;
    if (widget.clearFullscreenOnExit) {
      setState(() => _isFullscreen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebCustomFullscreenHost(
      fullscreenChild: _isFullscreen
          ? const ColoredBox(
              color: Colors.black,
              child: Center(child: Text('custom web video')),
            )
          : null,
      onExitFullscreen: _requestExit,
      child: _StatefulProbe(lifecycle: widget.lifecycle),
    );
  }
}

class _ProbeLifecycle {
  int initCount = 0;
  int disposeCount = 0;
}

class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe({this.lifecycle});

  final _ProbeLifecycle? lifecycle;

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle?.initCount++;
  }

  @override
  void dispose() {
    widget.lifecycle?.disposeCount++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: Text('normal player')),
    );
  }
}

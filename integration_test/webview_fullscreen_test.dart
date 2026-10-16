import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/presentation/web_custom_fullscreen_host.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'support/local_video_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HTML video fullscreen exits before the player route', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;

    final pageLoaded = Completer<void>();
    final customView = _CustomViewCoordinator();
    addTearDown(customView.dispose);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!pageLoaded.isCompleted) pageLoaded.complete();
          },
        ),
      );
    final androidController = controller.platform as AndroidWebViewController;
    await androidController.setCustomWidgetCallbacks(
      onShowCustomWidget: customView.show,
      onHideCustomWidget: customView.hideFromWebView,
    );
    await androidController.setMediaPlaybackRequiresUserGesture(false);
    await controller.loadRequest(_offlineVideoPage());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                key: const Key('open_offline_web_player'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _OfflineWebPlayer(
                        controller: controller,
                        customView: customView,
                      ),
                    ),
                  );
                },
                child: const Text('Open player'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_offline_web_player')));
    await tester.pump();
    await _waitUntil(
      tester,
      () => pageLoaded.isCompleted,
      failureMessage: 'Offline HTML video page did not finish loading.',
    );

    final webView = find.byKey(const Key('offline_webview'));
    expect(webView, findsOneWidget);
    final webViewRect = tester.getRect(webView);
    await tester.tapAt(Offset(webViewRect.center.dx, webViewRect.top + 40));
    await _waitUntil(
      tester,
      () =>
          customView.showCount == 1 &&
          find.byKey(WebCustomFullscreenHost.overlayKey).evaluate().isNotEmpty,
      failureMessage: 'Android WebView did not expose its custom view.',
    );

    expect(find.byKey(WebCustomFullscreenHost.overlayKey), findsOneWidget);
    expect(webView, findsOneWidget);

    await tester.binding.handlePopRoute();
    await _waitUntil(
      tester,
      () =>
          customView.exitRequestCount == 1 &&
          customView.hideCount == 1 &&
          find.byKey(WebCustomFullscreenHost.overlayKey).evaluate().isEmpty,
      failureMessage: 'Back did not close the WebView custom view cleanly.',
    );

    expect(webView, findsOneWidget);
    expect(find.byKey(const Key('open_offline_web_player')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_offline_web_player')), findsOneWidget);
  });
}

class _OfflineWebPlayer extends StatelessWidget {
  const _OfflineWebPlayer({required this.controller, required this.customView});

  final WebViewController controller;
  final _CustomViewCoordinator customView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: customView,
        builder: (context, _) => WebCustomFullscreenHost(
          fullscreenChild: customView.widget,
          onExitFullscreen: customView.requestExit,
          child: WebViewWidget(
            key: const Key('offline_webview'),
            controller: controller,
          ),
        ),
      ),
    );
  }
}

class _CustomViewCoordinator extends ChangeNotifier {
  Widget? widget;
  VoidCallback? _notifyHidden;
  int showCount = 0;
  int hideCount = 0;
  int exitRequestCount = 0;

  void show(Widget customWidget, VoidCallback onCustomWidgetHidden) {
    showCount++;
    widget = customWidget;
    _notifyHidden = onCustomWidgetHidden;
    notifyListeners();
  }

  void hideFromWebView() {
    hideCount++;
    widget = null;
    _notifyHidden = null;
    notifyListeners();
  }

  void requestExit() {
    if (widget == null) return;
    exitRequestCount++;
    widget = null;
    final notifyHidden = _notifyHidden;
    _notifyHidden = null;
    notifyListeners();
    notifyHidden?.call();
  }

  @override
  void dispose() {
    final notifyHidden = _notifyHidden;
    _notifyHidden = null;
    widget = null;
    notifyHidden?.call();
    super.dispose();
  }
}

Uri _offlineVideoPage() {
  final html =
      '''
<!doctype html>
<html>
<head>
  <meta name="viewport"
        content="width=device-width,initial-scale=1,maximum-scale=1">
  <style>
    html, body { margin: 0; width: 100%; height: 100%; background: #111; }
    #enter {
      width: 100%; height: 45vh; border: 0; background: #27ae60;
      color: white; font-size: 24px;
    }
    video { width: 100%; height: 50vh; }
  </style>
  <script>
    function enterFullscreen() {
      const video = document.getElementById('video');
      video.play().catch(() => {});
      video.requestFullscreen();
    }
  </script>
</head>
<body>
  <button id="enter" onclick="enterFullscreen()">Enter fullscreen</button>
  <video id="video" controls playsinline autoplay muted>
    <source type="video/mp4"
            src="data:video/mp4;charset=utf-8;base64,$localVideoFixtureBase64">
  </video>
</body>
</html>
''';
  return Uri.dataFromString(
    html,
    mimeType: 'text/html',
    encoding: utf8,
    base64: true,
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String failureMessage,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  fail(failureMessage);
}

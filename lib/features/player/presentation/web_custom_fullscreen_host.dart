import 'package:flutter/material.dart';

/// Keeps a web player mounted while presenting its native custom view on top.
///
/// Android WebView uses a custom view for HTML video fullscreen. Keeping
/// [child] in the tree avoids recreating the WebView (and losing playback
/// state) when that custom view is shown or hidden.
class WebCustomFullscreenHost extends StatelessWidget {
  const WebCustomFullscreenHost({
    required this.child,
    required this.fullscreenChild,
    required this.onExitFullscreen,
    super.key,
  });

  static const childKey = Key('web_custom_fullscreen_host_child');
  static const overlayKey = Key('web_custom_fullscreen_overlay');
  static const fullscreenContentKey = Key('web_custom_fullscreen_content');
  static const exitButtonKey = Key('web_custom_fullscreen_exit');

  /// The normal player page. It remains mounted while fullscreen is active.
  final Widget child;

  /// The custom view supplied by the WebView, or `null` when it is hidden.
  final Widget? fullscreenChild;

  /// Requests that the WebView hide its current custom view.
  ///
  /// This host deliberately does not pop a route. The owner is responsible
  /// for making this callback idempotent and clearing [fullscreenChild].
  final VoidCallback onExitFullscreen;

  @override
  Widget build(BuildContext context) {
    final customView = fullscreenChild;
    final isFullscreen = customView != null;

    return PopScope(
      canPop: !isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isFullscreen) {
          onExitFullscreen();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(key: childKey, child: child),
          if (customView != null)
            Positioned.fill(
              child: ColoredBox(
                key: overlayKey,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: KeyedSubtree(
                        key: fullscreenContentKey,
                        child: customView,
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: SafeArea(
                        minimum: const EdgeInsets.all(8),
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            key: exitButtonKey,
                            tooltip: '退出网页全屏',
                            color: Colors.white,
                            onPressed: onExitFullscreen,
                            icon: const Icon(Icons.fullscreen_exit_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

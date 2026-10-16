import 'dart:async';

import 'package:flutter/material.dart';

/// Hosts fullscreen video content and manages the visibility of its controls.
///
/// Controls start visible. While [isPlaying] is true, they are hidden after
/// [autoHideDelay]. A pointer interaction inside [controls] suspends that timer
/// until the interaction ends, then starts a fresh delay.
class FullscreenControlsVisibility extends StatefulWidget {
  const FullscreenControlsVisibility({
    required this.child,
    required this.controls,
    required this.isPlaying,
    this.enabled = true,
    this.autoHideDelay = const Duration(seconds: 3),
    this.animationDuration = const Duration(milliseconds: 160),
    this.onVisibilityChanged,
    this.showControlsSemanticLabel = '显示播放控制',
    this.hideControlsSemanticLabel = '隐藏播放控制',
    this.controlsSemanticLabel = '播放控制',
    super.key,
  });

  static const surfaceKey = Key('fullscreen_controls_visibility_surface');
  static const surfaceSemanticsKey = Key(
    'fullscreen_controls_visibility_surface_semantics',
  );
  static const controlsKey = Key('fullscreen_controls_visibility_controls');
  static const controlsSemanticsKey = Key(
    'fullscreen_controls_visibility_controls_semantics',
  );

  /// Video or other fullscreen media rendered below the controls.
  final Widget child;

  /// The complete control layer. Its own layout determines where it appears.
  final Widget controls;

  /// Whether playback is currently advancing.
  ///
  /// Pausing immediately reveals the controls and disables automatic hiding.
  final bool isPlaying;

  /// Whether surface taps and automatic hiding are active.
  ///
  /// Keeping the host mounted with this disabled lets platform video views
  /// retain their identity when entering and leaving fullscreen.
  final bool enabled;

  /// Idle time before controls are hidden during playback.
  final Duration autoHideDelay;

  /// Fade duration used when the control layer changes visibility.
  final Duration animationDuration;

  /// Called only when the managed visibility value changes.
  final ValueChanged<bool>? onVisibilityChanged;

  final String showControlsSemanticLabel;
  final String hideControlsSemanticLabel;
  final String controlsSemanticLabel;

  @override
  State<FullscreenControlsVisibility> createState() =>
      _FullscreenControlsVisibilityState();
}

class _FullscreenControlsVisibilityState
    extends State<FullscreenControlsVisibility> {
  Timer? _autoHideTimer;
  bool _controlsVisible = true;
  int _activeControlPointers = 0;

  @override
  void initState() {
    super.initState();
    _restartAutoHideTimer();
  }

  @override
  void didUpdateWidget(covariant FullscreenControlsVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.enabled) {
      _cancelAutoHideTimer();
      _setControlsVisible(true);
      return;
    }

    if (!widget.isPlaying) {
      _cancelAutoHideTimer();
      _setControlsVisible(true);
      return;
    }

    if (!oldWidget.enabled ||
        !oldWidget.isPlaying ||
        oldWidget.autoHideDelay != widget.autoHideDelay) {
      _restartAutoHideTimer();
    }
  }

  @override
  void dispose() {
    _cancelAutoHideTimer();
    super.dispose();
  }

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _restartAutoHideTimer() {
    _cancelAutoHideTimer();
    if (!widget.enabled ||
        !widget.isPlaying ||
        !_controlsVisible ||
        _activeControlPointers > 0) {
      return;
    }

    _autoHideTimer = Timer(widget.autoHideDelay, () {
      _autoHideTimer = null;
      if (!mounted ||
          !widget.enabled ||
          !widget.isPlaying ||
          _activeControlPointers > 0) {
        return;
      }
      _setControlsVisible(false);
    });
  }

  void _setControlsVisible(bool visible) {
    if (_controlsVisible == visible) {
      if (visible) {
        _restartAutoHideTimer();
      }
      return;
    }

    setState(() => _controlsVisible = visible);
    widget.onVisibilityChanged?.call(visible);
    if (visible) {
      _restartAutoHideTimer();
    } else {
      _cancelAutoHideTimer();
    }
  }

  void _handleSurfaceTap() {
    if (!widget.enabled) return;
    if (!widget.isPlaying) {
      _setControlsVisible(true);
      return;
    }
    _setControlsVisible(!_controlsVisible);
  }

  void _handleControlPointerDown(PointerDownEvent event) {
    _activeControlPointers++;
    _cancelAutoHideTimer();
    if (!_controlsVisible) {
      _setControlsVisible(true);
    }
  }

  void _handleControlPointerEnd(PointerEvent event) {
    if (_activeControlPointers > 0) {
      _activeControlPointers--;
    }
    if (_activeControlPointers == 0) {
      _restartAutoHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.enabled)
          Positioned.fill(
            child: Semantics(
              key: FullscreenControlsVisibility.surfaceSemanticsKey,
              button: true,
              label: _controlsVisible
                  ? widget.hideControlsSemanticLabel
                  : widget.showControlsSemanticLabel,
              onTap: _handleSurfaceTap,
              child: GestureDetector(
                key: FullscreenControlsVisibility.surfaceKey,
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: _handleSurfaceTap,
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              key: FullscreenControlsVisibility.controlsKey,
              opacity: _controlsVisible ? 1 : 0,
              duration: widget.animationDuration,
              child: TickerMode(
                enabled: _controlsVisible,
                child: ExcludeSemantics(
                  excluding: !_controlsVisible,
                  child: Semantics(
                    key: FullscreenControlsVisibility.controlsSemanticsKey,
                    container: true,
                    label: widget.controlsSemanticLabel,
                    child: Listener(
                      onPointerDown: _handleControlPointerDown,
                      onPointerUp: _handleControlPointerEnd,
                      onPointerCancel: _handleControlPointerEnd,
                      child: widget.controls,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

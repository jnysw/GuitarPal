import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../../features/segments/practice_segment_providers.dart';
import '../../features/segments/presentation/practice_segment_card.dart';
import '../../features/segments/presentation/practice_segment_editor_sheet.dart';
import '../../features/segments/presentation/practice_segment_progress_slider.dart';
import '../../features/segments/presentation/practice_segment_timecode.dart';
import '../../media/adapters/bilibili_player_uri_builder.dart';
import '../../media/playback/bilibili_web_playback_controller.dart';
import '../../media/playback/loop_controller.dart';
import '../library/practice_source_providers.dart';
import '../plans/application/practice_playback_session_recorder.dart';
import '../plans/practice_plan_providers.dart';
import '../recordings/presentation/practice_recording_panel.dart';
import 'presentation/fullscreen_controls_visibility.dart';
import 'presentation/fullscreen_local_video_controls.dart';
import 'presentation/web_custom_fullscreen_host.dart';
import 'widgets/playback_volume_control.dart';
import 'widgets/precise_playback_speed_control.dart';

class BilibiliWebPlayerScreen extends ConsumerStatefulWidget {
  const BilibiliWebPlayerScreen({
    required this.source,
    this.initialSegment,
    this.planId,
    this.defaultPlaybackSpeed = 1.0,
    super.key,
  });

  final PracticeSource source;
  final PracticeSegment? initialSegment;
  final String? planId;
  final double defaultPlaybackSpeed;

  @override
  ConsumerState<BilibiliWebPlayerScreen> createState() =>
      _BilibiliWebPlayerScreenState();
}

class _BilibiliWebPlayerScreenState
    extends ConsumerState<BilibiliWebPlayerScreen>
    with WidgetsBindingObserver {
  WebViewController? _webController;
  BilibiliWebPlaybackController? _playbackController;
  late final PracticePlaybackSessionRecorder _sessionRecorder;
  Uri? _playerUri;
  bool _didApplyInitialPlaybackState = false;
  bool _didPersistDuration = false;
  Widget? _webCustomFullscreenWidget;
  VoidCallback? _onWebCustomWidgetHidden;
  bool _isAppFullscreen = false;
  bool _fullscreenTransitionInProgress = false;
  bool _recordingWorkflowActive = false;
  bool _isDisposing = false;
  int _systemUiRevision = 0;

  @override
  void initState() {
    super.initState();
    _sessionRecorder = ref
        .read(practiceSessionServiceProvider)
        .trackPlayback(
          sourceId: widget.source.id,
          planId: widget.planId,
          segmentId: widget.initialSegment?.id,
        );
    WidgetsBinding.instance.addObserver(this);
    _playerUri = const BilibiliPlayerUriBuilder().build(widget.source);
    final uri = _playerUri;
    if (uri == null) return;

    final webController = WebViewController();
    final playbackController = BilibiliWebPlaybackController(
      _WebViewScriptExecutor(webController),
    );
    playbackController.addListener(_applyInitialPlaybackStateWhenReady);
    playbackController.addListener(_trackPlayback);
    webController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'GuitarPalPlayer',
        onMessageReceived: (message) {
          playbackController.onJavaScriptMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            return _isAllowedBilibiliNavigation(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) => playbackController.installBridge(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {});
            }
          },
        ),
      );

    unawaited(_configurePlatformAndLoad(webController, uri));

    _webController = webController;
    _playbackController = playbackController;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionRecorder.resume();
    } else {
      _sessionRecorder.suspend();
      unawaited(_checkpointSession());
      unawaited(_playbackController?.pause());
    }
  }

  Future<void> _configurePlatformAndLoad(
    WebViewController controller,
    Uri uri,
  ) async {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setCustomWidgetCallbacks(
        onShowCustomWidget: _showWebCustomWidget,
        onHideCustomWidget: _handleWebCustomWidgetHidden,
      );
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }
    await controller.loadRequest(uri);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposing = true;
    _systemUiRevision++;
    final notifyWebView = _takeWebCustomWidgetHiddenCallback();
    notifyWebView?.call();
    _trackPlayback();
    _playbackController?.removeListener(_applyInitialPlaybackStateWhenReady);
    _playbackController?.removeListener(_trackPlayback);
    _playbackController?.dispose();
    unawaited(_finishSession());
    if (_isAppFullscreen || _webCustomFullscreenWidget != null) {
      unawaited(_restoreSystemChrome());
    }
    super.dispose();
  }

  void _trackPlayback() {
    final controller = _playbackController;
    if (controller == null) return;
    _sessionRecorder.observe(
      isPlaying: controller.isPlaying,
      completedLoops: controller.loopController.totalCompletedLoops,
    );
  }

  Future<void> _finishSession() async {
    try {
      await _sessionRecorder.finish();
    } on Object {
      // Playback teardown must never trap the user on the player route.
    }
  }

  Future<void> _checkpointSession() async {
    try {
      await _sessionRecorder.checkpoint();
    } on Object {
      // A failed recovery snapshot must not interrupt lifecycle handling.
    }
  }

  void _showWebCustomWidget(Widget widget, VoidCallback onCustomWidgetHidden) {
    if (!mounted || _isDisposing) {
      onCustomWidgetHidden();
      return;
    }

    final previousCallback = _takeWebCustomWidgetHiddenCallback();
    previousCallback?.call();
    _onWebCustomWidgetHidden = onCustomWidgetHidden;
    setState(() => _webCustomFullscreenWidget = widget);
    unawaited(_syncSystemChrome());
  }

  void _handleWebCustomWidgetHidden() {
    _onWebCustomWidgetHidden = null;
    if (!mounted || _isDisposing) return;
    if (_webCustomFullscreenWidget != null) {
      setState(() => _webCustomFullscreenWidget = null);
    }
    unawaited(_syncSystemChrome());
  }

  void _requestExitWebCustomFullscreen() {
    if (_isDisposing) return;
    final notifyWebView = _takeWebCustomWidgetHiddenCallback();
    if (_webCustomFullscreenWidget != null && mounted) {
      setState(() => _webCustomFullscreenWidget = null);
    }
    notifyWebView?.call();
    unawaited(_syncSystemChrome());
  }

  VoidCallback? _takeWebCustomWidgetHiddenCallback() {
    final callback = _onWebCustomWidgetHidden;
    _onWebCustomWidgetHidden = null;
    return callback;
  }

  Future<void> _toggleAppFullscreen() async {
    if (_fullscreenTransitionInProgress) return;
    if (!_isAppFullscreen && _recordingWorkflowActive) {
      _showMessage('请先结束或保存当前录音，再进入全屏');
      return;
    }
    _fullscreenTransitionInProgress = true;
    final previous = _isAppFullscreen;
    setState(() => _isAppFullscreen = !previous);
    try {
      await _syncSystemChrome();
    } on Object {
      if (mounted) {
        setState(() => _isAppFullscreen = previous);
        _showMessage('无法切换全屏显示');
      }
      await _syncSystemChrome();
    } finally {
      _fullscreenTransitionInProgress = false;
    }
  }

  Future<void> _syncSystemChrome() async {
    final revision = ++_systemUiRevision;
    final shouldBeFullscreen =
        _isAppFullscreen || _webCustomFullscreenWidget != null;
    if (shouldBeFullscreen) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (revision != _systemUiRevision) return;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    await _restoreSystemChrome(revision: revision);
  }

  Future<void> _restoreSystemChrome({int? revision}) async {
    await SystemChrome.setPreferredOrientations(const []);
    if (revision != null && revision != _systemUiRevision) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _applyInitialPlaybackStateWhenReady() {
    final segment = widget.initialSegment;
    final controller = _playbackController;
    if (!_didPersistDuration &&
        controller != null &&
        controller.duration > Duration.zero) {
      _didPersistDuration = true;
      unawaited(_persistDuration(controller.duration));
    }
    if (_didApplyInitialPlaybackState ||
        controller == null ||
        !controller.bridgeReady ||
        (segment != null && controller.duration <= Duration.zero)) {
      return;
    }

    _didApplyInitialPlaybackState = true;
    unawaited(_applyInitialPlaybackState(controller, segment));
  }

  Future<void> _persistDuration(Duration duration) async {
    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .recordDuration(widget.source, duration);
      ref.invalidate(practiceSourceByIdProvider(widget.source.id));
    } on Object {
      // Playback remains available if optional metadata persistence fails.
      _didPersistDuration = false;
    }
  }

  Future<void> _applyInitialPlaybackState(
    BilibiliWebPlaybackController controller,
    PracticeSegment? segment,
  ) async {
    try {
      if (segment != null) {
        await controller.activateLoopRange(
          LoopRange(start: segment.start, end: segment.end),
        );
      }
      await controller.setSpeed(
        segment?.preferredSpeed ?? widget.defaultPlaybackSpeed,
      );
    } on Object {
      if (mounted) _showMessage('无法应用初始练习设置');
    }
  }

  Future<void> _saveCurrentLoop() async {
    final controller = _playbackController;
    final range = controller?.loopController.range;
    if (controller == null || range == null) return;
    try {
      await controller.pause();
    } on Object {
      if (mounted) _showMessage('无法暂停播放器，请稍后重试');
      return;
    }
    if (!mounted) return;
    final value = await showPracticeSegmentEditorSheet(
      context: context,
      mode: PracticeSegmentEditorMode.create,
      initialValue: PracticeSegmentEditorResult(
        title:
            '片段 ${formatPracticeTimecode(range.start)}–${formatPracticeTimecode(range.end)}',
        start: range.start,
        end: range.end,
        preferredSpeed: controller.speed,
      ),
    );
    if (value == null || !mounted) return;

    late final PracticeSegment created;
    try {
      created = await ref
          .read(practiceSegmentServiceProvider)
          .create(
            sourceId: widget.source.id,
            title: value.title,
            start: value.start,
            end: value.end,
            note: value.note,
            preferredSpeed: value.preferredSpeed,
            sourceDuration: controller.duration,
          );
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    } on Object {
      if (mounted) _showMessage('保存片段失败，请稍后重试');
      return;
    }

    try {
      await controller.activateLoopRange(
        LoopRange(start: created.start, end: created.end),
      );
      await controller.setSpeed(created.preferredSpeed);
      if (mounted) _showMessage('片段已保存并应用');
    } on Object {
      if (mounted) _showMessage('片段已保存，但播放器切换失败');
    }
  }

  Future<void> _activateSegment(PracticeSegment segment) async {
    final controller = _playbackController;
    if (controller == null) return;
    try {
      await controller.activateLoopRange(
        LoopRange(start: segment.start, end: segment.end),
      );
      await controller.setSpeed(segment.preferredSpeed);
      if (mounted) {
        _showMessage(
          '已切换到「${segment.title}」 · '
          '${_formatSpeed(segment.preferredSpeed)}x',
        );
      }
    } on Object {
      if (mounted) _showMessage('无法打开这个片段');
    }
  }

  Future<void> _editSegment(PracticeSegment segment) async {
    final controller = _playbackController;
    if (controller == null) return;
    try {
      await controller.pause();
    } on Object {
      if (mounted) _showMessage('无法暂停播放器，请稍后重试');
      return;
    }
    if (!mounted) return;
    final value = await showPracticeSegmentEditorSheet(
      context: context,
      mode: PracticeSegmentEditorMode.edit,
      initialValue: PracticeSegmentEditorResult(
        title: segment.title,
        start: segment.start,
        end: segment.end,
        note: segment.note,
        preferredSpeed: segment.preferredSpeed,
      ),
    );
    if (value == null || !mounted) return;

    late final PracticeSegment updated;
    try {
      updated = await ref
          .read(practiceSegmentServiceProvider)
          .update(
            segment,
            title: value.title,
            start: value.start,
            end: value.end,
            note: value.note,
            preferredSpeed: value.preferredSpeed,
            sourceDuration: controller.duration,
          );
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    } on Object {
      if (mounted) _showMessage('更新片段失败，请稍后重试');
      return;
    }

    try {
      await controller.activateLoopRange(
        LoopRange(start: updated.start, end: updated.end),
      );
      await controller.setSpeed(updated.preferredSpeed);
      if (mounted) _showMessage('已更新「${value.title}」');
    } on Object {
      if (mounted) _showMessage('片段已更新，但播放器切换失败');
    }
  }

  Future<void> _deleteSegment(PracticeSegment segment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除练习片段？'),
        content: Text('「${segment.title}」将从这个练习中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_segment'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final activeRange = _playbackController?.loopController.range;
      final wasActive =
          activeRange?.start == segment.start &&
          activeRange?.end == segment.end;
      await ref.read(practiceSegmentServiceProvider).delete(segment);
      if (wasActive) _playbackController?.clearLoop();
      if (mounted) _showMessage('已删除「${segment.title}」');
    } on Object {
      if (mounted) _showMessage('删除片段失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final webController = _webController;
    final playbackController = _playbackController;
    if (_playerUri == null ||
        webController == null ||
        playbackController == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.source.title)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('这个 B站链接没有可用的 BV/AV 号，暂时只能作为引用内容保存。'),
          ),
        ),
      );
    }

    final segments = ref.watch(practiceSegmentsProvider(widget.source.id));

    final scaffold = PopScope(
      canPop: !_isAppFullscreen || _webCustomFullscreenWidget != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isAppFullscreen && _webCustomFullscreenWidget == null) {
          unawaited(_toggleAppFullscreen());
        }
      },
      child: Scaffold(
        backgroundColor: _isAppFullscreen ? Colors.black : null,
        appBar: _isAppFullscreen
            ? null
            : AppBar(
                title: Text(widget.source.title),
                actions: [
                  IconButton(
                    key: const Key('bilibili_app_fullscreen'),
                    tooltip: '全屏练习',
                    onPressed: _recordingWorkflowActive
                        ? null
                        : _toggleAppFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                  IconButton(
                    tooltip: '刷新播放器',
                    onPressed: webController.reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
        body: SafeArea(
          top: !_isAppFullscreen,
          bottom: !_isAppFullscreen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desiredNormalHeight = (constraints.maxWidth * 9 / 16).clamp(
                180.0,
                420.0,
              );
              final normalHeight = desiredNormalHeight
                  .clamp(0.0, constraints.maxHeight)
                  .toDouble();
              final playerHeight = _isAppFullscreen
                  ? constraints.maxHeight
                  : normalHeight;
              final segmentItems = segments.asData?.value ?? const [];

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: playerHeight,
                    child: AnimatedBuilder(
                      animation: playbackController,
                      child: ColoredBox(
                        color: Colors.black,
                        child: WebViewWidget(
                          key: const ValueKey('bilibili_web_player_surface'),
                          controller: webController,
                        ),
                      ),
                      builder: (context, webSurface) {
                        return FullscreenControlsVisibility(
                          enabled: _isAppFullscreen,
                          isPlaying: playbackController.isPlaying,
                          controls: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_isAppFullscreen)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 12,
                                  child: SafeArea(
                                    minimum: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: FullscreenLocalVideoControls(
                                      position: playbackController.position,
                                      duration: playbackController.duration,
                                      segments: segmentItems,
                                      isPlaying: playbackController.isPlaying,
                                      enabled:
                                          playbackController.bridgeReady &&
                                          playbackController.duration >
                                              Duration.zero,
                                      onPreviewPosition:
                                          playbackController.previewPosition,
                                      onSeek: (position) => _runWebPlayerAction(
                                        context,
                                        () => playbackController.seek(position),
                                      ),
                                      onPlayPause: () => _runWebPlayerAction(
                                        context,
                                        playbackController.isPlaying
                                            ? playbackController.pause
                                            : playbackController.play,
                                      ),
                                      onSeekBackward: () => _runWebPlayerAction(
                                        context,
                                        () => playbackController.seek(
                                          playbackController.position -
                                              const Duration(seconds: 5),
                                        ),
                                      ),
                                      onSeekForward: () => _runWebPlayerAction(
                                        context,
                                        () => playbackController.seek(
                                          playbackController.position +
                                              const Duration(seconds: 5),
                                        ),
                                      ),
                                      onSegmentTap: (segment) =>
                                          unawaited(_activateSegment(segment)),
                                      volume: playbackController.volume,
                                      volumeEnabled:
                                          playbackController.bridgeReady,
                                      onPreviewVolume:
                                          playbackController.previewVolume,
                                      onVolumeChangeEnd: (value) =>
                                          _runWebPlayerAction(
                                            context,
                                            () => playbackController.setVolume(
                                              value,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              if (_isAppFullscreen)
                                PositionedDirectional(
                                  top: 0,
                                  end: 0,
                                  child: SafeArea(
                                    minimum: const EdgeInsets.all(8),
                                    child: IconButton.filledTonal(
                                      key: const Key(
                                        'bilibili_exit_app_fullscreen',
                                      ),
                                      tooltip: '退出全屏',
                                      onPressed: _toggleAppFullscreen,
                                      icon: const Icon(
                                        Icons.fullscreen_exit_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          child: webSurface!,
                        );
                      },
                    ),
                  ),
                  if (!_isAppFullscreen)
                    Positioned(
                      top: normalHeight,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedBuilder(
                        animation: playbackController,
                        builder: (context, _) => _PlayerControls(
                          controller: playbackController,
                          segments: segments,
                          recordingPanel: PracticeRecordingPanel(
                            key: ValueKey(
                              'bilibili_recording_${widget.source.id}',
                            ),
                            sourceId: widget.source.id,
                            planId: widget.planId,
                            enabled:
                                playbackController.bridgeReady &&
                                playbackController.duration > Duration.zero,
                            captureReference: () => _captureRecordingReference(
                              playbackController,
                              segments.asData?.value ?? const [],
                            ),
                            referencePosition: () =>
                                playbackController.position,
                            referenceIsPlaying: () =>
                                playbackController.isPlaying,
                            seekReference: playbackController.seek,
                            playReference: playbackController.play,
                            pauseReference: playbackController.pause,
                            onWorkflowActiveChanged: (value) {
                              if (mounted &&
                                  _recordingWorkflowActive != value) {
                                setState(
                                  () => _recordingWorkflowActive = value,
                                );
                              }
                            },
                          ),
                          onSaveSegment: _saveCurrentLoop,
                          onActivateSegment: (segment) =>
                              unawaited(_activateSegment(segment)),
                          onEditSegment: (segment) =>
                              unawaited(_editSegment(segment)),
                          onDeleteSegment: (segment) =>
                              unawaited(_deleteSegment(segment)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    return WebCustomFullscreenHost(
      fullscreenChild: _webCustomFullscreenWidget,
      onExitFullscreen: _requestExitWebCustomFullscreen,
      child: scaffold,
    );
  }

  PracticeRecordingReference _captureRecordingReference(
    BilibiliWebPlaybackController controller,
    List<PracticeSegment> segments,
  ) {
    final range = controller.loopController.range;
    final segment = range == null
        ? null
        : segments.cast<PracticeSegment?>().firstWhere(
            (item) => item?.start == range.start && item?.end == range.end,
            orElse: () => null,
          );
    return PracticeRecordingReference(
      start: range?.start ?? controller.position,
      end: range?.end,
      speed: controller.speed,
      segmentId: segment?.id,
      segmentTitle: segment?.title,
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.controller,
    required this.segments,
    required this.recordingPanel,
    required this.onSaveSegment,
    required this.onActivateSegment,
    required this.onEditSegment,
    required this.onDeleteSegment,
  });

  final BilibiliWebPlaybackController controller;
  final AsyncValue<List<PracticeSegment>> segments;
  final Widget recordingPanel;
  final VoidCallback onSaveSegment;
  final ValueChanged<PracticeSegment> onActivateSegment;
  final ValueChanged<PracticeSegment> onEditSegment;
  final ValueChanged<PracticeSegment> onDeleteSegment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final durationMs = controller.duration.inMilliseconds;
    final canControl = controller.bridgeReady && durationMs > 0;
    final loop = controller.loopController;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: controller.bridgeReady
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      controller.bridgeReady
                          ? Icons.link_rounded
                          : Icons.hourglass_top_rounded,
                      color: controller.bridgeReady
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.bridgeReady
                            ? '已连接 B站播放器，可使用进度与循环控制'
                            : '播放器可直接操作；正在探测自动控制能力…',
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.playerError case final error?) ...[
                const SizedBox(height: 10),
                Text(error, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 16),
              PracticeSegmentProgressSlider(
                duration: controller.duration,
                position: controller.position,
                segments: segments.asData?.value ?? const [],
                enabled: canControl,
                sliderKey: const Key('bilibili_position_slider'),
                onChanged: (value) => controller.previewPosition(
                  Duration(milliseconds: value.round()),
                ),
                onChangeEnd: (value) => _runWebPlayerAction(
                  context,
                  () => controller.seek(Duration(milliseconds: value.round())),
                ),
                onSegmentTap: onActivateSegment,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(controller.position)),
                    Text(_formatDuration(controller.duration)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    key: const Key('bilibili_play_pause'),
                    tooltip: controller.isPlaying ? '暂停' : '播放',
                    onPressed: canControl
                        ? () => _runWebPlayerAction(
                            context,
                            controller.isPlaying
                                ? controller.pause
                                : controller.play,
                          )
                        : null,
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PrecisePlaybackSpeedControl(
                value: controller.speed,
                enabled: canControl,
                onChanged: (_) {},
                onChangeEnd: (value) => _runWebPlayerAction(
                  context,
                  () => controller.setSpeed(value),
                ),
              ),
              const SizedBox(height: 14),
              PlaybackVolumeControl(
                value: controller.volume,
                enabled: controller.bridgeReady,
                onChanged: controller.previewVolume,
                onChangeEnd: (value) => _runWebPlayerAction(
                  context,
                  () => controller.setVolume(value),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'A-B Loop',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('set_loop_a'),
                      onPressed: canControl ? controller.setLoopStart : null,
                      child: Text('A  ${_formatOptional(loop.start)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('set_loop_b'),
                      onPressed: canControl
                          ? () {
                              if (!controller.setLoopEnd()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('B 点必须晚于 A 点')),
                                );
                              }
                            }
                          : null,
                      child: Text('B  ${_formatOptional(loop.end)}'),
                    ),
                  ),
                  IconButton(
                    tooltip: '清除循环区间',
                    onPressed: loop.range == null ? null : controller.clearLoop,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('循环播放区间'),
                subtitle: Text('已完成 ${loop.completedLoops} 次'),
                value: loop.enabled,
                onChanged: canControl && loop.range != null
                    ? controller.setLoopEnabled
                    : null,
              ),
              const Divider(height: 32),
              recordingPanel,
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '练习片段',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('save_loop_segment'),
                    onPressed: loop.range == null ? null : onSaveSegment,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('保存当前区间'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              segments.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) =>
                    Text('暂时无法读取已保存片段', style: TextStyle(color: colors.error)),
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      '设置 A、B 点后保存，之后可以一键回到这个练习区间。',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    );
                  }
                  return Column(
                    children: items
                        .map(
                          (segment) => PracticeSegmentCard(
                            cardKey: ValueKey('practice_segment_${segment.id}'),
                            segment: segment,
                            onOpen: () => onActivateSegment(segment),
                            onEdit: () => onEditSegment(segment),
                            onDelete: () => onDeleteSegment(segment),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                '进度控制依赖 B站网页播放器当前暴露的标准 video 元素；若页面结构变化，仍可使用上方播放器自带控件。',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _runWebPlayerAction(BuildContext context, Future<void> Function() action) {
  unawaited(() async {
    try {
      await action();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('播放器操作失败，请重试')));
    }
  }());
}

class _WebViewScriptExecutor implements JavaScriptExecutor {
  const _WebViewScriptExecutor(this._controller);

  final WebViewController _controller;

  @override
  Future<void> runJavaScript(String javaScript) {
    return _controller.runJavaScript(javaScript);
  }
}

bool _isAllowedBilibiliNavigation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  if (uri.scheme == 'about') return true;
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' &&
      (host == 'bilibili.com' || host.endsWith('.bilibili.com'));
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatOptional(Duration? duration) {
  return duration == null ? '--:--' : formatPracticeTimecode(duration);
}

String _formatSpeed(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../../media/playback/local_video_playback_controller.dart';
import '../../media/playback/loop_controller.dart';
import '../plans/application/practice_playback_session_recorder.dart';
import '../plans/practice_plan_providers.dart';
import '../recordings/presentation/practice_recording_panel.dart';
import 'presentation/fullscreen_controls_visibility.dart';
import 'presentation/fullscreen_local_video_controls.dart';
import 'widgets/video_analysis_panel.dart';
import 'widgets/practice_workspace.dart';
import 'widgets/video_chord_playback_strip.dart';
import '../audio_tools/domain/legacy_algorithm_models.dart';
import '../segments/practice_segment_providers.dart';
import '../segments/presentation/practice_segment_editor_sheet.dart';
import '../segments/presentation/practice_segment_timecode.dart';

class LocalVideoPlayerScreen extends ConsumerStatefulWidget {
  const LocalVideoPlayerScreen({
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
  ConsumerState<LocalVideoPlayerScreen> createState() =>
      _LocalVideoPlayerScreenState();
}

class _LocalVideoPlayerScreenState extends ConsumerState<LocalVideoPlayerScreen>
    with WidgetsBindingObserver {
  LocalVideoPlaybackController? _controller;
  late final PracticePlaybackSessionRecorder _sessionRecorder;
  bool _didApplyInitialPlaybackState = false;
  bool _isFullscreen = false;
  bool _fullscreenTransitionInProgress = false;
  bool _recordingWorkflowActive = false;
  AlgorithmOperation? _requestedAnalysis;
  int _analysisRevision = 0;
  int _workspaceIndex = 0;

  String? get _videoPath {
    final uri = widget.source.canonicalUri;
    if (uri == null || uri.scheme != 'file') return null;
    try {
      return uri.toFilePath();
    } on UnsupportedError {
      return null;
    }
  }

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionRecorder.resume();
    } else {
      _sessionRecorder.suspend();
      unawaited(_checkpointSession());
      unawaited(_controller?.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _trackPlayback();
    controller?.removeListener(_applyInitialPlaybackStateWhenReady);
    controller?.removeListener(_trackPlayback);
    controller?.dispose();
    unawaited(_finishSession());
    if (_isFullscreen || _fullscreenTransitionInProgress) {
      unawaited(_restoreSystemChrome());
    }
    super.dispose();
  }

  void _onPlatformViewCreated(int viewId) {
    final previous = _controller;
    _trackPlayback();
    previous?.removeListener(_applyInitialPlaybackStateWhenReady);
    previous?.removeListener(_trackPlayback);
    previous?.dispose();

    final controller = LocalVideoPlaybackController(
      MethodChannelLocalVideoPlayerBridge(viewId),
    );
    controller.addListener(_applyInitialPlaybackStateWhenReady);
    controller.addListener(_trackPlayback);
    setState(() => _controller = controller);
    unawaited(controller.requestSnapshot());
  }

  void _trackPlayback() {
    final controller = _controller;
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

  void _applyInitialPlaybackStateWhenReady() {
    final segment = widget.initialSegment;
    final controller = _controller;
    if (_didApplyInitialPlaybackState ||
        controller == null ||
        !controller.isReady ||
        (segment != null && controller.duration <= Duration.zero)) {
      return;
    }
    _didApplyInitialPlaybackState = true;
    unawaited(_applyInitialPlaybackState(controller, segment));
  }

  Future<void> _applyInitialPlaybackState(
    LocalVideoPlaybackController controller,
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

  Future<void> _toggleFullscreen() async {
    if (_fullscreenTransitionInProgress) return;
    if (!_isFullscreen && _recordingWorkflowActive) {
      _showMessage('请先结束或保存当前录音，再进入全屏');
      return;
    }
    _fullscreenTransitionInProgress = true;
    final next = !_isFullscreen;
    try {
      if (next) {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        if (!mounted) {
          await _restoreSystemChrome();
          return;
        }
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await _restoreSystemChrome();
      }
      if (!mounted) {
        await _restoreSystemChrome();
        return;
      }
      setState(() => _isFullscreen = next);
    } finally {
      _fullscreenTransitionInProgress = false;
    }
  }

  Future<void> _restoreSystemChrome() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _saveCurrentLoop() async {
    final controller = _controller;
    final range = controller?.loopController.range;
    if (controller == null || range == null) return;
    await controller.pause();
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

    try {
      final created = await ref
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
      await controller.activateLoopRange(
        LoopRange(start: created.start, end: created.end),
      );
      await controller.setSpeed(created.preferredSpeed);
      if (mounted) _showMessage('片段已保存并应用');
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('保存片段失败，请稍后重试');
    }
  }

  Future<void> _activateSegment(PracticeSegment segment) async {
    final controller = _controller;
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
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
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

    try {
      final updated = await ref
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
      await controller.activateLoopRange(
        LoopRange(start: updated.start, end: updated.end),
      );
      await controller.setSpeed(updated.preferredSpeed);
      if (mounted) _showMessage('已更新「${value.title}」');
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('更新片段失败，请稍后重试');
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final activeRange = _controller?.loopController.range;
      final wasActive =
          activeRange?.start == segment.start &&
          activeRange?.end == segment.end;
      await ref.read(practiceSegmentServiceProvider).delete(segment);
      if (wasActive) _controller?.clearLoop();
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
    final path = _videoPath;
    final fileExists = path != null && File(path).existsSync();
    if (!Platform.isAndroid || !fileExists) {
      return _LocalVideoUnavailableView(
        title: widget.source.title,
        message: !Platform.isAndroid
            ? '本地视频播放当前先在 Android 版本开放。'
            : '找不到这个视频文件。它可能已被系统清理或从应用目录移除。',
      );
    }

    final segments = ref.watch(practiceSegmentsProvider(widget.source.id));
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) unawaited(_toggleFullscreen());
      },
      child: Scaffold(
        backgroundColor: _isFullscreen ? Colors.black : null,
        appBar: _isFullscreen
            ? null
            : AppBar(
                title: Text(
                  widget.source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (kDebugMode)
                    AnimatedBuilder(
                      animation: _controller ?? kAlwaysCompleteAnimation,
                      builder: (context, _) =>
                          PopupMenuButton<AlgorithmOperation>(
                            key: const Key('local_video_analysis_menu'),
                            tooltip: '当前视频的和弦与分轨',
                            enabled:
                                !_recordingWorkflowActive &&
                                _controller?.isReady == true,
                            icon: const Icon(Icons.auto_awesome),
                            onSelected: (operation) => setState(() {
                              _workspaceIndex = 1;
                              _requestedAnalysis = operation;
                              _analysisRevision++;
                            }),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: AlgorithmOperation.chords,
                                child: Text('扒和弦'),
                              ),
                              PopupMenuItem(
                                value: AlgorithmOperation.separation,
                                child: Text('分离音轨'),
                              ),
                            ],
                          ),
                    ),
                ],
              ),
        body: SafeArea(
          top: !_isFullscreen,
          bottom: !_isFullscreen,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final normalHeight = (constraints.maxWidth * 9 / 16)
                  .clamp(0.0, 360.0)
                  .clamp(
                    0.0,
                    constraints.maxHeight *
                        (constraints.maxHeight < 480 ? .28 : .34),
                  );
              final videoHeight = _isFullscreen
                  ? constraints.maxHeight
                  : normalHeight;
              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: videoHeight,
                    child: SizedBox(
                      key: const ValueKey('local_video_surface_container'),
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: _controller ?? kAlwaysCompleteAnimation,
                        child: ColoredBox(
                          color: Colors.black,
                          child: AndroidView(
                            key: ValueKey('local_video_${widget.source.id}'),
                            viewType: 'com.guitarpal/local_video_player',
                            creationParams: {'path': path},
                            creationParamsCodec: const StandardMessageCodec(),
                            onPlatformViewCreated: _onPlatformViewCreated,
                          ),
                        ),
                        builder: (context, videoSurface) {
                          final controller = _controller;
                          return FullscreenControlsVisibility(
                            enabled: _isFullscreen,
                            isPlaying: controller?.isPlaying ?? false,
                            controls: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_isFullscreen && controller != null)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 12,
                                    child: SafeArea(
                                      minimum: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: _FullscreenTransport(
                                        controller: controller,
                                        segments:
                                            segments.asData?.value ?? const [],
                                        onActivateSegment: (segment) =>
                                            unawaited(
                                              _activateSegment(segment),
                                            ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton.filledTonal(
                                    key: const Key('local_video_fullscreen'),
                                    tooltip: _isFullscreen ? '退出全屏' : '全屏',
                                    onPressed:
                                        _isFullscreen ||
                                            !_recordingWorkflowActive
                                        ? _toggleFullscreen
                                        : null,
                                    icon: Icon(
                                      _isFullscreen
                                          ? Icons.fullscreen_exit_rounded
                                          : Icons.fullscreen_rounded,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            child: videoSurface!,
                          );
                        },
                      ),
                    ),
                  ),
                  if (kDebugMode && _isFullscreen && _controller != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 64,
                      child: SafeArea(
                        child: VideoChordPlaybackStrip(
                          sourceId: widget.source.id,
                          path: path,
                          controller: _controller!,
                          compact: true,
                          enabled: !_recordingWorkflowActive,
                          onCalibrate: () async {
                            await _toggleFullscreen();
                            if (mounted) {
                              setState(() {
                                _workspaceIndex = 1;
                                _requestedAnalysis = AlgorithmOperation.chords;
                                _analysisRevision++;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  Positioned(
                    key: const ValueKey('local_video_controls_region'),
                    top: _isFullscreen ? 0 : normalHeight,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Offstage(
                      offstage: _isFullscreen,
                      child: _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : AnimatedBuilder(
                              animation: _controller!,
                              builder: (context, _) => PracticeWorkspace(
                                selectedSection: _workspaceIndex,
                                keyboardVisible: keyboardVisible,
                                recordingActive: _recordingWorkflowActive,
                                onSelectSection: (value) =>
                                    setState(() => _workspaceIndex = value),
                                chordStrip: kDebugMode
                                    ? VideoChordPlaybackStrip(
                                        sourceId: widget.source.id,
                                        path: path,
                                        controller: _controller!,
                                        showTimeline: false,
                                        enabled: !_recordingWorkflowActive,
                                        onCalibrate: () => setState(() {
                                          _workspaceIndex = 1;
                                          _requestedAnalysis =
                                              AlgorithmOperation.chords;
                                          _analysisRevision++;
                                        }),
                                      )
                                    : null,
                                controller: _controller!,
                                segments: segments,
                                analysisPanel: kDebugMode
                                    ? VideoAnalysisPanel(
                                        key: ValueKey(
                                          'video_analysis_${widget.source.id}',
                                        ),
                                        source: widget.source,
                                        embedded: true,
                                        path: path,
                                        controller: _controller!,
                                        planId: widget.planId,
                                        enabled:
                                            !_recordingWorkflowActive &&
                                            _controller!.isReady &&
                                            _controller!.duration >
                                                Duration.zero,
                                        requestedOperation: _requestedAnalysis,
                                        requestRevision: _analysisRevision,
                                        onSaveLoop: _saveCurrentLoop,
                                        recordingActive:
                                            _recordingWorkflowActive,
                                      )
                                    : null,
                                recordingPanel: PracticeRecordingPanel(
                                  key: ValueKey(
                                    'local_recording_${widget.source.id}',
                                  ),
                                  sourceId: widget.source.id,
                                  planId: widget.planId,
                                  enabled:
                                      _controller!.isReady &&
                                      _controller!.duration > Duration.zero,
                                  captureReference: () =>
                                      _captureRecordingReference(
                                        _controller!,
                                        segments.asData?.value ?? const [],
                                      ),
                                  referencePosition: () =>
                                      _controller!.position,
                                  referenceIsPlaying: () =>
                                      _controller!.isPlaying,
                                  seekReference: _controller!.seek,
                                  playReference: _controller!.play,
                                  pauseReference: _controller!.pause,
                                  onWorkflowActiveChanged: (value) {
                                    if (value && _controller!.stemsLoaded) {
                                      unawaited(
                                        _controller!.clearStems().catchError(
                                          (Object _) {},
                                        ),
                                      );
                                    }
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  PracticeRecordingReference _captureRecordingReference(
    LocalVideoPlaybackController controller,
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

class _FullscreenTransport extends StatelessWidget {
  const _FullscreenTransport({
    required this.controller,
    required this.segments,
    required this.onActivateSegment,
  });

  final LocalVideoPlaybackController controller;
  final List<PracticeSegment> segments;
  final ValueChanged<PracticeSegment> onActivateSegment;

  @override
  Widget build(BuildContext context) {
    final canControl =
        controller.isReady && controller.duration > Duration.zero;
    return FullscreenLocalVideoControls(
      position: controller.position,
      duration: controller.duration,
      segments: segments,
      isPlaying: controller.isPlaying,
      enabled: canControl,
      onPreviewPosition: controller.previewPosition,
      onSeek: (position) => unawaited(controller.seek(position)),
      onPlayPause: () => unawaited(
        controller.isPlaying ? controller.pause() : controller.play(),
      ),
      onSeekBackward: () =>
          unawaited(controller.seekRelative(const Duration(seconds: -5))),
      onSeekForward: () =>
          unawaited(controller.seekRelative(const Duration(seconds: 5))),
      onSegmentTap: onActivateSegment,
      volume: controller.volume,
      volumeEnabled: controller.isReady,
      onPreviewVolume: controller.previewVolume,
      onVolumeChangeEnd: (value) => unawaited(controller.setVolume(value)),
    );
  }
}

class _LocalVideoUnavailableView extends StatelessWidget {
  const _LocalVideoUnavailableView({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_file_outlined, size: 52),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSpeed(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

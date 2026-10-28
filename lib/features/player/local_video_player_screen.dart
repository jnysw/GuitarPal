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
import 'widgets/playback_volume_control.dart';
import 'widgets/precise_playback_speed_control.dart';
import 'widgets/video_analysis_panel.dart';
import '../audio_tools/domain/legacy_algorithm_models.dart';
import '../segments/practice_segment_providers.dart';
import '../segments/presentation/practice_segment_card.dart';
import '../segments/presentation/practice_segment_editor_sheet.dart';
import '../segments/presentation/practice_segment_progress_slider.dart';
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
                title: Text(widget.source.title),
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
              final normalHeight = (constraints.maxWidth * 9 / 16).clamp(
                180.0,
                420.0,
              );
              return Column(
                children: [
                  SizedBox(
                    key: const ValueKey('local_video_surface_container'),
                    width: double.infinity,
                    height: _isFullscreen
                        ? constraints.maxHeight
                        : normalHeight,
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
                                          unawaited(_activateSegment(segment)),
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
                                      _isFullscreen || !_recordingWorkflowActive
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
                  Expanded(
                    child: Offstage(
                      offstage: _isFullscreen,
                      child: _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : AnimatedBuilder(
                              animation: _controller!,
                              builder: (context, _) => _LocalVideoControls(
                                controller: _controller!,
                                segments: segments,
                                analysisPanel: kDebugMode
                                    ? VideoAnalysisPanel(
                                        key: ValueKey(
                                          'video_analysis_${widget.source.id}',
                                        ),
                                        source: widget.source,
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

class _LocalVideoControls extends StatelessWidget {
  const _LocalVideoControls({
    required this.controller,
    required this.segments,
    required this.recordingPanel,
    this.analysisPanel,
    required this.onSaveSegment,
    required this.onActivateSegment,
    required this.onEditSegment,
    required this.onDeleteSegment,
  });

  final LocalVideoPlaybackController controller;
  final AsyncValue<List<PracticeSegment>> segments;
  final Widget recordingPanel;
  final Widget? analysisPanel;
  final VoidCallback onSaveSegment;
  final ValueChanged<PracticeSegment> onActivateSegment;
  final ValueChanged<PracticeSegment> onEditSegment;
  final ValueChanged<PracticeSegment> onDeleteSegment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final durationMs = controller.duration.inMilliseconds;
    final canControl = controller.isReady && durationMs > 0;
    final loop = controller.loopController;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    controller.isReady && controller.hasVideoFrame
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_top_rounded,
                    color: controller.isReady && controller.hasVideoFrame
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(switch ((
                      controller.isReady,
                      controller.hasVideoFrame,
                    )) {
                      (true, true) => '本地播放器已就绪',
                      (true, false) => '正在渲染视频画面…',
                      _ => '正在读取视频…',
                    }),
                  ),
                ],
              ),
              if (controller.playerError case final error?) ...[
                const SizedBox(height: 8),
                Text(error, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 8),
              PracticeSegmentProgressSlider(
                duration: controller.duration,
                position: controller.position,
                segments: segments.asData?.value ?? const [],
                enabled: canControl,
                sliderKey: const Key('local_video_position_slider'),
                onChanged: (value) => controller.previewPosition(
                  Duration(milliseconds: value.round()),
                ),
                onChangeEnd: (value) =>
                    controller.seek(Duration(milliseconds: value.round())),
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
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '后退 5 秒',
                    onPressed: canControl
                        ? () => controller.seekRelative(
                            const Duration(seconds: -5),
                          )
                        : null,
                    icon: const Icon(Icons.replay_5_rounded),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    key: const Key('local_video_play_pause'),
                    tooltip: controller.isPlaying ? '暂停' : '播放',
                    onPressed: canControl
                        ? () => controller.isPlaying
                              ? controller.pause()
                              : controller.play()
                        : null,
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: '前进 5 秒',
                    onPressed: canControl
                        ? () => controller.seekRelative(
                            const Duration(seconds: 5),
                          )
                        : null,
                    icon: const Icon(Icons.forward_5_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrecisePlaybackSpeedControl(
                value: controller.speed,
                enabled: canControl,
                onChanged: (_) {},
                onChangeEnd: (value) => unawaited(controller.setSpeed(value)),
              ),
              const SizedBox(height: 12),
              PlaybackVolumeControl(
                value: controller.volume,
                enabled: controller.isReady,
                onChanged: controller.previewVolume,
                onChangeEnd: (value) => unawaited(controller.setVolume(value)),
              ),
              const SizedBox(height: 22),
              Text(
                'A-B Loop',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('local_video_set_loop_a'),
                      onPressed: canControl ? controller.setLoopStart : null,
                      child: Text('A  ${_formatOptional(loop.start)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('local_video_set_loop_b'),
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
              const Divider(height: 30),
              if (analysisPanel != null) ...[
                analysisPanel!,
                const Divider(height: 30),
              ],
              recordingPanel,
              const Divider(height: 30),
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
                    key: const Key('local_video_save_loop_segment'),
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
                            cardKey: ValueKey('local_segment_${segment.id}'),
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
            ],
          ),
        ),
      ),
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

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
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

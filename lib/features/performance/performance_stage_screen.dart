import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../recordings/practice_recording_providers.dart';
import 'application/performance_capture_controller.dart';
import 'performance_take_providers.dart';
import 'performance_dialog.dart';

import '../audio_tools/algorithm_providers.dart';
import '../audio_tools/domain/algorithm_task.dart';
import '../audio_tools/domain/legacy_algorithm_models.dart';
import '../audio_tools/domain/video_analysis_binding.dart';
import '../audio_tools/domain/video_chord_playback.dart';
import '../plans/practice_plan_providers.dart';
import '../player/widgets/scrolling_chord_lane.dart';
import '../segments/presentation/practice_segment_timecode.dart';
import 'application/performance_source_resolver.dart';
import 'application/performance_stage_controller.dart';
import 'performance_resolver_providers.dart';
import 'performance_route_observer.dart';

class PerformanceStageRouteScreen extends ConsumerWidget {
  const PerformanceStageRouteScreen({super.key, required this.sourceId});
  final String sourceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode || !Platform.isAndroid) {
      return const Scaffold(body: Center(child: Text('演奏舞台当前在 Android 测试版开放')));
    }
    return ref
        .watch(performanceBackingProvider(sourceId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('演奏空间')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(e is FormatException ? e.message : '无法读取伴奏，请返回准备页'),
            ),
          ),
          data: (backing) =>
              PerformanceStageScreen(key: ObjectKey(backing), backing: backing),
        );
  }
}

class PerformanceStageScreen extends ConsumerStatefulWidget {
  const PerformanceStageScreen({super.key, required this.backing});
  final PerformanceBacking backing;
  @override
  ConsumerState<PerformanceStageScreen> createState() =>
      _PerformanceStageScreenState();
}

class _PerformanceStageScreenState extends ConsumerState<PerformanceStageScreen>
    with WidgetsBindingObserver, RouteAware {
  late final PerformanceStageController _stage;
  late final PerformanceCaptureController _capture;
  bool _allowPop = false, _leaving = false, _motion = true, _showChords = true;
  double? _drag;
  VideoChordPlayback? _chords;
  List<AlgorithmTaskRecord>? _tasks;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final b = widget.backing;
    _stage = PerformanceStageController(
      platform: ref.read(algorithmMixPlatformProvider),
      store: ref.read(algorithmStemStoreProvider),
      candidate: b.candidate,
      preset: b.preset,
      recorder: ref
          .read(practiceSessionServiceProvider)
          .trackPlayback(sourceId: b.source.id),
      verify: ref.read(performanceSourceResolverProvider).verify,
    );
    _capture = PerformanceCaptureController(
      _stage,
      ref.read(practiceAudioRecorderProvider),
      ref.read(performanceAudioProvider),
      ref.read(performanceTakeServiceProvider),
    )..addListener(_captureChanged);
    unawaited(_capture.restore());
    unawaited(_stage.initialize());
  }

  void _captureChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _suspend() async {
    await _capture.interrupt();
    await _stage.suspend();
  }

  Future<void> _reviewDraft() async {
    final draft = _capture.draft;
    if (draft == null || _capture.active) return;
    await _stage.suspend();
    if (!mounted) return;
    await context.push(
      Uri(
        path: '/performance/review',
        queryParameters: {'takeId': draft.id},
      ).toString(),
    );
    _stage.resume();
    _capture.resume();
    await _capture.refreshDraft();
  }

  Future<void> _history() async {
    if (_capture.active) return;
    await _stage.suspend();
    if (!mounted) return;
    await context.push(
      Uri(
        path: '/performance/takes',
        queryParameters: {'sourceId': widget.backing.source.id},
      ).toString(),
    );
    _stage.resume();
    _capture.resume();
    await _capture.refreshDraft();
  }

  Future<void> _record(bool trial) async {
    final yes = await showPerformanceDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(trial ? '先试录 3 秒' : '录一遍演奏'),
        content: Text(
          trial
              ? '建议戴耳机。试录只录麦克风，不播放伴奏；听后确认输入是否正常。'
              : '建议戴耳机，伴奏外放可能被再次录入。三秒倒计时后，从所选伴奏区间开头录制。暂停、后台或音频设备变化会结束本条录音。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('开始'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _capture.begin(trial: trial);
  }

  PageRoute<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      performanceRouteObserver.unsubscribe(this);
      _route = route;
      performanceRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    unawaited(_suspend());
  }

  @override
  void didPopNext() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _stage.resume();
      _capture.resume();
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    if (_capture.active) await _capture.stop();
    if (_capture.draft != null && mounted) {
      final yes = await showPerformanceDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('还有未保存的录音'),
          content: const Text('退出后保留录音草稿。下次可从演奏录音继续回听、保存或丢弃。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('留在舞台'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('保留草稿退出'),
            ),
          ],
        ),
      );
      if (yes != true) {
        if (mounted) setState(() => _leaving = false);
        return;
      }
    }
    try {
      await _stage.leave();
    } on Object {
      if (!mounted) return;
      final leave = await showPerformanceDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('演奏记录暂未保存'),
          content: const Text('可以返回重试；直接退出会保留此前保存的检查点。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回重试'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('直接退出'),
            ),
          ],
        ),
      );
      if (leave != true) {
        if (mounted) setState(() => _leaving = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _settings() async => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => AnimatedBuilder(
      animation: _stage,
      builder: (context, _) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, update) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('舞台设置', style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                  title: const Text('舞台动效'),
                  subtitle: const Text('系统减弱动画时仅保留静态舞台'),
                  value: _motion,
                  onChanged: (v) {
                    setState(() => _motion = v);
                    update(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('和弦提示'),
                  value: _showChords,
                  onChanged: (v) {
                    setState(() => _showChords = v);
                    update(() {});
                  },
                ),
                const Text('伴奏音量'),
                Slider(
                  key: const Key('stage_master'),
                  value: _stage.master,
                  onChanged: _stage.busy
                      ? null
                      : (v) => unawaited(_stage.setMaster(v)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void _readChords(List<AlgorithmTaskRecord> tasks) {
    if (identical(tasks, _tasks)) return;
    _tasks = tasks;
    _chords = null;
    final c = widget.backing.candidate;
    for (final task in tasks) {
      if (task.operation != AlgorithmOperation.chords ||
          task.state != AlgorithmTaskState.completed ||
          task.linkedSourceId != widget.backing.source.id ||
          task.resultJson == null ||
          task.mediaBindingJson == null) {
        continue;
      }
      try {
        final binding = VideoAnalysisBinding.fromJson(
          algorithmObject(jsonDecode(task.mediaBindingJson!)),
        );
        if (binding.endMs <= c.binding.startMs ||
            binding.startMs >= c.binding.endMs) {
          continue;
        }
        if (binding.sourceId != c.binding.sourceId ||
            binding.sourceDurationMs != c.binding.sourceDurationMs ||
            binding.path != c.binding.path ||
            binding.sourceBytes != c.binding.sourceBytes ||
            binding.modifiedMs != c.binding.modifiedMs) {
          continue;
        }
        final result = LegacyChordResult.fromJson(
          algorithmObject(jsonDecode(task.resultJson!)),
        );
        final zero = binding.manualChordZeroMs ?? binding.startMs;
        if (binding.manualChordZeroMs != null &&
            zero + result.duration.inMilliseconds > binding.endMs + 20) {
          continue;
        }
        _chords = VideoChordPlayback(result, binding);
        break;
      } on Object {
        continue;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stage.resume();
      _capture.resume();
    } else if (!(state == AppLifecycleState.inactive &&
        _capture.phase == PerformanceCapturePhase.checking)) {
      // The system permission sheet may temporarily mark this page inactive.
      // A real background/hidden transition still cancels the pending start.
      unawaited(_suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    performanceRouteObserver.unsubscribe(this);
    _capture.removeListener(_captureChanged);
    _capture.dispose();
    _stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _readChords(ref.watch(algorithmTasksProvider).asData?.value ?? const []);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('演奏空间'),
          leading: BackButton(onPressed: _leaving ? null : _leave),
          actions: [
            IconButton(
              tooltip: '演奏录音',
              icon: const Icon(Icons.library_music_outlined),
              onPressed: _capture.active ? null : _history,
            ),
            IconButton(
              tooltip: '舞台设置',
              onPressed: _capture.active ? null : _settings,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _stage,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight < 520 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20;
                final colors = Theme.of(context).colorScheme;
                final motion =
                    _motion &&
                    !MediaQuery.disableAnimationsOf(context) &&
                    _stage.playing;
                final position =
                    widget.backing.candidate.binding.startMs +
                    _stage.positionMs;
                final content = Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.backing.source.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${widget.backing.preset.speed.toStringAsFixed(2)}×',
                          ),
                        ],
                      ),
                    ),
                    if (!compact && _showChords && _chords != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ScrollingChordLane(
                          playback: _chords!,
                          positionMs: position,
                          playing: _stage.playing,
                          onSeek: (ms) => unawaited(
                            _stage.seek(
                              ms - widget.backing.candidate.binding.startMs,
                            ),
                          ),
                          enabled:
                              !_stage.busy &&
                              !_capture.active &&
                              position >= _chords!.binding.startMs &&
                              position < _chords!.binding.endMs,
                        ),
                      ),
                    _StageFlex(
                      tiny: constraints.maxHeight < 600,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: colors.surfaceContainerLow,
                          ),
                          child: LayoutBuilder(
                            builder: (context, size) => Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: size.maxWidth * .08,
                                  right: size.maxWidth * .08,
                                  bottom: 12,
                                  child: Container(
                                    height: compact ? 34 : 70,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(
                                        Radius.elliptical(180, 40),
                                      ),
                                      color: colors.primary.withValues(
                                        alpha: .08,
                                      ),
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: size.maxWidth,
                                    height: compact ? 100 : 180,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        StageSpeaker(
                                          key: const Key('stage_left_speaker'),
                                          level: motion ? _stage.leftMotion : 0,
                                          peak: _stage.leftPeak,
                                          enabled: motion,
                                          label: '左音响',
                                          compact: compact,
                                        ),
                                        Flexible(
                                          child: PerformanceCharacterSlot(
                                            phase: _stage.phase,
                                            compact: compact,
                                          ),
                                        ),
                                        StageSpeaker(
                                          key: const Key('stage_right_speaker'),
                                          level: motion
                                              ? _stage.rightMotion
                                              : 0,
                                          peak: _stage.rightPeak,
                                          enabled: motion,
                                          label: '右音响',
                                          compact: compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _status(_stage.phase),
                        key: const Key('stage_status'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: Text(
                        _capture.active && _capture.draft?.trial == true
                            ? '音响跟随伴奏 · 麦克风试录不播放伴奏'
                            : !_motion ||
                                  MediaQuery.disableAnimationsOf(context)
                            ? '音响跟随伴奏 · 动效已关闭'
                            : _stage.systemMuted || _stage.master == 0
                            ? '音响跟随伴奏 · 伴奏或系统音量已静音'
                            : _stage.meterUnavailable
                            ? '伴奏电平暂未收到，音响保持静止'
                            : '音响跟随伴奏电平，不跟随麦克风录音',
                        key: const Key('stage_speaker_source'),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_stage.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _stage.error!,
                          style: TextStyle(color: colors.error),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (_stage.statisticsError != null)
                      TextButton(
                        onPressed: _stage.retryStatistics,
                        child: Text(_stage.statisticsError!),
                      ),
                    if (_stage.meterUnavailable && !compact)
                      const Text('音响电平暂不可用，舞台保持静止'),
                    if (_stage.busy) const LinearProgressIndicator(),
                    Slider(
                      key: const Key('stage_position'),
                      value: (_drag ?? _stage.positionMs.toDouble()).clamp(
                        0,
                        _stage.durationMs.toDouble(),
                      ),
                      min: 0,
                      max: _stage.durationMs.toDouble(),
                      onChanged: _stage.busy || _leaving || _capture.active
                          ? null
                          : (v) => setState(() => _drag = v),
                      onChangeEnd: (v) {
                        setState(() => _drag = null);
                        unawaited(_stage.seek(v.round()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatPracticeTimecode(
                              Duration(milliseconds: position),
                            ),
                          ),
                          Text(
                            formatPracticeTimecode(
                              Duration(
                                milliseconds:
                                    widget.backing.candidate.binding.endMs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            container: true,
                            liveRegion: _capture.active,
                            child: _capture.active
                                ? Text(switch (_capture.phase) {
                                    PerformanceCapturePhase.checking =>
                                      '正在检查麦克风与空间…',
                                    PerformanceCapturePhase.countdown =>
                                      '${_capture.countdown} · 准备好上台',
                                    PerformanceCapturePhase.recording =>
                                      '正在录音 · ${_capture.elapsedMs ~/ 1000} 秒',
                                    PerformanceCapturePhase.finalizing =>
                                      '正在保留录音…',
                                    PerformanceCapturePhase.idle => '',
                                  }, key: const Key('stage_capture_status'))
                                : const SizedBox.shrink(),
                          ),
                          if (_capture.error != null)
                            Text(
                              _capture.error!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (_capture.permanentlyDenied)
                            TextButton(
                              onPressed: () => ref
                                  .read(practiceAudioRecorderProvider)
                                  .openAppSettings(),
                              child: const Text('打开麦克风设置'),
                            ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              if (_capture.recording)
                                FilledButton.icon(
                                  key: const Key('stage_capture_stop'),
                                  onPressed: _capture.stop,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('结束录音'),
                                )
                              else if (_capture.active)
                                TextButton(
                                  onPressed:
                                      _capture.phase ==
                                          PerformanceCapturePhase.finalizing
                                      ? null
                                      : _capture.stop,
                                  child: const Text('取消准备'),
                                )
                              else if (_capture.draft != null)
                                OutlinedButton.icon(
                                  key: const Key('stage_capture_review'),
                                  onPressed: _reviewDraft,
                                  icon: const Icon(Icons.headphones),
                                  label: const Text('回听未保存录音'),
                                )
                              else ...[
                                TextButton.icon(
                                  key: const Key('stage_capture_trial'),
                                  onPressed:
                                      _capture.loading ||
                                          _leaving ||
                                          _stage.busy
                                      ? null
                                      : () => _record(true),
                                  icon: const Icon(Icons.mic_none),
                                  label: const Text('麦克风试录'),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('stage_capture_start'),
                                  onPressed:
                                      _capture.loading ||
                                          _leaving ||
                                          _stage.busy
                                      ? null
                                      : () => _record(false),
                                  icon: const Icon(Icons.mic),
                                  label: const Text('录一遍'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '从头演奏',
                            onPressed:
                                _stage.busy || _leaving || _capture.active
                                ? null
                                : () => unawaited(_stage.seek(0)),
                            icon: const Icon(Icons.replay),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('stage_play'),
                              onPressed:
                                  _stage.busy || _leaving || _capture.active
                                  ? null
                                  : () => unawaited(_stage.toggle()),
                              icon: Icon(
                                _stage.playing ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(_stage.playing ? '暂停' : '开始演奏'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: '结束本次演奏',
                            onPressed: _leaving ? null : _leave,
                            icon: const Icon(Icons.stop_circle_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                return constraints.maxHeight < 600
                    ? SingleChildScrollView(child: content)
                    : content;
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _status(PerformanceStagePhase phase) => switch (phase) {
  PerformanceStagePhase.preparing => '正在准备舞台…',
  PerformanceStagePhase.ready => '伴奏就绪，轮到你上台了',
  PerformanceStagePhase.playing => '这一刻，舞台属于你',
  PerformanceStagePhase.paused => '已暂停，准备好后继续',
  PerformanceStagePhase.finished => '这场演奏结束了，谢谢你的投入',
  PerformanceStagePhase.error => '先调整一下，准备好再来',
};

class PerformanceCharacterSlot extends StatelessWidget {
  const PerformanceCharacterSlot({
    super.key,
    required this.phase,
    this.compact = false,
  });
  final PerformanceStagePhase phase;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '乐队伙伴舞台席位，${_status(phase)}',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 116,
              height: compact ? 64 : 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer.withValues(alpha: .55),
              ),
              child: Icon(
                phase == PerformanceStagePhase.finished
                    ? Icons.celebration_outlined
                    : Icons.auto_awesome,
                size: compact ? 28 : 44,
                color: colors.primary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Text('伙伴席位', style: Theme.of(context).textTheme.titleSmall),
            ],
          ],
        ),
      ),
    );
  }
}

class StageSpeaker extends StatefulWidget {
  const StageSpeaker({
    super.key,
    required this.level,
    required this.peak,
    required this.enabled,
    required this.label,
    this.compact = false,
  });
  final double level, peak;
  final bool enabled, compact;
  final String label;
  @override
  State<StageSpeaker> createState() => _StageSpeakerState();
}

class _StageSpeakerState extends State<StageSpeaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _vibration;
  @override
  void initState() {
    super.initState();
    _vibration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _update();
  }

  void _update() {
    if (widget.enabled && widget.level > 0) {
      if (!_vibration.isAnimating) _vibration.repeat();
    } else {
      _vibration.stop();
      _vibration.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant StageSpeaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _vibration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final v = widget.enabled ? widget.level.clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: '${widget.label}，${v > 0 ? '跟随伴奏' : '静止'}',
      child: AnimatedBuilder(
        animation: _vibration,
        builder: (context, _) {
          // A slow visual carrier simulates a moving cone; amplitude comes only from real PCM energy.
          final wave = v > 0 ? math.sin(_vibration.value * 2 * math.pi) : 0.0;
          return Container(
            width: widget.compact ? 52 : 70,
            height: widget.compact ? 84 : 128,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colors.surfaceContainerHighest,
              boxShadow: v > 0
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: v * .24),
                        blurRadius: 12 + v * 18,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, wave * v * 1.3),
                  child: Transform.scale(
                    key: ValueKey('${widget.label}_cone'),
                    scale: 1 + wave * v * .12,
                    child: Container(
                      width: widget.compact ? 28 : 45,
                      height: widget.compact ? 28 : 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.onSurfaceVariant.withValues(alpha: .85),
                      ),
                      child: Center(
                        child: Container(
                          width: widget.compact ? 10 : 16,
                          height: widget.compact ? 10 : 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      key: ValueKey('${widget.label}_meter'),
                      value: v,
                      backgroundColor: colors.primary.withValues(alpha: .12),
                      color: widget.peak >= .99 && widget.enabled
                          ? colors.error
                          : colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StageFlex extends StatelessWidget {
  const _StageFlex({required this.tiny, required this.child});
  final bool tiny;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      tiny ? SizedBox(height: 110, child: child) : Expanded(child: child);
}

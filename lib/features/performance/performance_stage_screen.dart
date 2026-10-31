import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    unawaited(_stage.initialize());
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
    unawaited(_stage.suspend());
  }

  @override
  void didPopNext() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _stage.resume();
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await _stage.leave();
    } on Object {
      if (!mounted) return;
      final leave = await showDialog<bool>(
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
    } else {
      unawaited(_stage.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    performanceRouteObserver.unsubscribe(this);
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
              tooltip: '舞台设置',
              onPressed: _settings,
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
                              position >= _chords!.binding.startMs &&
                              position < _chords!.binding.endMs,
                        ),
                      ),
                    _StageFlex(
                      tiny: constraints.maxHeight < 300,
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
                      onChanged: _stage.busy || _leaving
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '从头演奏',
                            onPressed: _stage.busy || _leaving
                                ? null
                                : () => unawaited(_stage.seek(0)),
                            icon: const Icon(Icons.replay),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('stage_play'),
                              onPressed: _stage.busy || _leaving
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
                return constraints.maxHeight < 300
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

class StageSpeaker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = enabled ? level.clamp(0.0, 1.0).toDouble() : 0.0;
    return Semantics(
      label: '$label，${enabled ? '跟随伴奏' : '静止'}',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: active),
        duration: enabled ? const Duration(milliseconds: 75) : Duration.zero,
        builder: (context, v, _) => Container(
          width: compact ? 52 : 70,
          height: compact ? 84 : 128,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.surfaceContainerHighest,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: v * .22),
                      blurRadius: 12 + v * 12,
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
              Transform.scale(
                scale: 1 + v * .10,
                child: Container(
                  width: compact ? 28 : 45,
                  height: compact ? 28 : 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onSurfaceVariant.withValues(alpha: .85),
                  ),
                  child: Center(
                    child: Container(
                      width: compact ? 10 : 16,
                      height: compact ? 10 : 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 3,
                color: peak >= .99 && enabled
                    ? colors.error
                    : colors.primary.withValues(alpha: .2 + v * .6),
              ),
            ],
          ),
        ),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recordings/practice_recording_providers.dart';
import 'application/performance_comparison_controller.dart';
import 'domain/performance_comparison.dart';
import 'performance_route_observer.dart';
import 'performance_take_providers.dart';

typedef ComparisonIds = ({String sourceId, String firstId, String secondId});

final performanceComparisonProvider = FutureProvider.autoDispose
    .family<PerformanceComparison, ComparisonIds>((ref, ids) async {
      final repository = ref.watch(practiceRecordingRepositoryProvider);
      final first = await repository.getById(ids.firstId);
      final second = await repository.getById(ids.secondId);
      if (first == null ||
          second == null ||
          first.sourceId != ids.sourceId ||
          second.sourceId != ids.sourceId) {
        throw const FormatException('录音已不存在，请返回列表重新选择');
      }
      return PerformanceComparison(
        PerformanceComparisonEntry.fromRecording(first),
        PerformanceComparisonEntry.fromRecording(second),
      );
    });

class PerformanceComparisonRouteScreen extends ConsumerWidget {
  const PerformanceComparisonRouteScreen({super.key, required this.ids});
  final ComparisonIds ids;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(performanceComparisonProvider(ids))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('演奏对比')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e is FormatException ? e.message : '录音读取失败，请重试'),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(performanceComparisonProvider(ids)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (comparison) => PerformanceComparisonScreen(
          key: ObjectKey(comparison),
          comparison: comparison,
        ),
      );
}

class PerformanceComparisonScreen extends ConsumerStatefulWidget {
  const PerformanceComparisonScreen({super.key, required this.comparison});
  final PerformanceComparison comparison;
  @override
  ConsumerState<PerformanceComparisonScreen> createState() =>
      _ComparisonState();
}

class _ComparisonState extends ConsumerState<PerformanceComparisonScreen>
    with WidgetsBindingObserver, RouteAware {
  late final PerformanceComparisonController _controller;
  PageRoute<dynamic>? _route;
  bool _leaving = false, _canPop = false;
  double? _drag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PerformanceComparisonController(
      widget.comparison,
      ref.read(practiceAudioRecorderProvider),
      ref.read(performanceAudioProvider),
    );
    unawaited(_controller.initialize());
  }

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
  void didPushNext() => unawaited(_controller.suspend());
  @override
  void didPopNext() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _controller.resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_route?.isCurrent != false) _controller.resume();
    } else {
      unawaited(_controller.suspend());
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _controller.close();
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    performanceRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pair = widget.comparison;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('演奏对比'),
          leading: BackButton(onPressed: _leave),
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final c = _controller;
              final enabled = !c.busy && c.error == null && !_leaving;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '听见不同时间的自己',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('选择 A 或 B，从原曲对应位置轮流回听。仅播放原始麦克风录音。'),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 2; i++)
                    Card(
                      color: c.active == i
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      child: ListTile(
                        key: Key('performance_compare_$i'),
                        selected: c.active == i,
                        enabled: enabled,
                        leading: Text(
                          i == 0 ? 'A' : 'B',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        title: Text(pair.entry(i).recording.title),
                        subtitle: Text(
                          '${_date(pair.entry(i).take.createdAt)}\n'
                          '${pair.entry(i).take.preset.speed.toStringAsFixed(2)}× 录制 · '
                          '${_time(pair.entry(i).take.durationMs)}',
                        ),
                        trailing: c.active == i
                            ? const Icon(Icons.hearing)
                            : const Icon(Icons.swap_horiz),
                        onTap: enabled ? () => c.select(i) : null,
                      ),
                    ),
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.error != null)
                    Text(
                      c.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('共同原曲区间 ${_time(pair.startMs)}–${_time(pair.endMs)}'),
                  Slider(
                    key: const Key('performance_compare_position'),
                    min: pair.startMs.toDouble(),
                    max: pair.endMs.toDouble(),
                    value: (_drag ?? c.sourceMs.toDouble()).clamp(
                      pair.startMs.toDouble(),
                      pair.endMs.toDouble(),
                    ),
                    semanticFormatterCallback: (v) => '原曲 ${_time(v.round())}',
                    onChanged: enabled
                        ? (v) => setState(() => _drag = v)
                        : null,
                    onChangeEnd: (v) {
                      setState(() => _drag = null);
                      unawaited(c.seek(v.round()));
                    },
                  ),
                  Text(
                    '原曲 ${_time((_drag ?? c.sourceMs).round())} · 当前 ${c.active == 0 ? 'A' : 'B'}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('performance_compare_play'),
                    onPressed: enabled ? c.toggle : null,
                    icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      c.playing ? '暂停对比' : '播放 ${c.active == 0 ? 'A' : 'B'}',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('回听音量'),
                  Slider(
                    key: const Key('performance_compare_volume'),
                    value: c.volume,
                    onChanged: enabled
                        ? (v) => unawaited(c.setVolume(v))
                        : null,
                  ),
                  if (pair.differentSpeeds)
                    const Text('两次录制的倍速不同，保留各自录制时的速度；切换时对齐原曲位置，不自动变速。'),
                  const SizedBox(height: 12),
                  const Text(
                    '位置沿用各次录音的起点估计与已保存试听对齐。耳机、编码和演奏起拍仍可能有误差；可先在单条演奏回听中调整并保存。',
                  ),
                  const SizedBox(height: 8),
                  const Text('回听不累计练习时长，不修改录音，也不生成评分。'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _time(int ms) =>
    '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';
String _date(DateTime date) {
  final d = date.toLocal();
  return '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

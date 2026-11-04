import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_recording/practice_recording.dart';
import '../audio_tools/algorithm_providers.dart';
import '../recordings/practice_recording_providers.dart';
import 'application/performance_review_controller.dart';
import 'domain/performance_take.dart';
import 'performance_resolver_providers.dart';
import 'performance_route_observer.dart';
import 'performance_take_providers.dart';
import 'performance_dialog.dart';
import 'performance_export_screen.dart';

final performanceReviewProvider = FutureProvider.autoDispose
    .family<({PerformanceTake take, PracticeRecording? saved}), String>((
      ref,
      id,
    ) async {
      final service = ref.watch(performanceTakeServiceProvider);
      final take = await service.recover(id);
      return (take: take, saved: await service.recordings.getById(id));
    });

class PerformanceReviewRouteScreen extends ConsumerWidget {
  const PerformanceReviewRouteScreen({super.key, required this.takeId});
  final String takeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(performanceReviewProvider(takeId))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('演奏回听')),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text('暂时无法恢复这条录音。可返回演奏录音列表重试；未完整写入的过短录音可能无法恢复。'),
          ),
        ),
        data: (entry) => PerformanceReviewScreen(
          key: ObjectKey(entry.take),
          take: entry.take,
          saved: entry.saved,
        ),
      );
}

class PerformanceReviewScreen extends ConsumerStatefulWidget {
  const PerformanceReviewScreen({super.key, required this.take, this.saved});
  final PerformanceTake take;
  final PracticeRecording? saved;
  @override
  ConsumerState<PerformanceReviewScreen> createState() =>
      _PerformanceReviewScreenState();
}

class _PerformanceReviewScreenState
    extends ConsumerState<PerformanceReviewScreen>
    with WidgetsBindingObserver, RouteAware {
  late final PerformanceReviewController _review;
  late final TextEditingController _title;
  bool _saved = false, _saving = false, _allowPop = false, _leaving = false;
  String _savedSignature = '';
  String get _signature =>
      '${_review.take.alignmentMs}|${_review.micVolume}|${_review.backingVolume}|${_title.text.trim()}';
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saved = widget.saved != null;

    _title = TextEditingController(
      text: widget.saved?.title ?? '演奏 · ${_date(widget.take.createdAt)}',
    );
    _review = PerformanceReviewController(
      widget.take,
      ref.read(practiceAudioRecorderProvider),
      ref.read(performanceAudioProvider),
      ref.read(algorithmMixPlatformProvider),
      ref.read(algorithmStemStoreProvider),
      ref.read(performanceSourceResolverProvider),
    );
    _savedSignature = _signature;
    unawaited(_review.initialize());
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
    unawaited(_review.suspend());
  }

  @override
  void didPopNext() {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _review.resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _review.resume();
    } else {
      unawaited(_review.suspend());
    }
  }

  Future<void> _save() async {
    if (_saving || widget.take.trial) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _review.pause();
      final title = _title.text.trim();
      if (title.isEmpty || title.length > 120) {
        throw const FormatException('请填写 1–120 字的录音标题');
      }
      await ref.read(performanceTakeServiceProvider).save(_review.take, title);
      if (mounted) {
        setState(() {
          _saved = true;
          _savedSignature = _signature;
          _message = '演奏已保存，可以从同曲演奏录音再次回听';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException
              ? e.message
              : '保存未完成，草稿与原始录音仍保留，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _linkPlan() async {
    if (_saving || !_saved) return;
    await _review.pause();
    if (!mounted) return;
    if (_savedSignature != _signature) {
      setState(() => _message = '请先保存本次回听调整，再关联计划');
      return;
    }
    final changed = await context.push<bool>(
      Uri(
        path: '/performance/plan',
        queryParameters: {'takeId': widget.take.id},
      ).toString(),
    );
    if (mounted && changed == true) {
      setState(() => _message = '计划关联已更新，可从计划的成果录音回听');
    }
  }

  Future<void> _export() async {
    if (_saving || !_saved) return;
    await _review.pause();
    if (!mounted) return;
    if (_savedSignature != _signature) {
      setState(() => _message = '请先保存本次回听调整，再导出音频');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PerformanceExportScreen(
          take: _review.take,
          title: _title.text.trim(),
        ),
      ),
    );
  }

  Future<void> _discard() async {
    await _review.pause();
    if (!mounted) return;
    final yes = await showPerformanceDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('丢弃这次录音？'),
        content: const Text('将删除本次原始录音与草稿，不影响伴奏或历史成果。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('丢弃'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await _review.close();
      await ref.read(performanceTakeServiceProvider).discard(_review.take);
      if (mounted) {
        _saved = true;
        _savedSignature = _signature;
        await _leave();
      }
    } on Object {
      if (mounted) setState(() => _message = '未能丢弃录音，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await _review.pause();
    if (!mounted) return;
    if (!_saved || _savedSignature != _signature) {
      final yes = await showPerformanceDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(_saved ? '回听调整尚未保存' : '录音尚未保存为成果'),
          content: Text(
            _saved
                ? '退出将使用上次保存的回听设置和标题。原始录音不变。'
                : '退出后保留录音草稿，可从演奏录音列表继续回听、保存或丢弃。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('继续回听'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('退出'),
            ),
          ],
        ),
      );
      if (yes != true) {
        _leaving = false;
        return;
      }
    }
    try {
      await _review.close();
    } on Object {
      /* Preserve the committed audio and permit a later cleanup retry. */
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _align(int ms) async {
    await _review.setAlignment(ms);
    if (!_saved) {
      try {
        await ref.read(performanceTakeStoreProvider).save(_review.take);
      } on Object {
        if (mounted) setState(() => _message = '对齐草稿未能保存，请在退出前重试保存');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    performanceRouteObserver.unsubscribe(this);
    _review.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !_saving) unawaited(_leave());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.take.trial ? '麦克风试录回听' : '演奏回听'),
        leading: BackButton(onPressed: _saving ? null : _leave),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _review,
          builder: (c, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.take.trial ? '先听听你的声音' : '把这一遍演奏留下来',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '原始麦克风录音 · ${_date(widget.take.createdAt)} · ${widget.take.preset.speed.toStringAsFixed(2)}× 伴奏',
              ),
              if (widget.take.reason != 'stopped' &&
                  widget.take.reason != 'trial')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.take.reason == 'backingStopped'
                        ? '伴奏已停止，本次录音已保留。'
                        : '这是一条中断后保留的录音，可先回听再决定是否保存。',
                  ),
                ),
              const SizedBox(height: 16),
              if (_review.busy) const LinearProgressIndicator(),
              if (_review.error != null)
                Text(
                  _review.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Slider(
                key: const Key('performance_review_position'),
                value: _review.positionMs.toDouble().clamp(
                  0,
                  widget.take.durationMs.toDouble(),
                ),
                max: widget.take.durationMs.toDouble().clamp(
                  1,
                  double.infinity,
                ),
                onChanged: _review.busy || _saving
                    ? null
                    : (v) => unawaited(_review.seek(v.round())),
              ),
              Text(
                '${_time(_review.positionMs)} / ${_time(widget.take.durationMs)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('performance_review_play'),
                onPressed: _review.busy || _saving ? null : _review.toggle,
                icon: Icon(_review.playing ? Icons.pause : Icons.play_arrow),
                label: Text(_review.playing ? '暂停回听' : '回听录音'),
              ),
              const SizedBox(height: 16),
              const Text('我的录音音量'),
              Slider(
                key: const Key('performance_review_mic'),
                value: _review.micVolume,
                onChanged: _saving
                    ? null
                    : (v) => unawaited(_review.setVolumes(mic: v)),
              ),
              if (!widget.take.trial) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同时播放本次伴奏'),
                  subtitle: Text(_review.backingError ?? '使用录制时保存的伴奏配置，无需重新分析'),
                  value: _review.useBacking && _review.backingReady,
                  onChanged: _review.backingReady && !_saving
                      ? (v) => unawaited(_review.setBacking(v))
                      : null,
                ),
                if (_review.backingReady) ...[
                  const Text('伴奏音量'),
                  Slider(
                    key: const Key('performance_review_backing'),
                    value: _review.backingVolume,
                    onChanged: _saving
                        ? null
                        : (v) => unawaited(_review.setVolumes(backing: v)),
                  ),
                  ExpansionTile(
                    title: const Text('试听对齐'),
                    subtitle: const Text('耳机与编码延迟尚未校准，可听后手动调整'),
                    children: [
                      Text('录音相对伴奏延后 ${_review.take.alignmentMs} ms（负值为提前）'),
                      Slider(
                        key: const Key('performance_review_alignment'),
                        value: _review.take.alignmentMs.toDouble(),
                        min: -2000,
                        max: 2000,
                        divisions: 400,
                        onChanged: _saving
                            ? null
                            : (v) => unawaited(_review.setAlignment(v.round())),
                        onChangeEnd: (v) => unawaited(_align(v.round())),
                      ),
                      TextButton(
                        onPressed: _saving ? null : () => unawaited(_align(0)),
                        child: const Text('恢复起点估计'),
                      ),
                      Text(
                        widget.take.leadMs == null
                            ? '本次起点估计不可用，默认从零开始试听；请以听感调整。'
                            : '录音与伴奏起点为估计值；若听起来有先后，可用上方滑块调整。',
                      ),
                      const Text('当前合听用于练习对比，设备与蓝牙延迟尚未校准；保存调整后可导出演奏音频。'),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 120,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: '演奏标题'),
                ),
                FilledButton.icon(
                  key: const Key('performance_take_save'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(
                    _saving
                        ? '正在保存…'
                        : _saved
                        ? '保存调整'
                        : '保存这次演奏',
                  ),
                ),
                if (_saved)
                  OutlinedButton.icon(
                    key: const Key('performance_take_link_plan'),
                    onPressed: _saving ? null : _linkPlan,
                    icon: const Icon(Icons.link),
                    label: const Text('关联／管理练习计划'),
                  ),
                if (_saved)
                  OutlinedButton.icon(
                    key: const Key('performance_take_export'),
                    onPressed: _saving ? null : _export,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('导出演奏音频'),
                  ),
              ],
              if (!_saved)
                TextButton(
                  key: const Key('performance_take_discard'),
                  onPressed: _saving ? null : _discard,
                  child: const Text('丢弃本次录音'),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_message!),
                ),
              const SizedBox(height: 12),
              const Text('回听不累计练习时长。建议戴耳机录制，外放伴奏可能被麦克风再次收到。'),
            ],
          ),
        ),
      ),
    ),
  );
}

String _time(int ms) =>
    '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';
String _date(DateTime date) {
  final d = date.toLocal();
  return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

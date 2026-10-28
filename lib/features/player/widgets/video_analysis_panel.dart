import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/practice_source/practice_source.dart';
import '../../../media/playback/local_video_playback_controller.dart';
import '../../audio_tools/algorithm_providers.dart';
import '../../audio_tools/data/algorithm_audio_import.dart';
import '../../audio_tools/domain/algorithm_task.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_analysis_binding.dart';

/// In-place tools for the current video. This never starts another practice session.
class VideoAnalysisPanel extends ConsumerStatefulWidget {
  const VideoAnalysisPanel({
    required this.source,
    required this.path,
    required this.controller,
    this.planId,
    this.enabled = true,
    this.requestedOperation,
    this.requestRevision = 0,
    super.key,
  });
  final PracticeSource source;
  final String path;
  final LocalVideoPlaybackController controller;
  final String? planId;
  final bool enabled;
  final AlgorithmOperation? requestedOperation;
  final int requestRevision;
  @override
  ConsumerState<VideoAnalysisPanel> createState() => _VideoAnalysisPanelState();
}

class _VideoAnalysisPanelState extends ConsumerState<VideoAnalysisPanel>
    with WidgetsBindingObserver {
  bool _expanded = false,
      _busy = false,
      _polling = false,
      _foreground = true,
      _useRange = false;
  bool _confirming = false;
  final _expansion = ExpansibleController();
  AlgorithmOperation _operation = AlgorithmOperation.chords;
  String _endpoint = '', _stage = '';
  double? _progress;
  Timer? _timer;
  List<AlgorithmTaskRecord> _tasks = [];
  Map<String, double> _volumes = {};
  final Set<String> _muted = {}, _solo = {};
  @override
  void initState() {
    super.initState();
    _endpoint = ref.read(algorithmEndpointProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  void didUpdateWidget(covariant VideoAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestRevision != oldWidget.requestRevision &&
        widget.requestedOperation != null &&
        !_busy) {
      _operation = widget.requestedOperation!;
      _open(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _expansion.expand();
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  void _open(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    _timer?.cancel();
    if (value) {
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_refresh()),
      );
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_polling || !_expanded || !_foreground || !mounted) return;
    _polling = true;
    final service = ref.read(algorithmTaskServiceProvider);
    try {
      for (final task in _tasks.where((t) => t.shouldPoll).take(4)) {
        if (!mounted || !_foreground || !_expanded) break;
        await service.refresh(task.id);
      }
    } on Object {
      /* Task cards retain their last durable status. */
    } finally {
      _polling = false;
    }
  }

  Future<void> _configureEndpoint() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _AnalysisValueDialog(
        title: '连接分析服务',
        label: 'HTTPS 服务地址',
        initial: _endpoint,
        validate: (text) {
          try {
            AlgorithmEndpoint(text, allowLocalHttp: true);
            return null;
          } on FormatException catch (e) {
            return e.message;
          }
        },
      ),
    );
    if (value != null && mounted) {
      setState(
        () => _endpoint = AlgorithmEndpoint(
          value,
          allowLocalHttp: true,
        ).origin.toString(),
      );
    }
  }

  Future<void> _submit() async {
    if (_busy || _confirming || !widget.enabled) return;
    _confirming = true;
    try {
      await _prepareAndSubmit();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _prepareAndSubmit() async {
    if (_endpoint.isEmpty) {
      await _configureEndpoint();
      if (!mounted || _endpoint.isEmpty) return;
    }
    final controller = widget.controller;
    final range = _useRange ? controller.loopController.range : null;
    final start = range?.start.inMilliseconds ?? 0;
    final end = range?.end.inMilliseconds ?? controller.duration.inMilliseconds;
    if (end - start < 2000 || end - start > 600000) {
      _message('请选择 2 秒至 10 分钟的视频或 A-B 区间');
      return;
    }
    late AlgorithmEndpoint endpoint;
    try {
      endpoint = AlgorithmEndpoint(_endpoint, allowLocalHttp: true);
    } on FormatException catch (e) {
      _message(e.message);
      return;
    }
    await controller.pause();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _operation == AlgorithmOperation.chords ? '分析当前视频的和弦？' : '分离当前视频的音轨？',
        ),
        content: Text(
          '「${widget.source.title}」\n${_time(start)}–${_time(end)}\n仅提取并上传此区间的音频，视频保留在本机。\n接收服务：${endpoint.origin}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('video_analysis_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始分析'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final extractor = ref.read(videoAudioExtractorProvider);
    final importer = ref.read(algorithmAudioImportProvider);
    final service = ref.read(algorithmTaskServiceProvider);
    final repository = ref.read(algorithmTaskRepositoryProvider);
    final taskId = const Uuid().v4();
    AlgorithmAudioInput? input;
    bool handedOff = false;
    setState(() {
      _busy = true;
      _stage = '正在提取当前视频音频…';
      _progress = null;
    });
    try {
      final before = await File(widget.path).stat();
      final extracted = await extractor.extract(widget.path, start, end);
      input = extracted.input;
      if (!mounted) return;
      final after = await File(widget.path).stat();
      if (before.size != after.size || before.modified != after.modified) {
        throw const FormatException('视频文件已变化，请重试');
      }
      final binding = VideoAnalysisBinding(
        sourceId: widget.source.id,
        path: widget.path,
        sourceBytes: before.size,
        modifiedMs: before.modified.millisecondsSinceEpoch,
        sourceDurationMs: controller.duration.inMilliseconds,
        startMs: start,
        durationMs: end - start,
        inputSha256: extracted.sha256,
        waveform: extracted.waveform,
      );
      final now = DateTime.now().toUtc();
      setState(() => _stage = '正在上传音频…');
      await service.submit(
        AlgorithmTaskRecord(
          id: taskId,
          endpoint: endpoint.origin.toString(),
          inputPath: input.path,
          inputName: 'video-audio.wav',
          inputSizeBytes: input.sizeBytes,
          inputDurationMs: input.duration.inMilliseconds,
          ownsInput: true,
          state: AlgorithmTaskState.submitting,
          createdAt: now,
          updatedAt: now,
          failures: 0,
          operation: _operation,
          linkedSourceId: widget.source.id,
          linkedPlanId: widget.planId,
          mediaBindingJson: jsonEncode(binding.toJson()),
        ),
        onProgress: (sent, total) {
          if (mounted) setState(() => _progress = sent / total);
        },
      );
      handedOff = true;
      unawaited(_refresh());
    } on Object catch (e) {
      try {
        handedOff = await repository.get(taskId) != null;
      } on Object {
        handedOff = true;
      }
      _message(_errorMessage(e, '分析准备失败，请检查连接后重试'));
    } finally {
      if (input != null && !handedOff) {
        await importer.deleteInput(input.path).catchError((Object _) {});
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = '';
          _progress = null;
        });
      }
    }
  }

  VideoAnalysisBinding _binding(AlgorithmTaskRecord task) =>
      VideoAnalysisBinding.fromJson(
        algorithmObject(jsonDecode(task.mediaBindingJson!)),
      );
  Future<void> _verify(VideoAnalysisBinding binding) async {
    if (!binding.matches(
      widget.source.id,
      widget.path,
      await File(widget.path).stat(),
    )) {
      throw const FormatException('视频文件已变化，此结果不能用于当前视频，请重新分析');
    }
  }

  Future<void> _loadStems(AlgorithmTaskRecord task) async {
    if (_busy) return;
    final store = ref.read(algorithmStemStoreProvider);
    setState(() {
      _busy = true;
      _stage = '正在准备当前视频的音轨…';
    });
    try {
      await widget.controller.pause();
      final binding = _binding(task);
      await _verify(binding);
      final result = LegacySeparationResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
        AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
      );
      if ((result.duration.inMilliseconds - binding.durationMs).abs() > 100) {
        throw const FormatException('分轨时间轴与本视频区间不一致');
      }
      final paths = <String, String>{};
      for (final stem in result.stems.where((s) => s.id != 'instrumental')) {
        final file = await store.download(
          task.id,
          stem,
          onProgress: (received, total) {
            if (mounted) {
              setState(() {
                _stage = '下载${stem.displayName}…';
                _progress = received / total;
              });
            }
          },
        );
        paths[stem.id] = file.path;
      }
      if (!mounted) return;
      await _verify(binding);
      await widget.controller.loadStems(
        paths,
        binding.startMs,
        binding.durationMs,
      );
      setState(() {
        _volumes = {for (final id in paths.keys) id: 1};
        _muted.clear();
        _solo.clear();
      });
    } on Object catch (e) {
      _message(_errorMessage(e, '无法使用分轨，请检查连接或重新下载'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = '';
          _progress = null;
        });
      }
    }
  }

  Future<void> _applyGains() async {
    final anySolo = _solo.isNotEmpty;
    try {
      await widget.controller.setStemGains({
        for (final id in _volumes.keys)
          id: _muted.contains(id) || (anySolo && !_solo.contains(id))
              ? 0
              : _volumes[id]!,
      });
    } on Object {
      _message('音轨控制失败，请重新载入分轨');
    }
  }

  Future<void> _seekVerified(VideoAnalysisBinding binding, int sourceMs) async {
    try {
      await _verify(binding);
      await widget.controller.seek(Duration(milliseconds: sourceMs));
    } on Object catch (e) {
      _message(e is FormatException ? e.message : '无法定位当前视频');
    }
  }

  Future<void> _calibrate(AlgorithmTaskRecord task) async {
    final binding = _binding(task);
    final result = LegacyChordResult.fromJson(
      algorithmObject(jsonDecode(task.resultJson!)),
    );
    await widget.controller.pause();
    if (!mounted) return;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _AnalysisValueDialog(
        title: '校准和弦时间',
        label: '分析 0 秒对应的视频时间（秒）',
        initial: binding.manualChordZeroMs == null
            ? ''
            : (binding.manualChordZeroMs! / 1000).toStringAsFixed(3),
        description:
            '服务裁剪了静音但未返回偏移。请对照视频确认位置；这是人工显示校准，不会改写算法结果。当前视频位置：${_time(widget.controller.position.inMilliseconds)}',
        validate: (text) {
          if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
            return '请输入秒数，最多三位小数';
          }
          final seconds = double.tryParse(text);
          if (seconds == null || !seconds.isFinite) return '请输入有效秒数';
          final zero = (seconds * 1000).round();
          if (zero < binding.startMs ||
              zero + result.duration.inMilliseconds > binding.endMs + 20) {
            return '校准后的和弦必须位于本次分析区间内';
          }
          return null;
        },
      ),
    );
    if (value == null || !mounted) return;
    try {
      await _verify(binding);
      await ref
          .read(algorithmTaskRepositoryProvider)
          .updateMediaBinding(
            task.id,
            jsonEncode(
              binding
                  .withChordZero((double.parse(value) * 1000).round())
                  .toJson(),
            ),
          );
    } on Object catch (e) {
      _message(e is FormatException ? e.message : '校准保存失败');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return ExpansionTile(
        controller: _expansion,
        title: const Text('和弦与分轨'),
        subtitle: const Text('直接分析当前视频，在这里练习'),
        onExpansionChanged: _open,
      );
    }
    final tasks = ref.watch(algorithmTasksProvider);
    _tasks = (tasks.asData?.value ?? [])
        .where(
          (t) =>
              t.linkedSourceId == widget.source.id &&
              t.mediaBindingJson != null,
        )
        .toList();
    if (_endpoint.isEmpty && _tasks.isNotEmpty) {
      _endpoint = _tasks.first.endpoint;
    }
    return ExpansionTile(
      controller: _expansion,
      initiallyExpanded: true,
      title: const Text('和弦与分轨'),
      onExpansionChanged: _open,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        const Text('共用当前视频、播放进度、倍速与 A-B；无需再次导入或关联曲目。'),
        const SizedBox(height: 8),
        SegmentedButton<AlgorithmOperation>(
          segments: const [
            ButtonSegment(value: AlgorithmOperation.chords, label: Text('扒和弦')),
            ButtonSegment(
              value: AlgorithmOperation.separation,
              label: Text('分轨'),
            ),
          ],
          selected: {_operation},
          onSelectionChanged: _busy
              ? null
              : (values) => setState(() => _operation = values.single),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('仅分析当前 A-B 区间'),
          value: _useRange,
          onChanged: _busy || widget.controller.loopController.range == null
              ? null
              : (v) => setState(() => _useRange = v),
        ),
        FilledButton.icon(
          key: const Key('video_analysis_submit'),
          onPressed: _busy || !widget.enabled ? null : _submit,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            _operation == AlgorithmOperation.chords ? '分析当前视频和弦' : '分离当前视频音轨',
          ),
        ),
        if (_endpoint.isEmpty)
          TextButton(
            onPressed: _busy ? null : _configureEndpoint,
            child: const Text('连接分析服务'),
          ),
        if (_busy) ...[Text(_stage), LinearProgressIndicator(value: _progress)],
        if (widget.controller.stemsLoaded) ...[
          const Divider(),
          Text(widget.controller.stemsActive ? '当前播放：分轨（原视频已静音）' : '当前区间外播放原声'),
          TextButton(
            onPressed: _busy ? null : widget.controller.clearStems,
            child: const Text('切回视频原声'),
          ),
          ExpansionTile(
            title: const Text('音轨音量、静音与独奏'),
            initiallyExpanded: true,
            children: [
              for (final id in _volumes.keys)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(_stemName(id))),
                        FilterChip(
                          label: const Text('静音'),
                          selected: _muted.contains(id),
                          onSelected: (v) {
                            setState(() {
                              v ? _muted.add(id) : _muted.remove(id);
                            });
                            unawaited(_applyGains());
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('独奏'),
                          selected: _solo.contains(id),
                          onSelected: (v) {
                            setState(() {
                              v ? _solo.add(id) : _solo.remove(id);
                              if (v) _muted.remove(id);
                            });
                            unawaited(_applyGains());
                          },
                        ),
                      ],
                    ),
                    Slider(
                      value: _volumes[id]!,
                      onChanged: (v) => setState(() => _volumes[id] = v),
                      onChangeEnd: (_) => unawaited(_applyGains()),
                    ),
                  ],
                ),
            ],
          ),
        ],
        tasks.when(
          loading: () => const Text('正在读取本视频分析…'),
          error: (_, _) => const Text('分析记录读取失败，请稍后重新打开'),
          data: (_) => Column(
            children: [
              for (final task
                  in _tasks.where((t) => t.operation == _operation).take(5))
                _taskCard(task),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskCard(AlgorithmTaskRecord task) {
    try {
      final binding = _binding(task);
      if (!binding.matches(
        widget.source.id,
        widget.path,
        File(widget.path).statSync(),
      )) {
        return const Text('视频文件版本已变化，请重新分析；旧结果不会应用到新视频。');
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_time(binding.startMs)}–${_time(binding.endMs)} · ${task.operation == AlgorithmOperation.chords ? '和弦' : '音轨'}',
              ),
              if (binding.waveform.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapUp: !widget.enabled
                        ? null
                        : (details) => _seekVerified(
                            binding,
                            binding.startMs +
                                (details.localPosition.dx /
                                        constraints.maxWidth *
                                        binding.durationMs)
                                    .round()
                                    .clamp(0, binding.durationMs),
                          ),
                    child: SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          binding.waveform,
                          Theme.of(context).colorScheme.primary,
                          cursor:
                              (widget.controller.position.inMilliseconds -
                                  binding.startMs) /
                              binding.durationMs,
                        ),
                      ),
                    ),
                  ),
                ),
              Text(task.message ?? task.state.name),
              if (task.shouldPoll)
                LinearProgressIndicator(
                  value: task.progress == null ? null : task.progress! / 100,
                ),
              if (task.resultJson != null &&
                  task.operation == AlgorithmOperation.chords)
                ..._chords(task),
              if (task.resultJson != null &&
                  task.operation == AlgorithmOperation.separation)
                TextButton(
                  onPressed: _busy || !widget.enabled
                      ? null
                      : () => _loadStems(task),
                  child: const Text('在当前视频中使用分轨'),
                ),
              if (task.remoteJobId != null && task.resultJson == null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref
                            .read(algorithmTaskServiceProvider)
                            .refresh(task.id, force: true),
                  child: const Text('重新查询'),
                ),
            ],
          ),
        ),
      );
    } on Object {
      return const Text('本视频分析记录需要更新，请重新分析');
    }
  }

  List<Widget> _chords(AlgorithmTaskRecord task) {
    final result = LegacyChordResult.fromJson(
      algorithmObject(jsonDecode(task.resultJson!)),
    );
    final binding = _binding(task);
    final zero = binding.manualChordZeroMs;
    final position = widget.controller.position.inMilliseconds - (zero ?? 0);
    final current = zero == null
        ? null
        : result.segments
              .where(
                (s) =>
                    s.start.inMilliseconds <= position &&
                    position < s.end.inMilliseconds,
              )
              .firstOrNull;
    final next = zero == null
        ? null
        : result.segments
              .where((s) => s.start.inMilliseconds > position)
              .firstOrNull;
    return [
      if (result.keyEstimate.isNotEmpty) Text('调性参考：${result.keyEstimate}'),
      Text(
        zero == null
            ? '当前为分析相对时间。校准后可随视频显示和定位。'
            : '当前：${current?.displayLabel ?? '—'}   下一个：${next?.displayLabel ?? '—'} · 人工校准',
      ),
      TextButton(
        onPressed: _busy || !widget.enabled ? null : () => _calibrate(task),
        child: Text(zero == null ? '与视频时间校准' : '调整人工校准'),
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final segment in result.segments.take(80))
            InputChip(
              selected: identical(current, segment),
              onPressed: zero == null || !widget.enabled
                  ? null
                  : () => _seekVerified(
                      binding,
                      zero + segment.start.inMilliseconds,
                    ),
              label: Text(
                '${segment.displayLabel}  ${_time((zero ?? 0) + segment.start.inMilliseconds)}',
              ),
            ),
        ],
      ),
    ];
  }
}

String _time(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
String _errorMessage(Object error, String fallback) {
  if (error is FormatException) return error.message;
  if (error is PlatformException && error.message != null) {
    return error.message!;
  }
  return fallback;
}

String _stemName(String id) =>
    const {
      'vocals': '人声',
      'drums': '鼓',
      'bass': '贝斯',
      'guitar': '吉他',
      'piano': '钢琴',
      'other': '其他',
    }[id] ??
    id;

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.peaks, this.color, {required this.cursor});
  final double cursor;
  final List<double> peaks;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (var i = 0; i < peaks.length; i++) {
      final x = size.width * (i + .5) / peaks.length,
          half = size.height * peaks[i] / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - half),
        Offset(x, size.height / 2 + half),
        paint,
      );
    }
    if (cursor >= 0 && cursor <= 1) {
      canvas.drawLine(
        Offset(cursor * size.width, 0),
        Offset(cursor * size.width, size.height),
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.color != color ||
      oldDelegate.cursor != cursor;
}

class _AnalysisValueDialog extends StatefulWidget {
  const _AnalysisValueDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.validate,
    this.description,
  });
  final String title, label, initial;
  final String? description;
  final String? Function(String) validate;
  @override
  State<_AnalysisValueDialog> createState() => _AnalysisValueDialogState();
}

class _AnalysisValueDialogState extends State<_AnalysisValueDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.description != null) Text(widget.description!),
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(labelText: widget.label),
            validator: (s) => widget.validate(s?.trim() ?? ''),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('确认'),
      ),
    ],
  );
}

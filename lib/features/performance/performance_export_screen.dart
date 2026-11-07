import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_tools/algorithm_providers.dart';
import '../recordings/practice_recording_providers.dart';
import 'application/performance_export_service.dart';
import 'data/performance_export_platform.dart';
import 'domain/performance_take.dart';
import 'performance_resolver_providers.dart';
import 'performance_dialog.dart';

final performanceExportPlatformProvider = Provider(
  (ref) => const PerformanceExportPlatform(),
);
final performanceExportServiceProvider = Provider(
  (ref) => PerformanceExportService(
    ref.watch(practiceAudioRecorderProvider),
    ref.watch(algorithmStemStoreProvider),
    ref.watch(performanceSourceResolverProvider),
    ref.watch(performanceExportPlatformProvider),
  ),
);

class PerformanceExportScreen extends ConsumerStatefulWidget {
  const PerformanceExportScreen({
    super.key,
    required this.take,
    required this.title,
  });
  final PerformanceTake take;
  final String title;
  @override
  ConsumerState<PerformanceExportScreen> createState() =>
      _PerformanceExportScreenState();
}

class _PerformanceExportScreenState
    extends ConsumerState<PerformanceExportScreen>
    with WidgetsBindingObserver {
  bool _backing = true,
      _busy = false,
      _external = false,
      _playing = false,
      _foreground = true;
  bool _polling = false, _rendering = false, _generating = false;
  bool _cancelling = false, _allowPop = false, _leaving = false;
  bool _savedToFiles = false, _failed = false;
  bool _editingSettings = false, _resultBacking = true;
  int _generation = 0;
  double _progress = 0;
  String _stage = '', _message = '';
  PerformanceExportResult? _result;
  Timer? _timer;
  late final PerformanceExportPlatform _platform;
  @override
  void initState() {
    super.initState();
    _platform = ref.read(performanceExportPlatformProvider);
    _backing = widget.take.preset.speed == 1;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_poll()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      if (!_external) ++_generation;
      setState(() => _playing = false);
      unawaited(_platform.stop().catchError((Object _) {}));
      if (_generating) {
        unawaited(_platform.cancel().catchError((Object _) {}));
      }
      // Also invalidate a preparation that has not reached the native renderer yet.
      if (_generating) {
        setState(() {
          _stage = '正在停止导出';
          _message = '导出已中断，原始录音仍保留，可重试';
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_polling ||
        (!_rendering && !_playing) ||
        (_busy && !_rendering) ||
        !_foreground ||
        _external) {
      return;
    }
    _polling = true;
    final token = _generation;
    try {
      final s = await _platform.snapshot();
      if (mounted &&
          _foreground &&
          !_external &&
          (!_busy || _rendering) &&
          token == _generation) {
        setState(() {
          _progress = ((s['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1);
          if (!_cancelling) _stage = s['stage'] as String? ?? '';
          _playing = s['playing'] == true;
        });
      }
    } on Object {
      /* Render/play action reports errors; polling must not hide them. */
    } finally {
      _polling = false;
    }
  }

  String _error(Object e) => e is FormatException
      ? e.message
      : e is PlatformException
      ? e.message ?? '音频操作未完成，请重试'
      : '音频操作未完成，请检查本机文件与空间后重试';
  Future<void> _render() async {
    if (_busy || !_foreground) return;
    final token = ++_generation;
    setState(() {
      _busy = true;
      _generating = true;
      _cancelling = false;
      _failed = false;
      _editingSettings = true;
      _playing = false;
      _message = '';
      _stage = '校验本机录音与伴奏';
      _progress = 0;
    });
    try {
      await _platform.stop();
      final snapshot = await ref
          .read(performanceExportServiceProvider)
          .prepare(widget.take, withBacking: _backing);
      if (!mounted || token != _generation || !_foreground) return;
      _rendering = true;
      final result = await _platform.render(snapshot);
      try {
        await ref
            .read(performanceExportServiceProvider)
            .verify(widget.take, snapshot, withBacking: _backing);
      } on Object {
        await _platform.discard(result.id).catchError((Object _) {});
        rethrow;
      }
      if (!mounted || token != _generation) return;
      setState(() {
        _result = result;
        _resultBacking = _backing;
        _savedToFiles = false;
        _editingSettings = false;
        _message = '音频已生成，可先回听再保存或分享';
      });
    } on Object catch (e) {
      if (mounted && token == _generation) {
        setState(() {
          _message = _error(e);
          _failed = true;
        });
      }
    } finally {
      _rendering = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _generating = false;
          _cancelling = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_cancelling) return;
    ++_generation;
    _cancelling = true;
    setState(() => _stage = '正在停止导出');
    await _platform.cancel().catchError((Object _) {});
    if (mounted) {
      setState(() {
        _message = '导出已取消，原始录音仍保留';
      });
    }
  }

  Future<void> _action(String action) async {
    final result = _result;
    if (result == null || _busy || !_foreground) return;
    final token = ++_generation;
    final play = !_playing;
    setState(() {
      _busy = true;
      if (action != 'play') _playing = false;
      _external = action != 'play';
      _message = '';
    });
    try {
      if (action == 'play') {
        if (!play) {
          await _platform.stop();
        } else {
          await _platform.play(result.id);
        }
        if (!_foreground) await _platform.stop();
        if (mounted && token == _generation) {
          setState(() => _playing = play && _foreground);
        }
      } else if (action == 'save') {
        final saved = await _platform.save(result.id, widget.title);
        if (mounted) {
          setState(() {
            _savedToFiles = _savedToFiles || saved;
            _message = saved ? '已保存到你选择的位置' : '已取消保存，本机作品仍保留，可再次保存';
          });
        }
      } else {
        await _platform.share(result.id);
        if (mounted) setState(() => _message = '已打开系统分享，是否发送由你选择');
      }
    } on Object catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _external = false;
        });
      }
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    if (_generating) {
      final leave = await showPerformanceDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('停止生成并返回？'),
          content: const Text('本次生成会停止，原始录音仍保留。稍后可重新导出。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('继续生成'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('停止并返回'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) {
        _leaving = false;
        return;
      }
      await _cancel();
    }
    await _platform.stop().catchError((Object _) {});
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _changeBacking(bool value) {
    setState(() {
      _backing = value;
      _message = '';
      _failed = false;
    });
  }

  void _editSettings() {
    ++_generation;
    unawaited(_platform.stop().catchError((Object _) {}));
    setState(() {
      _editingSettings = true;
      _playing = false;
      _message = '';
      _failed = false;
    });
  }

  void _restoreResult() {
    ++_generation;
    setState(() {
      _backing = _resultBacking;
      _editingSettings = false;
      _message = '';
      _failed = false;
    });
  }

  @override
  void dispose() {
    ++_generation;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_platform.cancel().catchError((Object _) {}));
    unawaited(_platform.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) unawaited(_leave());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('导出演奏音频'),
        leading: BackButton(onPressed: _leave),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(widget.take.durationMs / 1000).toStringAsFixed(1)} 秒 · ${widget.take.preset.speed.toStringAsFixed(2)}× 演奏',
                ),
                const SizedBox(height: 16),
                if (_result case final result? when !_editingSettings) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            _savedToFiles
                                ? Icons.task_alt
                                : Icons.audio_file_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _savedToFiles ? '已保存到文件' : '音频已生成',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _resultBacking ? '我的演奏 + 本次伴奏' : '仅我的录音',
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'WAV · ${(result.bytes / 1024 / 1024).toStringAsFixed(1)} MB',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('performance_export_save'),
                            onPressed: _busy ? null : () => _action('save'),
                            icon: const Icon(Icons.save_alt),
                            label: Text(_savedToFiles ? '另存一份' : '保存到文件'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _action('play'),
                            icon: Icon(
                              _playing ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(_playing ? '停止回听' : '回听导出音频'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('performance_export_share'),
                            onPressed: _busy ? null : () => _action('share'),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('系统分享'),
                          ),
                          if (!_savedToFiles)
                            const Text('请保存到文件以长期留存，本机临时作品会在 7 天后清理。'),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('音频详情'),
                            children: [
                              const Text('44.1 kHz · 16 bit · 立体声'),
                              Text(
                                '整体防削顶衰减 ${math.max(0, -20 * math.log(result.attenuation) / math.ln10).toStringAsFixed(1)} dB',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_result == null || _editingSettings) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('混入本次伴奏'),
                    subtitle: Text(
                      widget.take.preset.speed == 1
                          ? '沿用录制时的选轨与已保存的回听音量'
                          : '当前仅支持 1.00× 伴奏混音，此成果可仅导出录音',
                    ),
                    value: _backing,
                    onChanged: _busy || widget.take.preset.speed != 1
                        ? null
                        : _changeBacking,
                  ),
                  Text(
                    _backing
                        ? '将伴奏与录音合成一个音频文件，使用已保存的试听对齐。'
                        : '将我的录音另存为 WAV，应用已保存的录音音量。',
                  ),
                  const SizedBox(height: 16),
                ],
                if (_generating) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(_cancelling ? '正在停止生成…' : _stage),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                  ),
                  if (_progress > 0) Text('${(_progress * 100).floor()}%'),
                  TextButton(
                    key: const Key('performance_export_cancel'),
                    onPressed: _cancelling ? null : _cancel,
                    child: const Text('取消生成'),
                  ),
                ],
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(liveRegion: true, child: Text(_message)),
                  ),
                if (_result == null || _editingSettings)
                  FilledButton.icon(
                    key: const Key('performance_export_render'),
                    onPressed: _busy ? null : _render,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: Text(
                      _failed
                          ? '重试生成'
                          : _result == null
                          ? '生成音频'
                          : '重新生成音频',
                    ),
                  ),
                if (_failed && _backing && !_busy)
                  OutlinedButton(
                    onPressed: () {
                      _changeBacking(false);
                      unawaited(_render());
                    },
                    child: const Text('仅导出录音'),
                  ),
                if (_result != null && _editingSettings)
                  OutlinedButton(
                    key: const Key('performance_export_restore'),
                    onPressed: _busy ? null : _restoreResult,
                    child: const Text('返回已生成音频'),
                  ),
                if (_result != null && !_editingSettings)
                  TextButton.icon(
                    key: const Key('performance_export_render'),
                    onPressed: _busy ? null : _editSettings,
                    icon: const Icon(Icons.tune),
                    label: const Text('调整导出设置'),
                  ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('格式与注意事项'),
                  children: [
                    const Text(
                      'WAV · 44.1 kHz · 16 bit · 立体声。仅使用本机文件，原始录音保持不变，导出不增加练习时长。',
                    ),
                    Text(
                      '试听微调 ${widget.take.alignmentMs} ms；设备与蓝牙延迟仍需凭听感校准。建议戴耳机录制，避免麦克风再次收到外放伴奏。',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

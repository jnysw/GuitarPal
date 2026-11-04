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
  bool _polling = false, _rendering = false;
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
      unawaited(_platform.stop().catchError((Object _) {}));
      if (_busy && !_external) {
        unawaited(_platform.cancel().catchError((Object _) {}));
      }
      // Also invalidate a preparation that has not reached the native renderer yet.
      if (_busy && !_external) {
        ++_generation;
        setState(() {
          _stage = '正在停止导出';
          _message = '导出已中断，原始录音仍保留，可重试';
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_polling || (!_rendering && !_playing) || !_foreground || _external) {
      return;
    }
    _polling = true;
    try {
      final s = await _platform.snapshot();
      if (mounted) {
        setState(() {
          _progress = ((s['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1);
          _stage = s['stage'] as String? ?? '';
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
      _result = null;
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
        _message = '音频已生成，可先回听再保存或分享';
      });
    } on Object catch (e) {
      if (mounted && token == _generation) {
        setState(() => _message = _error(e));
      }
    } finally {
      _rendering = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    ++_generation;
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
    if (result == null || _busy) return;
    setState(() {
      _busy = true;
      _external = action != 'play';
      _message = '';
    });
    try {
      if (action == 'play') {
        final play = !_playing;
        if (!play) {
          await _platform.stop();
        } else {
          await _platform.play(result.id);
        }
        if (mounted) setState(() => _playing = play);
      } else if (action == 'save') {
        final saved = await _platform.save(result.id, widget.title);
        if (mounted) {
          setState(() => _message = saved ? '已保存到你选择的位置' : '已取消保存，本机作品仍保留');
        }
      } else {
        await _platform.share(result.id);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('导出演奏音频')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            '完整录音 ${(widget.take.durationMs / 1000).toStringAsFixed(1)} 秒 · 录制速度 ${widget.take.preset.speed.toStringAsFixed(2)}×',
          ),
          const Text('WAV · 44.1 kHz · 16 bit · 立体声'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('混入本次伴奏'),
            subtitle: Text(
              widget.take.preset.speed == 1
                  ? '使用保存的选轨、静音、独奏、声像和回听音量'
                  : '当前仅支持 1.00× 伴奏混音，此成果可仅导出录音',
            ),
            value: _backing,
            onChanged: _busy || widget.take.preset.speed != 1
                ? null
                : (v) {
                    unawaited(_platform.stop().catchError((Object _) {}));
                    setState(() {
                      _backing = v;
                      _result = null;
                      _playing = false;
                    });
                  },
          ),
          Text(
            _backing
                ? '试听微调 ${widget.take.alignmentMs} ms；伴奏仅在实际演奏区间混入。设备与蓝牙延迟仍需凭听感校准。'
                : '仅导出麦克风录音，应用已保存的录音音量。',
          ),
          const SizedBox(height: 12),
          const Text('全程使用本机文件。伴奏缺失时可关闭上方开关，仅导出录音。建议戴耳机录制，外放伴奏可能被麦克风再次收到。'),
          const SizedBox(height: 20),
          if (_busy && !_external) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            Text(_stage),
            TextButton(onPressed: _cancel, child: const Text('取消导出')),
          ],
          FilledButton.icon(
            key: const Key('performance_export_render'),
            onPressed: _busy ? null : _render,
            icon: const Icon(Icons.audio_file_outlined),
            label: Text(_result == null ? '生成音频' : '重新生成'),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 12),
            Text(
              '${(result.bytes / 1024 / 1024).toStringAsFixed(1)} MB · 整体防削顶衰减 ${(-20 * math.log(result.attenuation) / math.ln10).toStringAsFixed(1)} dB',
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _action('play'),
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              label: Text(_playing ? '停止回听' : '回听导出音频'),
            ),
            FilledButton.tonalIcon(
              key: const Key('performance_export_save'),
              onPressed: _busy ? null : () => _action('save'),
              icon: const Icon(Icons.save_alt),
              label: const Text('保存到文件'),
            ),
            OutlinedButton.icon(
              key: const Key('performance_export_share'),
              onPressed: _busy ? null : () => _action('share'),
              icon: const Icon(Icons.share_outlined),
              label: const Text('系统分享'),
            ),
          ],
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message),
            ),
          const SizedBox(height: 12),
          const Text('原始录音保持不变，导出不增加练习时长。本机临时作品保留 7 天，请用“保存到文件”留存。'),
        ],
      ),
    ),
  );
}

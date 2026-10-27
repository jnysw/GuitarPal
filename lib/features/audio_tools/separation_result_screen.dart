import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'algorithm_providers.dart';
import 'data/algorithm_stem_store.dart';
import 'domain/algorithm_task.dart';
import 'domain/legacy_algorithm_models.dart';
import 'stem_mix_screen.dart';

class SeparationResultScreen extends ConsumerStatefulWidget {
  const SeparationResultScreen({required this.task, super.key});
  final AlgorithmTaskRecord task;
  @override
  ConsumerState<SeparationResultScreen> createState() =>
      _SeparationResultScreenState();
}

class _SeparationResultScreenState extends ConsumerState<SeparationResultScreen>
    with WidgetsBindingObserver {
  late final AlgorithmStemPlatform _player;
  late final AlgorithmStemStore _store;
  LegacySeparationResult? _result;
  String? _error, _downloading, _active;
  final Map<String, String> _local = {};
  double? _progress;
  bool _playing = false, _busy = false, _polling = false;
  Duration _position = Duration.zero, _duration = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = ref.read(algorithmStemPlatformProvider);
    _store = ref.read(algorithmStemStoreProvider);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = LegacySeparationResult.fromJson(
        algorithmObject(jsonDecode(widget.task.resultJson!)),
        AlgorithmEndpoint(widget.task.endpoint, allowLocalHttp: kDebugMode),
      );
      for (final stem in result.stems) {
        final file = await _store.localFile(widget.task.id, stem);
        if (file != null) _local[stem.id] = file.path;
      }
      if (mounted) setState(() => _result = result);
    } on Object {
      if (mounted) setState(() => _error = '无法读取本机分轨清单或存储目录');
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _download(LegacyStemFile stem) async {
    if (_downloading != null) return;
    setState(() {
      _downloading = stem.id;
      _progress = 0;
    });
    try {
      final file = await _store.download(
        widget.task.id,
        stem,
        onProgress: (received, total) {
          if (mounted) setState(() => _progress = received / total);
        },
      );
      if (mounted) setState(() => _local[stem.id] = file.path);
    } on Object catch (e) {
      _message(
        e is AlgorithmApiError
            ? e.message
            : e is FormatException
            ? e.message
            : '下载未完成，请检查网络和本机空间后重试',
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _toggle(LegacyStemFile stem) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_active == stem.id && _playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        final file = await _store.localFile(widget.task.id, stem);
        if (file == null) {
          if (mounted) setState(() => _local.remove(stem.id));
          throw StateError('missing');
        }
        final resume = _active == stem.id && _position < _duration
            ? _position
            : Duration.zero;
        await _player.play(file.path, resume);
        if (!mounted) {
          await _player.stop();
          return;
        }
        setState(() {
          _active = stem.id;
          _playing = true;
          _position = resume;
          _duration = stem.duration;
        });
        _ticker ??= Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => unawaited(_poll()),
        );
      }
    } on Object {
      _message('无法试听此音轨，文件可能已失效或格式不受设备支持');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMix() async {
    if (_busy || _local.isEmpty || _result == null) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!mounted) return;
      setState(() {
        _playing = false;
        _active = null;
        _position = Duration.zero;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StemMixScreen(
            taskId: widget.task.id,
            title: widget.task.inputName,
            result: _result!,
          ),
        ),
      );
    } on Object {
      _message('无法打开分轨练习，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    if (_polling || !_playing || !mounted) return;
    _polling = true;
    try {
      final data = await _player.snapshot();
      if (mounted) {
        setState(() {
          _playing = data['isPlaying'] == true;
          _position = Duration(
            milliseconds: algorithmInteger(data['positionMs']),
          );
          _duration = Duration(
            milliseconds: algorithmInteger(data['durationMs']),
          );
        });
      }
    } on Object {
      if (mounted) setState(() => _playing = false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _seek(double ms) async {
    try {
      final position = Duration(milliseconds: ms.round());
      await _player.seek(position);
      if (mounted) setState(() => _position = position);
    } on Object {
      _message('无法调整试听进度');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_player.stop().catchError((Object _) {}));
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_player.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final expired =
        result != null && !result.expiresAt.isAfter(DateTime.now().toUtc());
    return Scaffold(
      appBar: AppBar(title: const Text('分轨结果')),
      body: result == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.task.inputName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  expired
                      ? '服务器文件已到期；已下载的音轨仍可离线试听。'
                      : '服务器文件到期：${result.expiresAt.toLocal()}。需要保留的音轨请下载到本机。',
                ),
                const Text('下载音轨后可进入分轨练习，调节音量、独奏、倍速和 A-B 循环。'),
                FilledButton.icon(
                  onPressed: _busy || _local.isEmpty ? null : _openMix,
                  icon: const Icon(Icons.tune),
                  label: const Text('进入分轨练习'),
                ),
                for (final stem in result.stems)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stem.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${(stem.sizeBytes / 1048576).toStringAsFixed(2)} MiB · ${stem.sampleRate} Hz · ${stem.channels} 声道${stem.origin == 'derived' ? ' · 原音频减人声得到' : ''}',
                          ),
                          if (_local.containsKey(stem.id)) ...[
                            const Text('已下载 · 可离线试听'),
                            TextButton.icon(
                              onPressed: _busy ? null : () => _toggle(stem),
                              icon: Icon(
                                _active == stem.id && _playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              label: Text(
                                _active == stem.id && _playing ? '暂停' : '试听',
                              ),
                            ),
                            if (_active == stem.id) ...[
                              Slider(
                                value: _position.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0,
                                      _duration.inMilliseconds.toDouble(),
                                    ),
                                max: _duration.inMilliseconds.toDouble().clamp(
                                  1,
                                  double.infinity,
                                ),
                                onChanged: _busy ? null : _seek,
                              ),
                              Text(
                                '${_seconds(_position)} / ${_seconds(_duration)}',
                              ),
                            ],
                          ] else
                            TextButton.icon(
                              onPressed: expired || _downloading != null
                                  ? null
                                  : () => _download(stem),
                              icon: const Icon(Icons.download),
                              label: const Text('下载到本机'),
                            ),
                          if (_downloading == stem.id) ...[
                            LinearProgressIndicator(value: _progress),
                            Text(
                              '下载 ${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _seconds(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

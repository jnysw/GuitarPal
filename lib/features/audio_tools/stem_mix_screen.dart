import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/widgets/precise_playback_speed_control.dart';
import 'algorithm_providers.dart';
import 'data/algorithm_mix_platform.dart';
import 'data/algorithm_stem_store.dart';
import 'domain/legacy_algorithm_models.dart';
import 'domain/stem_mix_settings.dart';

class StemMixScreen extends ConsumerStatefulWidget {
  const StemMixScreen({
    required this.taskId,
    required this.title,
    required this.result,
    super.key,
  });
  final String taskId;
  final String title;
  final LegacySeparationResult result;
  @override
  ConsumerState<StemMixScreen> createState() => _StemMixScreenState();
}

class _StemMixScreenState extends ConsumerState<StemMixScreen>
    with WidgetsBindingObserver {
  late final AlgorithmMixPlatform _player;
  late final AlgorithmStemStore _store;
  late final StemMixPreferences _preferences;
  StemMixSettings _settings = StemMixSettings(), _applied = StemMixSettings();
  Set<String> _loadedIds = {};
  bool _busy = true,
      _loaded = false,
      _playing = false,
      _polling = false,
      _dragging = false;
  int _position = 0, _duration = 1, _loops = 0, _a = 0, _b = 1;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = ref.read(algorithmMixPlatformProvider);
    _store = ref.read(algorithmStemStoreProvider);
    _preferences = ref.read(stemMixPreferencesProvider);
    _duration = widget.result.duration.inMilliseconds;
    _b = _duration;
    unawaited(_initialize());
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(_poll()),
    );
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  String _errorText(Object e) => e is PlatformException
      ? e.message ?? '音频设备操作失败'
      : e is FormatException
      ? e.message
      : '无法操作本机混音，请重新载入音轨';

  Future<void> _initialize() async {
    try {
      _settings =
          await _preferences.load(widget.taskId, _duration) ??
          StemMixSettings();
    } on Object {
      _message('本机练习设置无法读取，已使用默认设置');
    }
    if (!mounted) return;
    _a = _settings.loop?.startMs ?? 0;
    _b = _settings.loop?.endMs ?? _duration;
    await _loadMode(_settings, initial: true);
  }

  Future<void> _loadMode(
    StemMixSettings settings, {
    bool initial = false,
  }) async {
    if (!mounted || (_busy && !initial)) return;
    setState(() {
      _busy = true;
      _error = null;
      _playing = false;
      _dragging = false;
    });
    try {
      await _player.pause();
      if (_loaded) {
        final previous = await _player.snapshot();
        if (previous['isLoaded'] == true) {
          _position = algorithmInteger(previous['positionMs']);
        }
      }
      final paths = <String, String>{};
      for (final stem in widget.result.stems.where(
        (s) => settings.includes(s.id) && s.extension == 'wav',
      )) {
        final file = await _store.localFile(widget.taskId, stem);
        if (file != null) paths[stem.id] = file.path;
      }
      if (paths.isEmpty) {
        throw const FormatException('此模式没有已下载的 WAV 音轨，请返回结果页下载，或切换模式');
      }
      if (!mounted) return;
      await _player.load(paths);
      final actualDuration = algorithmInteger(
        (await _player.snapshot())['durationMs'],
      );
      if ((actualDuration - widget.result.duration.inMilliseconds).abs() >
              100 ||
          actualDuration < 250) {
        throw const FormatException('音轨实际时长与结果清单不一致');
      }
      if (settings.loop != null && settings.loop!.endMs > actualDuration) {
        settings = settings.copyWith(clearLoop: true);
        _message('已保存的循环超出实际音轨，请重新设置 A-B');
      }
      _duration = actualDuration;
      _a = _a.clamp(0, _duration - 250);
      _b = _b.clamp(_a + 250, _duration);
      await _player.configure(settings, paths.keys);
      await _player.seek(_position.clamp(0, _duration));
      if (!mounted) {
        await _player.stop();
        return;
      }
      setState(() {
        _settings = settings;
        _applied = settings;
        _loadedIds = paths.keys.toSet();
        _loaded = true;
        _loops = 0;
      });
      await _poll(force: true);
    } on Object catch (e) {
      await _player.stop().catchError((Object _) {});
      if (mounted) {
        setState(() {
          _loaded = false;
          _loadedIds = {};
          _error = _errorText(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit(StemMixSettings settings) async {
    if (_busy || !_loaded) return;
    setState(() => _busy = true);
    try {
      await _player.configure(settings, _loadedIds);
      if (mounted) {
        setState(() {
          _settings = settings;
          _applied = settings;
        });
      }
      await _poll(force: true);
    } on Object catch (e) {
      if (mounted) setState(() => _settings = _applied);
      _message(_errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll({bool force = false}) async {
    if (_polling ||
        !mounted ||
        !_loaded ||
        (!force && (!_playing || _busy || _dragging))) {
      return;
    }
    _polling = true;
    try {
      final data = await _player.snapshot();
      if (data['error'] is String) {
        throw FormatException(data['error'] as String);
      }
      if (data['isLoaded'] != true) throw const FormatException('混音已释放，请重新载入');
      if (mounted) {
        setState(() {
          _playing = data['isPlaying'] == true;
          _position = algorithmInteger(data['positionMs']).clamp(0, _duration);
          _loops = algorithmInteger(data['completedLoops']);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loaded = false;
          _playing = false;
          _error = _errorText(e);
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _toggle() async {
    if (_busy || !_loaded) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      await _poll(force: true);
    } on Object catch (e) {
      _message(_errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seek(int ms) async {
    if (_busy || !_loaded) return;
    setState(() {
      _busy = true;
      _dragging = false;
    });
    try {
      await _player.seek(ms);
      await _poll(force: true);
    } on Object catch (e) {
      _message(_errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setLoop(int a, int b, {bool enable = true}) async {
    final loop = StemMixLoop(a, b);
    try {
      loop.validate(_duration);
    } on FormatException catch (e) {
      _message(e.message);
      return;
    }
    setState(() {
      _a = a;
      _b = b;
    });
    if (enable) await _commit(_settings.copyWith(loop: loop));
  }

  Future<void> _editLoop() async {
    final value = await showDialog<StemMixLoop>(
      context: context,
      builder: (_) => _LoopEditor(start: _a, end: _b, duration: _duration),
    );
    if (value != null && mounted) await _setLoop(value.startMs, value.endMs);
  }

  Future<void> _save() async {
    if (_busy || !_loaded) return;
    setState(() => _busy = true);
    try {
      await _preferences.save(widget.taskId, _applied);
      _message('已保存本机练习设置，下次打开自动恢复');
    } on Object {
      _message('保存失败，请检查本机空间后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_player.pause().catchError((Object _) {}));
      if (mounted) setState(() => _playing = false);
      _dragging = false;
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
    final enabled = _loaded && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('分轨练习')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const Text('使用已下载的 PCM16 WAV 音轨；本页练习暂不计入计划统计。'),
          const SizedBox(height: 12),
          SegmentedButton<StemMixMode>(
            segments: const [
              ButtonSegment(
                value: StemMixMode.instruments,
                label: Text('分轨混音'),
              ),
              ButtonSegment(
                value: StemMixMode.vocalsAndBacking,
                label: Text('人声＋伴奏'),
              ),
            ],
            selected: {_settings.mode},
            onSelectionChanged: _busy
                ? null
                : (v) => _loadMode(_settings.copyWith(mode: v.single)),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _busy ? null : () => _loadMode(_settings),
              child: const Text('重新载入'),
            ),
          ],
          const SizedBox(height: 12),
          if (_loaded) Text('已载入 ${_loadedIds.length} 条音轨，控制会作用于同一播放进度。'),
          FilledButton.icon(
            key: const Key('mix_play'),
            onPressed: enabled ? _toggle : null,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            label: Text(_playing ? '暂停混音' : '播放混音'),
          ),
          Slider(
            key: const Key('mix_progress'),
            value: _position.toDouble().clamp(0, _duration.toDouble()),
            max: _duration.toDouble(),
            onChangeStart: enabled
                ? (_) => setState(() => _dragging = true)
                : null,
            onChanged: enabled
                ? (v) => setState(() => _position = v.round())
                : null,
            onChangeEnd: enabled ? (v) => _seek(v.round()) : null,
          ),
          Text('${_time(_position)} / ${_time(_duration)}'),
          PrecisePlaybackSpeedControl(
            value: _settings.speed,
            enabled: enabled,
            presets: const [.5, 1, 1.5, 2],
            onChanged: (speed) =>
                setState(() => _settings = _settings.copyWith(speed: speed)),
            onChangeEnd: (speed) => _commit(_settings.copyWith(speed: speed)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('A-B 循环'),
            subtitle: Text('A ${_time(_a)} · B ${_time(_b)} · 已循环 $_loops 次'),
            value: _settings.loop != null,
            onChanged: enabled
                ? (v) => v
                      ? _setLoop(_a, _b)
                      : _commit(_settings.copyWith(clearLoop: true))
                : null,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: enabled ? () => _setLoop(_position, _b) : null,
                child: const Text('当前位置设 A'),
              ),
              OutlinedButton(
                onPressed: enabled ? () => _setLoop(_a, _position) : null,
                child: const Text('当前位置设 B'),
              ),
              TextButton(
                onPressed: enabled ? _editLoop : null,
                child: const Text('输入时间'),
              ),
            ],
          ),
          const Divider(),
          Text('主音量 ${(_settings.master * 100).round()}%'),
          Slider(
            value: _settings.master,
            onChanged: enabled
                ? (v) =>
                      setState(() => _settings = _settings.copyWith(master: v))
                : null,
            onChangeEnd: enabled
                ? (v) => _commit(_settings.copyWith(master: v))
                : null,
          ),
          for (final stem in widget.result.stems.where(
            (s) => _settings.includes(s.id),
          ))
            _stemCard(stem, enabled),
          OutlinedButton.icon(
            onPressed: enabled ? _save : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存练习设置'),
          ),
        ],
      ),
    );
  }

  Widget _stemCard(LegacyStemFile stem, bool enabled) {
    final control = _settings.controls[stem.id]!;
    final loaded = _loadedIds.contains(stem.id);
    void change(StemMixControl value) => unawaited(
      _commit(
        _settings.copyWith(controls: {..._settings.controls, stem.id: value}),
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stem.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!loaded) const Text('未载入；请返回结果页下载默认 WAV 音轨'),
            Wrap(
              spacing: 12,
              children: [
                FilterChip(
                  key: ValueKey('mix_mute_${stem.id}'),
                  label: const Text('静音'),
                  selected: control.muted,
                  onSelected: enabled && loaded
                      ? (v) => change(control.copyWith(muted: v))
                      : null,
                ),
                FilterChip(
                  key: ValueKey('mix_solo_${stem.id}'),
                  label: const Text('独奏'),
                  selected: control.solo,
                  onSelected: enabled && loaded
                      ? (v) => change(
                          control.copyWith(
                            solo: v,
                            muted: v ? false : control.muted,
                          ),
                        )
                      : null,
                ),
                Text('音量 ${(control.volume * 100).round()}%'),
              ],
            ),
            Slider(
              key: ValueKey('mix_volume_${stem.id}'),
              value: control.volume,
              onChanged: enabled && loaded
                  ? (v) => setState(
                      () => _settings = _settings.copyWith(
                        controls: {
                          ..._settings.controls,
                          stem.id: control.copyWith(volume: v),
                        },
                      ),
                    )
                  : null,
              onChangeEnd: enabled && loaded
                  ? (v) => change(control.copyWith(volume: v))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoopEditor extends StatefulWidget {
  const _LoopEditor({
    required this.start,
    required this.end,
    required this.duration,
  });
  final int start, end, duration;
  @override
  State<_LoopEditor> createState() => _LoopEditorState();
}

class _LoopEditorState extends State<_LoopEditor> {
  late final _a = TextEditingController(
    text: (widget.start / 1000).toStringAsFixed(3),
  );
  late final _b = TextEditingController(
    text: (widget.end / 1000).toStringAsFixed(3),
  );
  final _form = GlobalKey<FormState>();
  String? _error;
  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    final loop = StemMixLoop(
      (double.parse(_a.text) * 1000).round(),
      (double.parse(_b.text) * 1000).round(),
    );
    try {
      loop.validate(widget.duration);
      Navigator.pop(context, loop);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('输入 A-B 时间（秒）'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in [(_a, 'A 起点'), (_b, 'B 终点')])
            TextFormField(
              controller: field.$1,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: field.$2),
              validator: (text) =>
                  text != null &&
                      RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text) &&
                      double.tryParse(text)?.isFinite == true
                  ? null
                  : '请输入非负秒数，最多三位小数',
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _apply, child: const Text('应用')),
    ],
  );
}

String _time(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';

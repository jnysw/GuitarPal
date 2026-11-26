import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_source/practice_source.dart';
import '../library/practice_source_providers.dart';
import '../audio_tools/algorithm_providers.dart';
import '../audio_tools/domain/stem_mix_settings.dart';
import '../audio_tools/domain/video_stem_choice.dart';
import '../player/widgets/video_stem_mixer.dart';
import '../player/widgets/precise_playback_speed_control.dart';
import '../segments/presentation/practice_segment_timecode.dart';
import 'application/performance_preview.dart';
import 'domain/backing_preset.dart';
import 'performance_providers.dart';
import 'performance_resolver_providers.dart';

class PerformancePrepareRouteScreen extends ConsumerWidget {
  const PerformancePrepareRouteScreen({super.key, required this.sourceId});
  final String sourceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(practiceSourceByIdProvider(sourceId));
    return source.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _Unavailable('无法读取歌曲，请返回后重试'),
      data: (source) {
        if (source == null) return const _Unavailable('歌曲已不存在');
        if (!kDebugMode || !Platform.isAndroid) {
          return const _Unavailable('演奏伴奏准备当前在 Android 测试版开放');
        }
        if (source.platform != SourcePlatform.local ||
            source.kind != SourceKind.video ||
            source.canonicalUri?.scheme != 'file') {
          return const _Unavailable('请从已导入的本地视频准备演奏伴奏');
        }
        return PerformancePrepareScreen(source: source);
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('演奏空间')),
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    ),
  );
}

class PerformancePrepareScreen extends ConsumerStatefulWidget {
  const PerformancePrepareScreen({super.key, required this.source});
  final PracticeSource source;
  @override
  ConsumerState<PerformancePrepareScreen> createState() =>
      _PerformancePrepareScreenState();
}

class _PerformancePrepareScreenState
    extends ConsumerState<PerformancePrepareScreen>
    with WidgetsBindingObserver {
  late final PerformancePreview _preview;
  List<PerformanceCandidate> _candidates = [];
  PerformanceCandidate? _candidate;
  BackingPreset? _preset;
  Map<String, StemCacheStatus> _cache = {};
  bool _loading = true,
      _changing = false,
      _saving = false,
      _guitar = false,
      _vocals = false;
  int _inspection = 0;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preview = PerformancePreview(
      ref.read(algorithmMixPlatformProvider),
      ref.read(algorithmStemStoreProvider),
      verify: _verify,
    );
    unawaited(_load());
  }

  Future<void> _verify(PerformanceCandidate candidate) async {
    final source = await ref
        .read(practiceSourceRepositoryProvider)
        .getById(widget.source.id);
    final task = await ref
        .read(algorithmTaskRepositoryProvider)
        .get(candidate.task.id);
    if (source == null ||
        task == null ||
        task.resultJson != candidate.task.resultJson ||
        source.canonicalUri?.scheme != 'file') {
      throw const FormatException('歌曲或分轨记录已变化，请返回重新选择');
    }
    final latest = PerformanceCandidate.fromTask(
      source,
      await File(source.canonicalUri!.toFilePath()).stat(),
      task,
    );
    if (latest == null ||
        latest.manifestHash != candidate.manifestHash ||
        latest.binding.inputSha256 != candidate.binding.inputSha256) {
      throw const FormatException('视频文件或分轨区间已变化，请重新选择有效结果');
    }
  }

  String _text(Object e) =>
      e is FormatException ? e.message : '操作失败，请重试；已下载文件保留';
  Future<void> _load() async {
    try {
      final tasks = await ref
          .read(algorithmTaskRepositoryProvider)
          .watchAll()
          .first;
      final stat = await File(widget.source.canonicalUri!.toFilePath()).stat();
      final values = [
        for (final task in tasks)
          ?PerformanceCandidate.fromTask(widget.source, stat, task),
      ];
      BackingPreset? saved;
      try {
        saved = await ref
            .read(backingPresetStoreProvider)
            .load(widget.source.id);
      } on Object {
        _notice = '上次伴奏方案读取失败，可重新设置并保存';
      }
      if (!mounted) return;
      _candidates = values;
      _candidate =
          values.where((c) => saved?.matches(c) == true).firstOrNull ??
          values.firstOrNull;
      if (_candidate != null) {
        if (saved != null && saved.matches(_candidate!)) {
          try {
            saved.validateAgainst(_candidate!);
            _preset = saved;
          } on Object {
            _notice = '上次选轨已不可用，请重新选择';
          }
        }
        _preset ??= _default(_candidate!);
        _flags();
      }
    } on Object catch (e) {
      _error = _text(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _inspect();
  }

  BackingPreset _default(PerformanceCandidate c) {
    final hasGuitar = c.result.stems.any(
      (s) => s.origin == 'model' && s.id == 'guitar',
    );
    Set<String> ids;
    try {
      ids = performanceBackingTracks(c.result, omitGuitar: hasGuitar);
    } on FormatException {
      ids = c.result.mixStems.isEmpty
          ? {c.result.stems.first.id}
          : c.result.mixStems.map((s) => s.id).toSet();
    }
    return BackingPreset.forCandidate(c, ids);
  }

  void _flags() {
    final model = _candidate!.result.stems
        .where((s) => s.origin == 'model')
        .map((s) => s.id)
        .toSet();
    final modelOnly = _preset!.controls.keys.every(model.contains);
    _guitar =
        modelOnly &&
        model.contains('guitar') &&
        !_preset!.controls.containsKey('guitar');
    _vocals =
        modelOnly &&
        model.contains('vocals') &&
        !_preset!.controls.containsKey('vocals');
  }

  Future<void> _inspect() async {
    final c = _candidate;
    if (c == null) return;
    final token = ++_inspection;
    try {
      final states = await ref
          .read(algorithmStemStoreProvider)
          .inspect(c.task.id, c.result.stems);
      if (mounted && token == _inspection) setState(() => _cache = states);
    } on Object {
      if (mounted && token == _inspection) {
        setState(() => _notice = '下载状态暂时无法读取，准备时会再次校验');
      }
    }
  }

  Future<void> _select(PerformanceCandidate c, {BackingPreset? preset}) async {
    if (_changing || _saving || _preview.busy) return;
    setState(() => _changing = true);
    ++_inspection;
    await _preview.invalidate();
    if (!mounted) return;
    setState(() {
      _candidate = c;
      _preset = preset ?? _default(c);
      _cache = {};
      _notice = null;
      _error = null;
      _flags();
      _changing = false;
    });
    await _inspect();
  }

  Future<void> _togglePreset({bool? guitar, bool? vocals}) async {
    try {
      final ids = performanceBackingTracks(
        _candidate!.result,
        omitGuitar: guitar ?? _guitar,
        omitVocals: vocals ?? _vocals,
      );
      final controls = {
        for (final id in ids)
          id: _preset!.controls[id] ?? const StemMixControl(),
      };
      await _select(_candidate!, preset: _preset!.copyWith(controls: controls));
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text(e))));
      }
    }
  }

  Future<void> _toggleTrack(String id) async {
    try {
      final ids = toggleVideoStem(
        _candidate!.result,
        _preset!.controls.keys.toSet(),
        id,
      );
      if (ids.isEmpty) throw const FormatException('至少保留一条伴奏音轨');
      await _select(
        _candidate!,
        preset: _preset!.copyWith(
          controls: {
            for (final id in ids)
              id: _preset!.controls[id] ?? const StemMixControl(),
          },
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text(e))));
      }
    }
  }

  void _configure(BackingPreset value) {
    setState(() => _preset = value);
    unawaited(_preview.configure(value));
  }

  Future<void> _save() async {
    if (_saving || !_preview.ready) return;
    setState(() => _saving = true);
    try {
      await _preview.flush();
      await _verify(_candidate!);
      final preset = _preview.applied;
      if (!_preview.ready || preset == null) {
        throw const FormatException('请先重新准备有效伴奏');
      }
      await ref.read(backingPresetStoreProvider).save(preset);
      if (mounted) setState(() => _notice = '伴奏方案已保存，下次可继续使用');
    } on Object catch (e) {
      if (mounted) setState(() => _notice = '保存失败：${_text(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openStage() async {
    if (_saving || !_preview.ready) return;
    setState(() => _saving = true);
    try {
      await _preview.flush();
      await _verify(_candidate!);
      final preset = _preview.applied;
      if (!_preview.ready || preset == null) {
        throw const FormatException('请先准备有效伴奏');
      }
      await ref.read(backingPresetStoreProvider).save(preset);
      await _preview.invalidate();
      if (!mounted) return;
      ref.invalidate(performanceBackingProvider(widget.source.id));
      await context.push(
        Uri(
          path: '/performance/stage',
          queryParameters: {'sourceId': widget.source.id},
        ).toString(),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _notice = _text(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reload() async {
    if (_preview.busy || _saving || _changing || _loading) return;
    await _preview.invalidate();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _candidate = null;
      _preset = null;
      _cache = {};
      _error = null;
    });
    await _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _preview.resume();
    } else {
      unawaited(_preview.suspend());
    }
  }

  @override
  void dispose() {
    ++_inspection;
    WidgetsBinding.instance.removeObserver(this);
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('演奏空间 · 准备伴奏'),
      actions: [
        IconButton(
          tooltip: '刷新已有结果',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _preview,
        builder: (context, _) {
          if (_loading) return const Center(child: CircularProgressIndicator());
          final c = _candidate, p = _preset;
          final locked = _changing || _saving || _preview.busy;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.source.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('把你练过的歌，准备成自己的伴奏。'),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (c == null || p == null) ...[
                const SizedBox(height: 24),
                const Icon(Icons.library_music_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('还没有可用的分轨结果。请回到练习页，在「音频」中先完成整曲或片段分轨。'),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    unawaited(_load());
                  },
                  child: const Text('重新读取已有结果'),
                ),
              ] else ...[
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: const Key('performance_candidate'),
                  initialValue: c.task.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '伴奏区间'),
                  items: [
                    for (final item in _candidates)
                      DropdownMenuItem(
                        value: item.task.id,
                        child: Text(
                          '${_range(item)} · ${_date(item.task.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: locked
                      ? null
                      : (id) {
                          if (id != null) {
                            unawaited(
                              _select(
                                _candidates.firstWhere((c) => c.task.id == id),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 16),
                const Text(
                  '由我来演奏',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      key: const Key('performance_omit_guitar'),
                      label: const Text('吉他由我演奏'),
                      selected: _guitar,
                      onSelected:
                          !locked &&
                              c.result.stems.any(
                                (s) => s.id == 'guitar' && s.origin == 'model',
                              )
                          ? (v) => unawaited(_togglePreset(guitar: v))
                          : null,
                    ),
                    FilterChip(
                      key: const Key('performance_omit_vocals'),
                      label: const Text('关闭人声'),
                      selected: _vocals,
                      onSelected:
                          !locked &&
                              c.result.stems.any(
                                (s) => s.id == 'vocals' && s.origin == 'model',
                              )
                          ? (v) => unawaited(_togglePreset(vocals: v))
                          : null,
                    ),
                  ],
                ),
                if (!c.result.stems.any(
                  (s) => s.id == 'guitar' && s.origin == 'model',
                ))
                  const Text('此结果没有独立吉他轨，可自定义现有音轨。'),
                const Text('下方勾选要保留的伴奏音轨；未勾选的文件会保留。分离可能有残留串音。'),
                ExpansionTile(
                  key: const Key('performance_tracks'),
                  title: Text('自定义音轨 · 已选 ${p.controls.length} 轨'),
                  subtitle: const Text('展开查看下载状态和调整选轨'),
                  children: [
                    for (final stem in c.result.stems)
                      CheckboxListTile(
                        key: Key('performance_track_${stem.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(stem.displayName),
                        subtitle: Text(
                          _cache[stem.id]?.complete == true
                              ? '已下载'
                              : (_cache[stem.id]?.receivedBytes ?? 0) > 0
                              ? '可续传'
                              : '未下载',
                        ),
                        value: p.controls.containsKey(stem.id),
                        onChanged: locked
                            ? null
                            : (_) => unawaited(_toggleTrack(stem.id)),
                      ),
                  ],
                ),
                FilledButton.icon(
                  key: const Key('performance_prepare'),
                  onPressed: locked
                      ? null
                      : () async {
                          await _preview.prepare(c, p);
                          await _inspect();
                        },
                  icon: const Icon(Icons.headphones),
                  label: Text(_preview.ready ? '重新准备伴奏' : '准备所选伴奏'),
                ),
                if (_preview.busy) ...[
                  const SizedBox(height: 8),
                  Text(_preview.stage),
                  LinearProgressIndicator(value: _preview.progress?.fraction),
                  if (_preview.progress case final progress?)
                    Text(
                      '${_bytes(progress.receivedBytes)} / ${_bytes(progress.totalBytes)} · ${progress.completedFiles}/${progress.totalFiles} 轨',
                    ),
                  if (_preview.progress != null)
                    TextButton(
                      onPressed: _preview.pauseDownload,
                      child: const Text('暂停下载，保留进度'),
                    ),
                ],
                if (_preview.error != null)
                  Text(
                    _preview.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_preview.ready) ...[
                  const Divider(height: 28),
                  Text(
                    '试听伴奏 · ${_range(c)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    key: const Key('performance_position'),
                    value: _preview.positionMs.toDouble().clamp(
                      0,
                      _preview.durationMs.toDouble(),
                    ),
                    min: 0,
                    max: _preview.durationMs.toDouble(),
                    onChanged: locked
                        ? null
                        : (v) => unawaited(_preview.seek(v.round())),
                  ),
                  Text(
                    '${formatPracticeTimecode(Duration(milliseconds: c.binding.startMs + _preview.positionMs))} / ${formatPracticeTimecode(Duration(milliseconds: c.binding.endMs))}',
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('performance_preview_play'),
                    onPressed: locked
                        ? null
                        : () => unawaited(_preview.toggle()),
                    icon: Icon(
                      _preview.playing ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(_preview.playing ? '暂停试听' : '播放试听'),
                  ),
                  const SizedBox(height: 12),
                  const Text('试听不计入练习时长。确认伴奏后，可保存方案供下次使用。'),
                  ExpansionTile(
                    title: const Text('调整伴奏与倍速'),
                    children: [
                      PrecisePlaybackSpeedControl(
                        value: p.speed,
                        enabled: !locked,
                        onChanged: (_) {},
                        onChangeEnd: (v) => _configure(p.copyWith(speed: v)),
                      ),
                      VideoStemMixer(
                        controls: p.controls,
                        master: p.master,
                        enabled: !locked,
                        onMaster: (v) => _configure(p.copyWith(master: v)),
                        onChange: (id, control) => _configure(
                          p.copyWith(controls: {...p.controls, id: control}),
                        ),
                        onReset: () => _configure(
                          p.copyWith(
                            controls: {
                              for (final id in p.controls.keys)
                                id: const StemMixControl(),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    key: const Key('performance_enter_stage'),
                    onPressed: locked ? null : _openStage,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('进入演奏舞台'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('performance_save'),
                    onPressed: locked ? null : _save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(_saving ? '正在保存…' : '保存伴奏方案'),
                  ),
                ],
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!),
              ],
            ],
          );
        },
      ),
    ),
  );
}

String _range(PerformanceCandidate c) => c.wholeSong
    ? '整曲'
    : '片段 ${formatPracticeTimecode(Duration(milliseconds: c.binding.startMs))}–${formatPracticeTimecode(Duration(milliseconds: c.binding.endMs))}';
String _date(DateTime d) =>
    '${d.toLocal().month}/${d.toLocal().day} ${d.toLocal().hour.toString().padLeft(2, '0')}:${d.toLocal().minute.toString().padLeft(2, '0')}';
String _bytes(int n) => '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';

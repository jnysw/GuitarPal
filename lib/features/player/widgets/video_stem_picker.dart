import 'package:flutter/material.dart';

import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../audio_tools/data/stem_export.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_stem_choice.dart';

Future<void> showVideoStemExport({
  required BuildContext context,
  required String taskId,
  required LegacySeparationResult result,
  required AlgorithmStemStore store,
  required String title,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    isDismissible: false,
    builder: (_) => VideoStemPicker(
      taskId: taskId,
      result: result,
      store: store,
      initialIds: const [],
      exportTitle: title,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('所选音轨已保存')));
  }
}

/// Select and inspect downloads without changing playback or starting HTTP work.
class VideoStemPicker extends StatefulWidget {
  const VideoStemPicker({
    super.key,
    required this.taskId,
    required this.result,
    required this.store,
    required this.initialIds,
    this.exportTitle,
  });
  final String taskId;
  final LegacySeparationResult result;
  final AlgorithmStemStore store;
  final Iterable<String> initialIds;
  final String? exportTitle;
  @override
  State<VideoStemPicker> createState() => _VideoStemPickerState();
}

class _VideoStemPickerState extends State<VideoStemPicker> {
  late Set<String> _selected;
  late Future<Map<String, StemCacheStatus>> _inspection;
  StemDownloadCancellation? _exportCancellation;
  StemDownloadProgress? _exportProgress;
  String? _exportStage;
  String? _exportNotice;
  bool get _exporting => _exportCancellation != null;
  bool get _isExport => widget.exportTitle != null;
  @override
  void initState() {
    super.initState();
    if (_isExport) {
      _selected = {};
    } else {
      try {
        _selected = videoStemSubset(
          widget.result,
          widget.initialIds,
        ).map((s) => s.id).toSet();
      } on FormatException {
        _selected = widget.result.mixStems.map((s) => s.id).toSet();
      }
    }
    _inspection = widget.store.inspect(widget.taskId, widget.result.stems);
  }

  Future<void> _export(Set<String> selected) async {
    if (_exporting) return;
    final cancellation = StemDownloadCancellation();
    setState(() {
      _exportCancellation = cancellation;
      _exportNotice = null;
    });
    try {
      final saved = await const StemExport().save(
        store: widget.store,
        taskId: widget.taskId,
        result: widget.result,
        trackIds: selected,
        title: widget.exportTitle!,
        cancellation: cancellation,
        onDownload: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
        onPreparing: () {
          if (!mounted) return;
          setState(
            () =>
                _exportStage = selected.length == 1 ? '正在准备音频文件…' : '正在打包 ZIP…',
          );
        },
        onSaving: () {
          if (mounted) setState(() => _exportStage = '请在系统窗口选择保存位置');
        },
      );
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, true);
      } else {
        setState(() => _exportNotice = '已取消保存，所选音轨已保留');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _exportNotice = switch (error) {
            StemDownloadPaused() =>
              _exportProgress == null ? '已取消准备，可重新导出' : '已暂停下载，可继续导出',
            AlgorithmApiError() => error.message,
            FormatException() => error.message,
            _ => '无法导出，请检查本机存储空间后重试',
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportCancellation = null;
          _exportProgress = null;
          _exportStage = null;
          _inspection = widget.store.inspect(
            widget.taskId,
            widget.result.stems,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _exportCancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: !_exporting, child: _picker(context));

  Widget _picker(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isExport ? '导出音轨' : '选择练习音轨',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: _exporting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, StemCacheStatus>>(
            future: _inspection,
            builder: (context, snapshot) {
              final states = snapshot.data;
              final expired = !DateTime.now().toUtc().isBefore(
                widget.result.expiresAt,
              );
              final available = widget.result.stems
                  .where(
                    (stem) => !expired || states?[stem.id]?.complete == true,
                  )
                  .toList();
              final availableIds = available.map((stem) => stem.id).toSet();
              final selected = _selected.intersection(availableIds);
              final cachedIds = availableIds
                  .where((id) => states?[id]?.complete == true)
                  .toSet();
              final cached = selected.intersection(cachedIds);
              final remaining = states == null || expired
                  ? null
                  : available
                        .where((stem) => selected.contains(stem.id))
                        .fold(
                          0,
                          (sum, stem) =>
                              sum +
                              stem.sizeBytes -
                              (states[stem.id]?.receivedBytes ?? 0),
                        );
              final allLocal =
                  selected.isNotEmpty && cached.length == selected.length;
              final models = available
                  .where((s) => s.origin == 'model')
                  .map((s) => s.id)
                  .toSet();
              final backing =
                  available.any(
                    (s) => s.id == 'vocals' && s.origin == 'model',
                  ) &&
                  available.any(
                    (s) => s.id == 'instrumental' && s.origin == 'derived',
                  );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Text(
                          _isExport
                              ? '单轨保存为原音频文件，多轨分别打包进 ZIP。'
                              : expired
                              ? '选择已完整下载的音轨进行离线练习。'
                              : '只下载所选音轨，下载期间可继续练习。已下载的音轨可离线使用，未完成的下载可续传。',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (_isExport && available.isNotEmpty)
                              ActionChip(
                                label: Text(
                                  selected.length == available.length
                                      ? '取消全选'
                                      : '全选',
                                ),
                                onPressed: _exporting
                                    ? null
                                    : () => setState(() {
                                        _selected =
                                            selected.length == available.length
                                            ? {}
                                            : availableIds;
                                      }),
                              ),
                            if (_isExport &&
                                cachedIds.isNotEmpty &&
                                cachedIds.length < availableIds.length)
                              ActionChip(
                                label: const Text('只选已下载'),
                                onPressed: _exporting
                                    ? null
                                    : () =>
                                          setState(() => _selected = cachedIds),
                              ),
                            if (!_isExport && models.isNotEmpty)
                              ActionChip(
                                label: Text(expired ? '已下载的乐器音轨' : '全部分轨'),
                                onPressed: () =>
                                    setState(() => _selected = Set.of(models)),
                              ),
                            if (!_isExport && models.contains('guitar'))
                              ActionChip(
                                label: const Text('只听吉他'),
                                onPressed: () =>
                                    setState(() => _selected = {'guitar'}),
                              ),
                            if (!_isExport && backing)
                              ActionChip(
                                label: const Text('人声与伴奏'),
                                onPressed: () => setState(
                                  () => _selected = {'vocals', 'instrumental'},
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (snapshot.connectionState != ConnectionState.done)
                          const LinearProgressIndicator(),
                        if (snapshot.hasError) ...[
                          const Text('本机下载状态读取失败，请重试'),
                          TextButton(
                            onPressed: () => setState(
                              () => _inspection = widget.store.inspect(
                                widget.taskId,
                                widget.result.stems,
                              ),
                            ),
                            child: const Text('重试读取'),
                          ),
                        ],
                        if (expired)
                          Text(
                            states != null && available.isEmpty
                                ? '服务器音轨已到期，本机没有完整音轨。请返回并重新分轨。'
                                : '服务器音轨已到期，可以选择本机已下载的音轨。',
                          ),
                        for (final stem in widget.result.stems)
                          CheckboxListTile(
                            key: Key('video_pick_stem_${stem.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(stem.displayName),
                            subtitle: Text(
                              _status(stem, states?[stem.id], expired: expired),
                            ),
                            value: selected.contains(stem.id),
                            onChanged:
                                _exporting ||
                                    (expired &&
                                        states?[stem.id]?.complete != true)
                                ? null
                                : (_) => setState(() {
                                    if (_isExport) {
                                      if (!selected.remove(stem.id)) {
                                        selected.add(stem.id);
                                      }
                                      _selected = selected;
                                    } else {
                                      _selected = toggleVideoStem(
                                        widget.result,
                                        selected,
                                        stem.id,
                                      );
                                    }
                                  }),
                          ),
                        if (!_isExport)
                          const Text('合成音轨与乐器分轨分开播放，避免重复叠加；人声可搭配合成伴奏。'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_exporting)
                          Text(
                            [
                              '已选 ${selected.length} 轨',
                              if (_isExport && selected.isNotEmpty)
                                selected.length == 1 ? '原音频' : 'ZIP',
                              if (remaining != null && remaining > 0)
                                '待下载 ${_bytes(remaining)}',
                            ].join(' · '),
                          ),
                        if (_exportNotice != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(_exportNotice!),
                          ),
                        if (_isExport && !_exporting)
                          FilledButton(
                            key: const Key('video_export_selected_stems'),
                            onPressed: states == null || selected.isEmpty
                                ? null
                                : () => _export(selected),
                            child: Text(allLocal ? '保存所选音轨' : '下载并导出'),
                          )
                        else if (!_isExport)
                          FilledButton(
                            key: const Key('video_apply_stem_choice'),
                            onPressed: states == null || selected.isEmpty
                                ? null
                                : () => Navigator.pop(
                                    context,
                                    VideoStemLoadChoice(
                                      selected,
                                      localOnly: allLocal,
                                    ),
                                  ),
                            child: Text(allLocal ? '使用所选音轨' : '下载所选音轨'),
                          ),
                        if (_exporting) ...[
                          if (_exportStage case final stage?)
                            Semantics(liveRegion: true, child: Text(stage))
                          else if (_exportProgress case final progress?) ...[
                            Text(
                              '正在下载音轨 · ${progress.completedFiles}/${progress.totalFiles} 轨',
                            ),
                            Text(
                              '${_bytes(progress.receivedBytes)} / ${_bytes(progress.totalBytes)}',
                            ),
                          ] else
                            const Text('正在检查所选音轨…'),
                          LinearProgressIndicator(
                            value: _exportStage == null
                                ? _exportProgress?.fraction
                                : null,
                          ),
                          if (_exportStage == null)
                            TextButton(
                              onPressed: _exportCancellation!.isCancelled
                                  ? null
                                  : () => setState(_exportCancellation!.cancel),
                              child: Text(
                                _exportProgress == null ? '取消准备' : '暂停下载',
                              ),
                            ),
                        ],
                        if (!_isExport && cached.isNotEmpty && !allLocal)
                          TextButton(
                            key: const Key('video_use_cached_stems'),
                            onPressed: () => Navigator.pop(
                              context,
                              VideoStemLoadChoice(cached, localOnly: true),
                            ),
                            child: Text('仅使用已下载的 ${cached.length} 轨'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

String _status(
  LegacyStemFile stem,
  StemCacheStatus? state, {
  required bool expired,
}) {
  if (state == null) return '正在检查本机下载…';
  if (state.complete) return '已下载 · ${_bytes(stem.sizeBytes)}';
  if (expired) return '服务器音轨已到期';
  if (state.receivedBytes > 0) {
    return '可续传 · ${_bytes(state.receivedBytes)} / ${_bytes(stem.sizeBytes)}';
  }
  return '未下载 · ${_bytes(stem.sizeBytes)}';
}

String _bytes(int n) => n >= 1024 * 1024
    ? '${(n / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(n / 1024).toStringAsFixed(1)} KB';

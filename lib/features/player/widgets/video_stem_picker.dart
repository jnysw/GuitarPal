import 'package:flutter/material.dart';

import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_stem_choice.dart';

/// Select and inspect downloads without changing playback or starting HTTP work.
class VideoStemPicker extends StatefulWidget {
  const VideoStemPicker({
    super.key,
    required this.taskId,
    required this.result,
    required this.store,
    required this.initialIds,
  });
  final String taskId;
  final LegacySeparationResult result;
  final AlgorithmStemStore store;
  final Iterable<String> initialIds;
  @override
  State<VideoStemPicker> createState() => _VideoStemPickerState();
}

class _VideoStemPickerState extends State<VideoStemPicker> {
  late Set<String> _selected;
  late Future<Map<String, StemCacheStatus>> _inspection;
  @override
  void initState() {
    super.initState();
    try {
      _selected = videoStemSubset(
        widget.result,
        widget.initialIds,
      ).map((s) => s.id).toSet();
    } on FormatException {
      _selected = widget.result.mixStems.map((s) => s.id).toSet();
    }
    _inspection = widget.store.inspect(widget.taskId, widget.result.stems);
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
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
                  '选择练习音轨',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
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
              final selected = _selected.intersection(
                available.map((s) => s.id).toSet(),
              );
              final cached = selected
                  .where((id) => states?[id]?.complete == true)
                  .toSet();
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
                          expired
                              ? '选择已完整下载的音轨进行离线练习。'
                              : '只下载本次要练习的音轨。已下载的音轨可离线使用，未完成的下载可续传。',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (models.isNotEmpty)
                              ActionChip(
                                label: Text(expired ? '已下载的乐器音轨' : '全部分轨'),
                                onPressed: () =>
                                    setState(() => _selected = Set.of(models)),
                              ),
                            if (models.contains('guitar'))
                              ActionChip(
                                label: const Text('只听吉他'),
                                onPressed: () =>
                                    setState(() => _selected = {'guitar'}),
                              ),
                            if (backing)
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
                                expired && states?[stem.id]?.complete != true
                                ? null
                                : (_) => setState(
                                    () => _selected = toggleVideoStem(
                                      widget.result,
                                      selected,
                                      stem.id,
                                    ),
                                  ),
                          ),
                        const Text('合成音轨与乐器分轨分开播放，避免重复叠加；人声可搭配合成伴奏。'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '已选 ${selected.length} 轨${remaining == null ? '' : ' · 还需下载 ${_bytes(remaining)}'}',
                        ),
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
                          child: Text(allLocal ? '使用所选音轨' : '下载并使用所选音轨'),
                        ),
                        if (cached.isNotEmpty && !allLocal)
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

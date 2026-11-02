import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_recording/practice_recording.dart';
import '../recordings/practice_recording_providers.dart';
import 'domain/performance_take.dart';
import 'performance_take_providers.dart';
import 'performance_dialog.dart';

final performanceDraftsProvider = FutureProvider.autoDispose
    .family<List<PerformanceTake>, String>(
      (ref, sourceId) => ref.watch(performanceTakeStoreProvider).list(sourceId),
    );

class PerformanceTakesScreen extends ConsumerStatefulWidget {
  const PerformanceTakesScreen({super.key, required this.sourceId});
  final String sourceId;
  @override
  ConsumerState<PerformanceTakesScreen> createState() =>
      _PerformanceTakesState();
}

class _PerformanceTakesState extends ConsumerState<PerformanceTakesScreen> {
  String get sourceId => widget.sourceId;
  bool _selecting = false;
  final _selected = <String>{};

  Future<void> _compare(List<PracticeRecording> items) async {
    final chosen = items.where((r) => _selected.contains(r.id)).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (chosen.length != 2) return;
    await context.push(
      Uri(
        path: '/performance/compare',
        queryParameters: {
          'sourceId': sourceId,
          'firstId': chosen[0].id,
          'secondId': chosen[1].id,
        },
      ).toString(),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String id) async {
    await context.push(
      Uri(
        path: '/performance/review',
        queryParameters: {'takeId': id},
      ).toString(),
    );
    if (context.mounted) ref.invalidate(performanceDraftsProvider(sourceId));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String id, {
    PerformanceTake? draft,
    PracticeRecording? saved,
  }) async {
    final yes = await showPerformanceDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条演奏录音？'),
        content: const Text('将删除本地原始录音及其信息，不影响伴奏或其它演奏。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final service = ref.read(performanceTakeServiceProvider);
    final audio = ref.read(practiceAudioRecorderProvider);
    final repository = ref.read(practiceRecordingRepositoryProvider);
    try {
      if (draft != null) {
        await service.discard(draft);
      } else if (saved != null) {
        await audio.deleteRecording(saved.filePath);
        await repository.delete(id);
      }
      if (context.mounted) ref.invalidate(performanceDraftsProvider(sourceId));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除未完成，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(practiceRecordingsForSourceProvider(sourceId));
    final drafts = ref.watch(performanceDraftsProvider(sourceId));
    final items =
        saved.asData?.value
            .where((r) => r.kind == PracticeRecordingKind.performanceTake)
            .toList() ??
        [];
    final pending =
        drafts.asData?.value
            .where((t) => !items.any((r) => r.id == t.id))
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(title: const Text('演奏录音')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(performanceDraftsProvider(sourceId));
          ref.invalidate(practiceRecordingsForSourceProvider(sourceId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('同一首歌，不同时间的你', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            const Text('把以前与现在的演奏轮流听一遍，听见自己的变化。'),
            if (items.length >= 2 || _selecting) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('performance_compare_select'),
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selected.clear();
                }),
                icon: Icon(_selecting ? Icons.close : Icons.compare_arrows),
                label: Text(_selecting ? '取消选择' : '对比两次演奏'),
              ),
              if (_selecting)
                FilledButton(
                  key: const Key('performance_compare_open'),
                  onPressed:
                      items.where((r) => _selected.contains(r.id)).length == 2
                      ? () => _compare(items)
                      : null,
                  child: Text(
                    '开始对比（${items.where((r) => _selected.contains(r.id)).length}/2）',
                  ),
                ),
            ],
            if (saved.isLoading || drafts.isLoading)
              const LinearProgressIndicator(),
            if (saved.hasError || drafts.hasError)
              const Text('部分录音信息读取失败，请下拉重试。'),
            if (!saved.isLoading &&
                !drafts.isLoading &&
                items.isEmpty &&
                pending.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('还没有演奏录音，可从舞台开始试录或录一遍。'),
              ),
            for (final t in pending)
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(t.trial ? '麦克风试录草稿' : '未保存的演奏草稿'),
                subtitle: Text(
                  '${_date(t.createdAt)} · ${t.durationMs > 0 ? '待回听' : '待恢复'}',
                ),
                onTap: () => _open(context, ref, t.id),
                trailing: IconButton(
                  tooltip: '删除草稿',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref, t.id, draft: t),
                ),
              ),
            for (final r in items)
              if (_selecting)
                CheckboxListTile(
                  key: Key('performance_select_${r.id}'),
                  title: Text(r.title),
                  subtitle: Text(
                    '${_date(r.recordedAt)} · ${r.referenceSpeed.toStringAsFixed(2)}×',
                  ),
                  value: _selected.contains(r.id),
                  onChanged: (v) => setState(() {
                    if (v == true && _selected.length < 2) {
                      _selected.add(r.id);
                    } else {
                      _selected.remove(r.id);
                    }
                  }),
                )
              else
                ListTile(
                  leading: const Icon(Icons.mic),
                  title: Text(r.title),
                  subtitle: Text(
                    '${_date(r.recordedAt)} · ${r.duration.inSeconds} 秒 · ${r.referenceSpeed.toStringAsFixed(2)}×',
                  ),
                  onTap: () => _open(context, ref, r.id),
                  trailing: IconButton(
                    tooltip: '删除演奏录音',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, r.id, saved: r),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) {
  final d = date.toLocal();
  return '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

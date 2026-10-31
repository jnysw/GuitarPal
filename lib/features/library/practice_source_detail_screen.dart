import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/text_share_gateway.dart';
import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../recordings/presentation/practice_recording_list.dart';
import '../segments/practice_segment_providers.dart';
import '../segments/presentation/practice_segment_card.dart';
import '../segments/presentation/practice_segment_editor_sheet.dart';
import 'presentation/source_artwork.dart';
import 'practice_source_providers.dart';

class PracticeSourceDetailScreen extends ConsumerWidget {
  const PracticeSourceDetailScreen({required this.sourceId, super.key});

  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(practiceSourceByIdProvider(sourceId));
    return source.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _SourceUnavailableView(
        title: '无法读取练习内容',
        message: '请返回练习库后重试。',
      ),
      data: (source) {
        if (source == null) {
          return const _SourceUnavailableView(
            title: '练习内容不存在',
            message: '它可能已经从练习库中删除。',
          );
        }
        return _SourceDetailView(source: source);
      },
    );
  }
}

class _SourceDetailView extends ConsumerWidget {
  const _SourceDetailView({required this.source});

  final PracticeSource source;

  bool get _canPracticeInline =>
      (source.platform == SourcePlatform.bilibili &&
          source.externalId != null) ||
      (source.platform == SourcePlatform.local &&
          source.kind == SourceKind.video &&
          source.canonicalUri?.scheme == 'file');

  Future<void> _openOriginal(BuildContext context, WidgetRef ref) async {
    try {
      final opened = await ref.read(sourceLauncherProvider).open(source);
      if (!context.mounted) return;
      if (!opened) _showMessage(context, '暂时无法打开原内容');
    } on Object {
      if (context.mounted) _showMessage(context, '打开失败，请检查系统中的可用应用');
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final requestedTitle = await showDialog<String>(
      context: context,
      builder: (context) => _RenameSourceDialog(initialTitle: source.title),
    );
    if (requestedTitle == null || !context.mounted) return;

    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .rename(source, requestedTitle);
      ref.invalidate(practiceSourceByIdProvider(source.id));
      if (context.mounted) _showMessage(context, '已更新练习名称');
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, '重命名失败，请稍后重试');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除练习内容？'),
        content: Text(
          source.platform == SourcePlatform.local
              ? '「${source.title}」、其练习片段和 GuitarPal 保存的视频副本将从本机移除。'
              : '「${source.title}」及其练习片段将从本机移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('source_detail_confirm_delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(practiceLibraryServiceProvider).delete(source);
      if (context.mounted) context.go('/library');
    } on Object {
      if (context.mounted) _showMessage(context, '删除失败，请稍后重试');
    }
  }

  Future<void> _setCompleted(
    BuildContext context,
    WidgetRef ref,
    bool completed,
  ) async {
    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .setCompleted(source, completed);
      ref.invalidate(practiceSourceByIdProvider(source.id));
      ref.invalidate(practiceSourcesProvider);
      if (context.mounted) {
        _showMessage(context, completed ? '已标记为完成' : '已移回待练');
      }
    } on Object {
      if (context.mounted) _showMessage(context, '更新完成状态失败，请稍后重试');
    }
  }

  Future<void> _refreshMetadata(BuildContext context, WidgetRef ref) async {
    try {
      final changed = await ref
          .read(practiceLibraryServiceProvider)
          .refreshMetadata(source);
      ref.invalidate(practiceSourceByIdProvider(source.id));
      ref.invalidate(practiceSourcesProvider);
      if (context.mounted) {
        _showMessage(context, changed ? '已更新来源标题和封面' : '来源信息已是最新，或平台暂未提供公开封面');
      }
    } on Object {
      if (context.mounted) _showMessage(context, '刷新来源信息失败，请稍后重试');
    }
  }

  Future<void> _editSourceNote(BuildContext context, WidgetRef ref) async {
    final requestedNote = await showDialog<String>(
      context: context,
      builder: (context) => _SourceNoteDialog(initialNote: source.note),
    );
    if (requestedNote == null || !context.mounted) return;

    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .updateNote(source, requestedNote);
      ref.invalidate(practiceSourceByIdProvider(source.id));
      ref.invalidate(practiceSourcesProvider);
      if (context.mounted) {
        _showMessage(
          context,
          requestedNote.trim().isEmpty ? '已清空曲目笔记' : '已保存曲目笔记',
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, '保存曲目笔记失败，请稍后重试');
    }
  }

  Future<void> _exportNotes(
    BuildContext context,
    WidgetRef ref,
    List<PracticeSegment> segments,
  ) async {
    final service = ref.read(practiceNotesExportServiceProvider);
    if (!service.hasExportableNotes(source, segments)) {
      _showMessage(context, '请先添加曲目笔记或片段笔记');
      return;
    }

    final notedSegmentCount = segments
        .where((segment) => segment.note?.trim().isNotEmpty == true)
        .length;
    final action = await showModalBottomSheet<_NoteExportAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _NoteExportSheet(
        hasSourceNote: source.note?.trim().isNotEmpty == true,
        notedSegmentCount: notedSegmentCount,
      ),
    );
    if (action == null || !context.mounted) return;

    final export = service.build(source: source, segments: segments);
    switch (action) {
      case _NoteExportAction.share:
        final result = await ref
            .read(textShareGatewayProvider)
            .share(subject: export.subject, text: export.markdown);
        if (!context.mounted) return;
        if (result == TextShareResult.opened) {
          _showMessage(context, '已打开系统分享面板');
        } else {
          await Clipboard.setData(ClipboardData(text: export.markdown));
          if (context.mounted) {
            _showMessage(context, '系统分享不可用，已复制 Markdown');
          }
        }
      case _NoteExportAction.copy:
        await Clipboard.setData(ClipboardData(text: export.markdown));
        if (context.mounted) _showMessage(context, '练习笔记已复制为 Markdown');
    }
  }

  Future<void> _editSegment(
    BuildContext context,
    WidgetRef ref,
    PracticeSegment segment,
  ) async {
    final value = await showPracticeSegmentEditorSheet(
      context: context,
      mode: PracticeSegmentEditorMode.edit,
      initialValue: PracticeSegmentEditorResult(
        title: segment.title,
        start: segment.start,
        end: segment.end,
        note: segment.note,
        preferredSpeed: segment.preferredSpeed,
      ),
    );
    if (value == null || !context.mounted) return;

    try {
      await ref
          .read(practiceSegmentServiceProvider)
          .update(
            segment,
            title: value.title,
            start: value.start,
            end: value.end,
            note: value.note,
            preferredSpeed: value.preferredSpeed,
            sourceDuration: source.duration,
          );
      if (context.mounted) _showMessage(context, '已更新「${value.title}」');
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, '更新片段失败，请稍后重试');
    }
  }

  Future<void> _deleteSegment(
    BuildContext context,
    WidgetRef ref,
    PracticeSegment segment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除练习片段？'),
        content: Text('「${segment.title}」将从这个练习中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('source_detail_confirm_delete_segment'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(practiceSegmentServiceProvider).delete(segment);
      if (context.mounted) _showMessage(context, '已删除「${segment.title}」');
    } on Object {
      if (context.mounted) _showMessage(context, '删除片段失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final segments = ref.watch(practiceSegmentsProvider(source.id));
    final loadedSegments = segments.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习详情'),
        actions: [
          PopupMenuButton<_DetailAction>(
            tooltip: '更多操作',
            onSelected: (action) {
              switch (action) {
                case _DetailAction.toggleCompleted:
                  _setCompleted(context, ref, !source.isCompleted);
                case _DetailAction.refreshMetadata:
                  _refreshMetadata(context, ref);
                case _DetailAction.rename:
                  _rename(context, ref);
                case _DetailAction.delete:
                  _delete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('source_detail_toggle_completed'),
                value: _DetailAction.toggleCompleted,
                child: Text(source.isCompleted ? '移回待练' : '标记为完成'),
              ),
              if (source.platform != SourcePlatform.local)
                const PopupMenuItem(
                  key: Key('source_detail_refresh_metadata'),
                  value: _DetailAction.refreshMetadata,
                  child: Text('刷新标题和封面'),
                ),
              const PopupMenuItem(
                value: _DetailAction.rename,
                child: Text('重命名'),
              ),
              const PopupMenuItem(
                value: _DetailAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (source.thumbnailUri != null) ...[
                            AspectRatio(
                              key: const Key('source_detail_artwork'),
                              aspectRatio: 16 / 9,
                              child: SourceArtwork(
                                platform: source.platform,
                                thumbnailUri: source.thumbnailUri,
                                borderRadius: 16,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: colors.primaryContainer,
                                foregroundColor: colors.onPrimaryContainer,
                                child: Icon(_platformIcon(source.platform)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      source.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _platformLabel(source.platform),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: colors.primary),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      key: const Key(
                                        'source_detail_completion_status',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: source.isCompleted
                                            ? colors.primaryContainer
                                            : colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        source.isCompleted ? '已完成' : '待练',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: source.isCompleted
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (source.externalId case final id?) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '内容 ID：$id',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    if (source.duration case final duration?
                                        when duration > Duration.zero) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '时长：${_formatDuration(duration)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_canPracticeInline)
                            FilledButton.icon(
                              key: const Key('source_detail_start_practice'),
                              onPressed: () => context.push(
                                '/library/source/'
                                '${Uri.encodeComponent(source.id)}/practice',
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('开始练习'),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                '此来源当前为引用模式。可以保存在练习库并打开原内容，App 内播放将在对应平台适配后开放。',
                              ),
                            ),
                          if (kDebugMode &&
                              source.platform == SourcePlatform.local &&
                              source.kind == SourceKind.video) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const Key('source_detail_performance'),
                              onPressed: () => context.push(
                                Uri(
                                  path: '/performance/prepare',
                                  queryParameters: {'sourceId': source.id},
                                ).toString(),
                              ),
                              icon: const Icon(Icons.headphones),
                              label: const Text('去演奏 · 准备伴奏'),
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('source_detail_add_to_plan'),
                            onPressed: () => context.push(
                              '/plans/new?sourceId='
                              '${Uri.encodeQueryComponent(source.id)}',
                            ),
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: const Text('加入练习计划'),
                          ),
                          const SizedBox(height: 10),
                          if (source.platform != SourcePlatform.local)
                            OutlinedButton.icon(
                              onPressed: () => _openOriginal(context, ref),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('打开原内容'),
                            )
                          else
                            Text(
                              '视频副本保存在 GuitarPal 的私有目录，删除本练习时会一并清理。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SourceInformationCard(source: source),
                  const SizedBox(height: 16),
                  _SourceNoteCard(
                    source: source,
                    onEdit: () => _editSourceNote(context, ref),
                    onExport: loadedSegments == null
                        ? null
                        : () => _exportNotes(context, ref, loadedSegments),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '练习片段',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  segments.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('暂时无法读取练习片段'),
                    data: (items) => _SegmentList(
                      items: items,
                      canPracticeInline: _canPracticeInline,
                      onOpen: (segment) {
                        final segmentId = Uri.encodeQueryComponent(segment.id);
                        context.push(
                          '/library/source/'
                          '${Uri.encodeComponent(source.id)}/practice'
                          '?segmentId=$segmentId',
                        );
                      },
                      onEdit: (segment) => _editSegment(context, ref, segment),
                      onDelete: (segment) =>
                          _deleteSegment(context, ref, segment),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '练习录音',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  PracticeRecordingList(
                    sourceId: source.id,
                    segments: loadedSegments ?? const [],
                    canStartPractice: _canPracticeInline,
                    onStartPractice: _canPracticeInline
                        ? () => context.push(
                            '/library/source/'
                            '${Uri.encodeComponent(source.id)}/practice',
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameSourceDialog extends StatefulWidget {
  const _RenameSourceDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameSourceDialog> createState() => _RenameSourceDialogState();
}

class _RenameSourceDialogState extends State<_RenameSourceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名练习'),
      content: TextField(
        key: const Key('source_detail_rename_field'),
        controller: _controller,
        autofocus: true,
        maxLength: 300,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '练习名称',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _SourceNoteDialog extends StatefulWidget {
  const _SourceNoteDialog({this.initialNote});

  final String? initialNote;

  @override
  State<_SourceNoteDialog> createState() => _SourceNoteDialogState();
}

class _SourceNoteDialogState extends State<_SourceNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initialNote == null ? '添加曲目笔记' : '编辑曲目笔记'),
      content: SizedBox(
        width: 520,
        child: TextField(
          key: const Key('source_note_field'),
          controller: _controller,
          autofocus: true,
          minLines: 6,
          maxLines: 12,
          maxLength: 4000,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: '例如：本周先稳定右手节奏；副歌换把时保持手腕放松……',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        if (widget.initialNote != null)
          TextButton(
            key: const Key('source_note_clear'),
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清空'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('source_note_save'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _SegmentList extends StatelessWidget {
  const _SegmentList({
    required this.items,
    required this.canPracticeInline,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PracticeSegment> items;
  final bool canPracticeInline;
  final ValueChanged<PracticeSegment> onOpen;
  final ValueChanged<PracticeSegment> onEdit;
  final ValueChanged<PracticeSegment> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            canPracticeInline
                ? '还没有保存片段。开始练习后设置 A、B 点，即可将常练区间保存到这里。'
                : '此来源尚无练习片段。',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (segment) => PracticeSegmentCard(
              cardKey: ValueKey('source_detail_segment_${segment.id}'),
              segment: segment,
              onOpen: canPracticeInline ? () => onOpen(segment) : null,
              onAddToPlan: () {
                final sourceId = Uri.encodeQueryComponent(segment.sourceId);
                final segmentId = Uri.encodeQueryComponent(segment.id);
                context.push(
                  '/plans/new?sourceId=$sourceId&segmentId=$segmentId',
                );
              },
              onEdit: () => onEdit(segment),
              onDelete: () => onDelete(segment),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SourceUnavailableView extends StatelessWidget {
  const _SourceUnavailableView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('练习详情')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.find_in_page_outlined, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/library'),
                child: const Text('返回练习库'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceInformationCard extends StatelessWidget {
  const _SourceInformationCard({required this.source});

  final PracticeSource source;

  @override
  Widget build(BuildContext context) {
    final uri = source.canonicalUri;
    final externalUri = source.platform == SourcePlatform.local ? null : uri;
    return Card(
      key: const Key('source_detail_information'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '来源信息',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _InformationRow(
              label: '平台',
              value: _platformLabel(source.platform),
            ),
            if (externalUri != null)
              _InformationRow(label: '域名', value: externalUri.host),
            if (source.externalId case final externalId?)
              _InformationRow(label: '内容 ID', value: externalId),
            if (source.duration case final duration?
                when duration > Duration.zero)
              _InformationRow(label: '时长', value: _formatDuration(duration)),
            _InformationRow(
              label: '添加时间',
              value: _formatDateTime(source.createdAt),
            ),
            if (externalUri != null) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      externalUri.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('source_detail_copy_url'),
                    tooltip: '复制链接',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: externalUri.toString()),
                      );
                      if (context.mounted) _showMessage(context, '链接已复制');
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceNoteCard extends StatelessWidget {
  const _SourceNoteCard({
    required this.source,
    required this.onEdit,
    required this.onExport,
  });

  final PracticeSource source;
  final VoidCallback onEdit;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = source.note;
    return Card(
      key: const Key('source_detail_note'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '曲目笔记',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  key: const Key('source_note_export'),
                  tooltip: '导出笔记',
                  onPressed: onExport,
                  icon: const Icon(Icons.ios_share_rounded),
                ),
                TextButton.icon(
                  key: const Key('source_note_edit'),
                  onPressed: onEdit,
                  icon: Icon(
                    note == null ? Icons.add_rounded : Icons.edit_outlined,
                  ),
                  label: Text(note == null ? '添加' : '编辑'),
                ),
              ],
            ),
            if (note != null)
              SelectableText(
                note,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.55),
              )
            else
              Text(
                '记录整首曲目的练习目标、演奏要点或下一次需要继续处理的问题。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
              ),
            const SizedBox(height: 8),
            Text(
              '片段的局部笔记会显示在下方对应的 A-B 片段中。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteExportSheet extends StatelessWidget {
  const _NoteExportSheet({
    required this.hasSourceNote,
    required this.notedSegmentCount,
  });

  final bool hasSourceNote;
  final int notedSegmentCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final included = <String>[
      if (hasSourceNote) '曲目总体笔记',
      if (notedSegmentCount > 0) '$notedSegmentCount 个片段笔记',
    ].join('和');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '导出练习笔记',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '将 $included 整理为 Markdown，并保留片段区间和建议倍速。',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('source_note_export_share'),
              onPressed: () => Navigator.pop(context, _NoteExportAction.share),
              icon: const Icon(Icons.share_rounded),
              label: const Text('使用系统分享'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('source_note_export_copy'),
              onPressed: () => Navigator.pop(context, _NoteExportAction.copy),
              icon: const Icon(Icons.content_copy_rounded),
              label: const Text('复制 Markdown'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

enum _DetailAction { toggleCompleted, refreshMetadata, rename, delete }

enum _NoteExportAction { share, copy }

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地视频',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'Bilibili',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页链接',
  };
}

IconData _platformIcon(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => Icons.video_file_rounded,
    SourcePlatform.youtube => Icons.play_circle_fill_rounded,
    SourcePlatform.bilibili => Icons.smart_display_rounded,
    SourcePlatform.douyin => Icons.music_note_rounded,
    SourcePlatform.xiaohongshu => Icons.menu_book_rounded,
    SourcePlatform.genericWeb => Icons.public_rounded,
  };
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

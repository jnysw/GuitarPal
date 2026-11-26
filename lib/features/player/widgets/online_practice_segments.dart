import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import '../../../domain/practice_source/practice_source.dart';
import '../../segments/practice_segment_providers.dart';
import '../../segments/presentation/practice_segment_card.dart';
import '../../segments/presentation/practice_segment_editor_sheet.dart';

class OnlinePracticeSegments extends ConsumerWidget {
  const OnlinePracticeSegments({
    required this.source,
    this.initialValue,
    this.duration,
    this.onBeforeEdit,
    this.onActivate,
    super.key,
  });

  final PracticeSource source;
  final PracticeSegmentEditorResult? initialValue;
  final Duration? duration;
  final Future<void> Function()? onBeforeEdit;
  final Future<void> Function(PracticeSegment)? onActivate;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    PracticeSegment? segment,
  ]) async {
    await onBeforeEdit?.call();
    if (!context.mounted) return;
    final value = await showPracticeSegmentEditorSheet(
      context: context,
      mode: segment == null
          ? PracticeSegmentEditorMode.create
          : PracticeSegmentEditorMode.edit,
      initialValue: segment == null
          ? initialValue
          : PracticeSegmentEditorResult(
              title: segment.title,
              start: segment.start,
              end: segment.end,
              preferredSpeed: segment.preferredSpeed,
              note: segment.note,
            ),
    );
    if (value == null || !context.mounted) return;
    try {
      final service = ref.read(practiceSegmentServiceProvider);
      final sourceDuration = duration == Duration.zero
          ? null
          : duration ?? source.duration;
      final saved = segment == null
          ? await service.create(
              sourceId: source.id,
              title: value.title,
              start: value.start,
              end: value.end,
              note: value.note,
              preferredSpeed: value.preferredSpeed,
              sourceDuration: sourceDuration,
            )
          : await service.update(
              segment,
              title: value.title,
              start: value.start,
              end: value.end,
              note: value.note,
              preferredSpeed: value.preferredSpeed,
              sourceDuration: sourceDuration,
            );
      if (!context.mounted) return;
      _message(context, '片段已保存');
      if (segment == null) await onActivate?.call(saved);
    } on FormatException catch (error) {
      if (context.mounted) _message(context, error.message);
    } on Object {
      if (context.mounted) _message(context, '暂时无法保存片段');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PracticeSegment segment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除片段？'),
        content: Text('「${segment.title}」将从练习片段中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(practiceSegmentServiceProvider).delete(segment);
    } on Object {
      if (context.mounted) _message(context, '暂时无法删除片段');
    }
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(practiceSegmentsProvider(source.id));
    final title = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('练习片段', style: title)),
            TextButton.icon(
              key: const Key('online_create_segment'),
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(initialValue == null ? '新建片段' : '保存当前区间'),
            ),
          ],
        ),
        segments.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('暂时无法读取练习片段'),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty) const Text('还没有保存的片段'),
              for (final segment in items)
                PracticeSegmentCard(
                  segment: segment,
                  onOpen: onActivate == null
                      ? null
                      : () => onActivate!(segment),
                  onEdit: () => _edit(context, ref, segment),
                  onDelete: () => _delete(context, ref, segment),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

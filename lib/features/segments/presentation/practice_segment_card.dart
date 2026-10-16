import 'package:flutter/material.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import 'practice_segment_timecode.dart';

enum PracticeSegmentCardAction { addToPlan, edit, delete }

class PracticeSegmentCard extends StatelessWidget {
  const PracticeSegmentCard({
    required this.segment,
    this.onOpen,
    this.onAddToPlan,
    this.onEdit,
    this.onDelete,
    this.cardKey,
    super.key,
  });

  final PracticeSegment segment;
  final VoidCallback? onOpen;
  final VoidCallback? onAddToPlan;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.repeat_rounded),
        title: Text(segment.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${formatPracticeTimecode(segment.start)} – '
                  '${formatPracticeTimecode(segment.end)} · '
                  '${formatPracticeTimecode(segment.duration)}',
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_formatSpeed(segment.preferredSpeed)}x',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (segment.note case final note?) ...[
              const SizedBox(height: 5),
              Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpen != null) const Icon(Icons.chevron_right_rounded),
            if (onAddToPlan != null || onEdit != null || onDelete != null)
              PopupMenuButton<PracticeSegmentCardAction>(
                key: ValueKey('segment_actions_${segment.id}'),
                tooltip: '片段操作',
                onSelected: (action) {
                  switch (action) {
                    case PracticeSegmentCardAction.addToPlan:
                      onAddToPlan?.call();
                    case PracticeSegmentCardAction.edit:
                      onEdit?.call();
                    case PracticeSegmentCardAction.delete:
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onAddToPlan != null)
                    PopupMenuItem(
                      key: ValueKey('plan_segment_${segment.id}'),
                      value: PracticeSegmentCardAction.addToPlan,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.playlist_add_rounded),
                        title: Text('加入计划'),
                      ),
                    ),
                  if (onEdit != null)
                    PopupMenuItem(
                      key: ValueKey('edit_segment_${segment.id}'),
                      value: PracticeSegmentCardAction.edit,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑'),
                      ),
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      key: ValueKey('delete_segment_${segment.id}'),
                      value: PracticeSegmentCardAction.delete,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('删除'),
                      ),
                    ),
                ],
              ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      ),
    );
  }
}

String _formatSpeed(double speed) {
  return speed == speed.roundToDouble()
      ? speed.toStringAsFixed(0)
      : speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

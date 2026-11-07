import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_plan/practice_plan_progress.dart';
import '../../domain/practice_plan/practice_week_summary.dart';
import '../../domain/practice_source/practice_source.dart';
import '../library/practice_source_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'practice_plan_providers.dart';
import 'practice_week_summary_providers.dart';

class PlanOverviewScreen extends ConsumerWidget {
  const PlanOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(practicePlansProvider);
    final todayProgress = ref.watch(todayPlanProgressProvider);
    final weekSummary = ref.watch(thisWeekPracticeSummaryProvider);
    final today = ref.watch(currentCalendarDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习计划'),
        actions: [
          IconButton(
            key: const Key('plans_reminders_button'),
            tooltip: '管理练习提醒',
            onPressed: () => context.push('/plans/reminders'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            key: const Key('plans_create_button'),
            tooltip: '新建计划',
            onPressed: () => context.push('/plans/new'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('plans_create_fab'),
        onPressed: () => context.push('/plans/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建计划'),
      ),
      body: SafeArea(
        child: plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            onRetry: () {
              ref.invalidate(practicePlansProvider);
              ref.invalidate(todayPlanProgressProvider);
              ref.invalidate(thisWeekPracticeSummaryProvider);
            },
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyPlans();
            final orderedItems = List<PracticePlan>.of(items)
              ..sort((left, right) {
                final rank = _planSortRank(
                  left,
                  today,
                ).compareTo(_planSortRank(right, today));
                if (rank != 0) return rank;
                return right.updatedAt.compareTo(left.updatedAt);
              });
            final progressById = <String, PracticePlanProgress>{
              if (todayProgress case AsyncData(:final value))
                for (final progress in value) progress.plan.id: progress,
            };
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(practicePlansProvider);
                ref.invalidate(todayPlanProgressProvider);
                ref.invalidate(thisWeekPracticeSummaryProvider);
                await ref.read(practicePlansProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                children: [
                  _TodaySummary(progress: todayProgress),
                  const SizedBox(height: 12),
                  _WeekSummary(summary: weekSummary, today: today),
                  const SizedBox(height: 22),
                  Text(
                    '我的计划',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  for (final plan in orderedItems) ...[
                    _PlanCard(
                      plan: plan,
                      today: today,
                      progress: progressById[plan.id],
                      onStart: () => _startPractice(context, plan),
                      onOpenOriginal: (source) =>
                          _openOriginal(context, ref, source),
                      onRecord: plan.isScheduledOn(today)
                          ? () => _recordPractice(
                              context,
                              ref,
                              progressById[plan.id] ??
                                  PracticePlanProgress(
                                    plan: plan,
                                    sessions: const [],
                                  ),
                            )
                          : null,
                      onEdit: () => context.push(
                        '/plans/${Uri.encodeComponent(plan.id)}/edit',
                      ),
                      onReminder: () => context.push(
                        '/plans/${Uri.encodeComponent(plan.id)}/reminder',
                      ),
                      onOutcomes: () => context.push(
                        '/plans/${Uri.encodeComponent(plan.id)}/recordings',
                      ),
                      onDelete: () => _deletePlan(context, ref, plan),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _startPractice(BuildContext context, PracticePlan plan) {
    final sourceId = Uri.encodeComponent(plan.sourceId);
    final segment = plan.segmentId;
    final location = segment == null
        ? '/practice/$sourceId?planId=${Uri.encodeQueryComponent(plan.id)}'
        : '/practice/$sourceId?segmentId=${Uri.encodeQueryComponent(segment)}'
              '&planId=${Uri.encodeQueryComponent(plan.id)}';
    context.push(location);
  }

  Future<void> _openOriginal(
    BuildContext context,
    WidgetRef ref,
    PracticeSource source,
  ) async {
    try {
      final opened = await ref.read(sourceLauncherProvider).open(source);
      if (context.mounted && !opened) {
        _showMessage(context, '暂时无法打开原内容');
      }
    } on Object {
      if (context.mounted) _showMessage(context, '打开失败，请检查系统中的可用应用');
    }
  }

  Future<void> _recordPractice(
    BuildContext context,
    WidgetRef ref,
    PracticePlanProgress progress,
  ) async {
    final input = await showDialog<_PracticeRecordInput>(
      context: context,
      builder: (context) => _RecordPracticeDialog(progress: progress),
    );
    if (input == null || !context.mounted) return;

    try {
      await ref
          .read(practiceSessionServiceProvider)
          .record(
            plan: progress.plan,
            activeDuration: input.activeDuration,
            loopCount: input.loopCount,
          );
      if (context.mounted) {
        _showMessage(context, '已记录本次练习，今日进度已更新');
      }
    } on FormatException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } on Object {
      if (context.mounted) _showMessage(context, '记录失败，请稍后重试');
    }
  }

  Future<void> _deletePlan(
    BuildContext context,
    WidgetRef ref,
    PracticePlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除练习计划？'),
        content: Text('「${plan.name}」将从计划列表移除，已有练习记录仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('plan_confirm_delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(practicePlanServiceProvider).delete(plan);
      if (context.mounted) _showMessage(context, '已删除「${plan.name}」');
    } on Object {
      if (context.mounted) _showMessage(context, '删除失败，请稍后重试');
    }
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.summary, required this.today});

  final AsyncValue<PracticeWeekSummary> summary;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('practice_week_summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('本周进度暂时无法读取'),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_view_week_rounded, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本周进度',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${_shortDate(value.weekStart)}–${_shortDate(value.weekEnd)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    value.scheduledPlanCount == 0
                        ? '暂无计划'
                        : '${value.completedPlanCount}/${value.scheduledPlanCount} 项',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WeekdayStrip(summary: value, today: today),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: value.planCompletionFraction,
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _WeekMetric(
                      label: '练习时长',
                      value: _formatSummaryDuration(value.activeDuration),
                    ),
                  ),
                  Expanded(
                    child: _WeekMetric(
                      label: '练习记录',
                      value: '${value.sessionCount} 次',
                    ),
                  ),
                  Expanded(
                    child: _WeekMetric(
                      label: '完成循环',
                      value: '${value.loopCount} 次',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayStrip extends StatelessWidget {
  const _WeekdayStrip({required this.summary, required this.today});

  final PracticeWeekSummary summary;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < summary.days.length; index++)
          Expanded(
            child: Column(
              children: [
                Text(
                  labels[index],
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: summary.days[index].isComplete
                        ? colors.primary
                        : summary.days[index].hasScheduledPlans
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    border: summary.days[index].date == today
                        ? Border.all(color: colors.primary, width: 2)
                        : null,
                  ),
                  child: summary.days[index].isComplete
                      ? Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: colors.onPrimary,
                        )
                      : Text(
                          '${summary.days[index].date.day}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeekMetric extends StatelessWidget {
  const _WeekMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.progress});

  final AsyncValue<List<PracticePlanProgress>> progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: progress.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('今日进度暂时无法读取'),
          data: (items) {
            final completed = items.where((item) => item.isComplete).length;
            final fraction = items.isEmpty ? 0.0 : completed / items.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      completed == items.length && items.isNotEmpty
                          ? Icons.celebration_rounded
                          : Icons.today_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items.isEmpty
                            ? '今天没有安排'
                            : '今日完成 $completed / ${items.length}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: colors.primary,
                  backgroundColor: colors.surface.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 9),
                Text(
                  items.isEmpty
                      ? '计划会按照起止日期和每周重复日自动出现在今日任务中。'
                      : completed == items.length
                      ? '今天的计划已经完成，做得很好。'
                      : '每次练习可以分开记录，进度会自动累计。',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onPrimaryContainer, height: 1.4),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.plan,
    required this.today,
    required this.progress,
    required this.onStart,
    required this.onOpenOriginal,
    required this.onRecord,
    required this.onEdit,
    required this.onReminder,
    required this.onOutcomes,
    required this.onDelete,
  });

  final PracticePlan plan;
  final CalendarDate today;
  final PracticePlanProgress? progress;
  final VoidCallback onStart;
  final ValueChanged<PracticeSource> onOpenOriginal;
  final VoidCallback? onRecord;
  final VoidCallback onEdit;
  final VoidCallback onReminder;
  final VoidCallback onOutcomes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final source = ref.watch(practiceSourceByIdProvider(plan.sourceId));
    final segmentId = plan.segmentId;
    final segment = segmentId == null
        ? null
        : ref.watch(practiceSegmentByIdProvider(segmentId));
    final sourceValue = switch (source) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final sourceTitle = switch (source) {
      AsyncData(:final value) => value?.title ?? '练习内容已删除',
      _ => '练习内容',
    };
    final segmentTitle = switch (segment) {
      AsyncData(:final value) => value?.title,
      _ => null,
    };
    final status = _planStatus(plan, today, progress);
    final canPracticeInline =
        (sourceValue?.platform == SourcePlatform.bilibili &&
            sourceValue?.externalId != null) ||
        (sourceValue?.platform == SourcePlatform.local &&
            sourceValue?.kind == SourceKind.video &&
            sourceValue?.canonicalUri?.scheme == 'file');

    return Card(
      key: ValueKey('plan_card_${plan.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: status.complete
                        ? colors.primaryContainer
                        : colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    status.complete
                        ? Icons.check_rounded
                        : Icons.event_note_rounded,
                    color: status.complete
                        ? colors.onPrimaryContainer
                        : colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        segmentTitle == null
                            ? '$sourceTitle · 整曲'
                            : '$sourceTitle · $segmentTitle',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_PlanAction>(
                  key: ValueKey('plan_actions_${plan.id}'),
                  tooltip: '计划操作',
                  onSelected: (action) {
                    switch (action) {
                      case _PlanAction.edit:
                        onEdit();
                      case _PlanAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _PlanAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('编辑'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _PlanAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: [
                _InfoChip(icon: Icons.flag_outlined, label: _goalLabel(plan)),
                _InfoChip(
                  icon: Icons.date_range_outlined,
                  label:
                      '${_shortDate(plan.startDate)}–${_shortDate(plan.endDate)}',
                ),
                _InfoChip(
                  icon: Icons.repeat_rounded,
                  label: _weekdayLabel(plan.repeatWeekdays),
                ),
                _InfoChip(
                  key: ValueKey('plan_reminder_${plan.id}'),
                  icon: plan.reminderTime == null
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_outlined,
                  label: plan.reminderTime == null
                      ? '设置提醒'
                      : '${plan.reminderTime!.hhmm} 提醒',
                  onTap: onReminder,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (progress != null) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress!.fraction,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_progressLabel(progress!)),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            Wrap(
              spacing: 9,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('plan_outcomes_${plan.id}'),
                  onPressed: onOutcomes,
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('成果录音'),
                ),
                OutlinedButton.icon(
                  key: ValueKey('plan_start_${plan.id}'),
                  onPressed: sourceValue == null
                      ? null
                      : canPracticeInline
                      ? onStart
                      : () => onOpenOriginal(sourceValue),
                  icon: Icon(
                    canPracticeInline
                        ? Icons.play_arrow_rounded
                        : Icons.open_in_new_rounded,
                  ),
                  label: Text(canPracticeInline ? '开始练习' : '打开原内容'),
                ),
                if (onRecord != null)
                  FilledButton.tonalIcon(
                    key: ValueKey('plan_record_${plan.id}'),
                    onPressed: onRecord,
                    icon: const Icon(Icons.add_task_rounded),
                    label: Text(progress?.isComplete == true ? '继续补记' : '补记本次'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPracticeDialog extends StatefulWidget {
  const _RecordPracticeDialog({required this.progress});

  final PracticePlanProgress progress;

  @override
  State<_RecordPracticeDialog> createState() => _RecordPracticeDialogState();
}

class _RecordPracticeDialogState extends State<_RecordPracticeDialog> {
  late final TextEditingController _controller;
  String? _error;

  bool get _isLoops => widget.progress.plan.goal.type == PracticeGoalType.loops;

  @override
  void initState() {
    super.initState();
    final goal = widget.progress.plan.goal;
    final remaining = math.max(
      1,
      _isLoops
          ? goal.targetLoops! - widget.progress.completedLoops
          : ((goal.targetDuration!.inMilliseconds -
                        widget.progress.completedDuration.inMilliseconds) /
                    Duration.millisecondsPerMinute)
                .ceil(),
    );
    _controller = TextEditingController(text: '$remaining');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = _isLoops ? '请输入大于 0 的循环次数' : '请输入大于 0 的分钟数');
      return;
    }
    Navigator.pop(
      context,
      _PracticeRecordInput(
        activeDuration: _isLoops ? Duration.zero : Duration(minutes: value),
        loopCount: _isLoops ? value : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('补记本次练习'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isLoops
                ? '播放器会自动记录；如果遗漏，可填写实际循环次数并和今天已有记录累计。'
                : '播放器会自动记录；如果遗漏，可填写实际练习分钟并和今天已有记录累计。',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('plan_record_value_field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: _isLoops ? '循环次数' : '练习分钟',
              suffixText: _isLoops ? '次' : '分钟',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('plan_record_confirm'),
          onPressed: _submit,
          child: const Text('保存记录'),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null
              ? colors.surfaceContainerHighest
              : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 112),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  size: 42,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '还没有练习计划',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Text(
                '选择练习库中的整曲或片段，设置每天的循环次数或练习时长。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const Key('plans_empty_create'),
                onPressed: () => context.push('/plans/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('创建第一个计划'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/library'),
                child: const Text('先去练习库看看'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem_outlined, size: 48),
            const SizedBox(height: 14),
            const Text('暂时无法读取练习计划'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class _PracticeRecordInput {
  const _PracticeRecordInput({
    required this.activeDuration,
    required this.loopCount,
  });

  final Duration activeDuration;
  final int loopCount;
}

class _PlanStatus {
  const _PlanStatus(this.label, {this.complete = false});

  final String label;
  final bool complete;
}

enum _PlanAction { edit, delete }

_PlanStatus _planStatus(
  PracticePlan plan,
  CalendarDate today,
  PracticePlanProgress? progress,
) {
  if (today < plan.startDate) return const _PlanStatus('尚未开始');
  if (today > plan.endDate) return const _PlanStatus('已结束');
  if (!plan.isScheduledOn(today)) return const _PlanStatus('今天休息');
  if (progress?.isComplete == true) {
    return const _PlanStatus('今日已完成', complete: true);
  }
  return const _PlanStatus('今日待完成');
}

int _planSortRank(PracticePlan plan, CalendarDate today) {
  if (plan.isScheduledOn(today)) return 0;
  if (today >= plan.startDate && today <= plan.endDate) return 1;
  if (today < plan.startDate) return 2;
  return 3;
}

String _goalLabel(PracticePlan plan) {
  return switch (plan.goal.type) {
    PracticeGoalType.loops => '每天 ${plan.goal.targetLoops} 次循环',
    PracticeGoalType.duration => '每天 ${plan.goal.targetDuration!.inMinutes} 分钟',
  };
}

String _progressLabel(PracticePlanProgress progress) {
  return switch (progress.plan.goal.type) {
    PracticeGoalType.loops =>
      '${progress.completedLoops}/${progress.plan.goal.targetLoops} 次',
    PracticeGoalType.duration =>
      '${progress.completedDuration.inMinutes}/'
          '${progress.plan.goal.targetDuration!.inMinutes} 分钟',
  };
}

String _weekdayLabel(Set<int> weekdays) {
  if (weekdays.length == 7) return '每天';
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((day) => '周${labels[day - 1]}').join('、');
}

String _shortDate(CalendarDate date) => '${date.month}/${date.day}';

String _formatSummaryDuration(Duration duration) {
  if (duration < const Duration(minutes: 1)) return '${duration.inSeconds} 秒';
  if (duration < const Duration(hours: 1)) return '${duration.inMinutes} 分钟';
  final minutes = duration.inMinutes.remainder(60);
  return minutes == 0
      ? '${duration.inHours} 小时'
      : '${duration.inHours}时$minutes分';
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

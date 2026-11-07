import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/practice_reminder_gateway.dart';
import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_plan/reminder_time.dart';
import 'practice_plan_providers.dart';
import 'practice_reminder_providers.dart';

class PracticeReminderSettingsScreen extends ConsumerStatefulWidget {
  const PracticeReminderSettingsScreen({this.planId, super.key});

  final String? planId;

  @override
  ConsumerState<PracticeReminderSettingsScreen> createState() =>
      _PracticeReminderSettingsScreenState();
}

class _PracticeReminderSettingsScreenState
    extends ConsumerState<PracticeReminderSettingsScreen> {
  final Set<String> _busyPlanIds = {};

  Future<bool> _ensurePermission() async {
    final status = await ref
        .read(practiceReminderGatewayProvider)
        .requestPermission();
    if (!mounted) return false;
    switch (status) {
      case ReminderPermissionStatus.granted:
        return true;
      case ReminderPermissionStatus.denied:
        _showMessage('通知权限未开启，暂时无法启用练习提醒');
        return false;
      case ReminderPermissionStatus.unsupported:
        _showMessage('当前设备暂不支持练习提醒');
        return false;
    }
  }

  Future<void> _setReminder(
    PracticePlan plan,
    ReminderTime? reminderTime,
  ) async {
    if (_busyPlanIds.contains(plan.id)) return;
    setState(() => _busyPlanIds.add(plan.id));
    try {
      await ref
          .read(practicePlanServiceProvider)
          .updateReminder(plan, reminderTime);
      if (mounted) {
        _showMessage(
          reminderTime == null
              ? '已关闭「${plan.name}」的练习提醒'
              : '提醒已更新为 ${reminderTime.hhmm}',
        );
      }
    } on Object {
      if (mounted) _showMessage('提醒设置保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busyPlanIds.remove(plan.id));
    }
  }

  Future<void> _toggleReminder(PracticePlan plan, bool enabled) async {
    if (!enabled) {
      await _setReminder(plan, null);
      return;
    }
    if (!await _ensurePermission()) return;
    await _setReminder(
      plan,
      plan.reminderTime ?? ReminderTime(hour: 20, minute: 0),
    );
  }

  Future<void> _pickReminderTime(PracticePlan plan) async {
    if (plan.reminderTime == null && !await _ensurePermission()) return;
    if (!mounted) return;
    final initial = plan.reminderTime ?? ReminderTime(hour: 20, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: '选择练习提醒时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected == null || !mounted) return;
    await _setReminder(
      plan,
      ReminderTime(hour: selected.hour, minute: selected.minute),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(practicePlansProvider);
    final singlePlan = widget.planId != null;
    return Scaffold(
      appBar: AppBar(title: Text(singlePlan ? '计划提醒' : '练习提醒')),
      body: SafeArea(
        child: plans.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ReminderMessage(
            message: '暂时无法读取练习计划。',
            actionLabel: '重试',
            onAction: () => ref.invalidate(practicePlansProvider),
          ),
          data: (values) {
            final visible = widget.planId == null
                ? List<PracticePlan>.of(values)
                : values
                      .where((plan) => plan.id == widget.planId)
                      .toList(growable: false);
            visible.sort(
              (left, right) => right.updatedAt.compareTo(left.updatedAt),
            );
            if (visible.isEmpty) {
              return _ReminderMessage(
                message: singlePlan ? '这个练习计划已不存在。' : '还没有可设置提醒的练习计划。',
                actionLabel: singlePlan ? null : '新建计划',
                onAction: singlePlan ? null : () => context.push('/plans/new'),
              );
            }
            final enabledCount = visible
                .where((plan) => plan.reminderTime != null)
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _ReminderHeader(
                  planCount: visible.length,
                  enabledCount: enabledCount,
                  singlePlan: singlePlan,
                ),
                const SizedBox(height: 16),
                for (final plan in visible) ...[
                  _ReminderPlanCard(
                    plan: plan,
                    busy: _busyPlanIds.contains(plan.id),
                    onToggle: (enabled) => _toggleReminder(plan, enabled),
                    onPickTime: () => _pickReminderTime(plan),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReminderHeader extends StatelessWidget {
  const _ReminderHeader({
    required this.planCount,
    required this.enabledCount,
    required this.singlePlan,
  });

  final int planCount;
  final int enabledCount;
  final bool singlePlan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 10),
                Text(
                  singlePlan ? '随时调整这个计划' : '$enabledCount / $planCount 个计划已开启',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('提醒日期沿用计划的练习日和有效期；系统可能因省电策略略有延迟。'),
          ],
        ),
      ),
    );
  }
}

class _ReminderPlanCard extends StatelessWidget {
  const _ReminderPlanCard({
    required this.plan,
    required this.busy,
    required this.onToggle,
    required this.onPickTime,
  });

  final PracticePlan plan;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final reminder = plan.reminderTime;
    return Card(
      key: ValueKey('reminder_plan_${plan.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: ValueKey('plan_reminder_switch_${plan.id}'),
              value: reminder != null,
              onChanged: busy ? null : onToggle,
              title: Text(
                plan.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                reminder == null
                    ? '提醒已关闭'
                    : '${reminder.hhmm} · ${_weekdayLabel(plan.repeatWeekdays)}',
              ),
              secondary: busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      reminder == null
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${_formatDate(plan.startDate)}–${_formatDate(plan.endDate)} · '
                '${_weekdayLabel(plan.repeatWeekdays)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('plan_reminder_time_${plan.id}'),
                onPressed: busy ? null : onPickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  reminder == null ? '选择时间并开启' : '修改时间 ${reminder.hhmm}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderMessage extends StatelessWidget {
  const _ReminderMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _weekdayLabel(Set<int> weekdays) {
  if (weekdays.length == 7) return '每天';
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((day) => '周${labels[day - 1]}').join('、');
}

String _formatDate(CalendarDate date) =>
    '${date.year}/${date.month}/${date.day}';

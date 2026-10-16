import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/practice_reminder_gateway.dart';
import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_plan/reminder_time.dart';
import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../library/practice_source_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'practice_plan_providers.dart';
import 'practice_reminder_providers.dart';

/// Stable widget keys exposed for navigation and widget tests.
abstract final class PlanEditorKeys {
  static const screen = Key('plan_editor_screen');
  static const nameField = Key('plan_name_field');
  static const sourceDropdown = Key('plan_source_dropdown');
  static const segmentDropdown = Key('plan_segment_dropdown');
  static const goalTypeControl = Key('plan_goal_type_control');
  static const loopGoalField = Key('plan_goal_loops_field');
  static const durationGoalField = Key('plan_goal_duration_minutes_field');
  static const startDateButton = Key('plan_start_date_button');
  static const endDateButton = Key('plan_end_date_button');
  static const saveButton = Key('plan_save_button');
  static const reminderSwitch = Key('plan_reminder_switch');
  static const reminderTimeButton = Key('plan_reminder_time_button');
  static const createPracticeButton = Key('plan_editor_create_practice_button');
  static const retryPlanButton = Key('plan_editor_retry_plan_button');
  static const retrySourcesButton = Key('plan_editor_retry_sources_button');
  static const retrySegmentsButton = Key('plan_editor_retry_segments_button');

  static Key weekday(int weekday) => ValueKey('plan_weekday_$weekday');
}

/// Creates or edits one single-target practice plan.
///
/// When [planId] is null a new plan is created. [initialSourceId] and
/// [initialSegmentId] can preselect a target for a new plan opened from the
/// library. Persisted values always take precedence while editing.
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({
    this.planId,
    this.initialSourceId,
    this.initialSegmentId,
    super.key,
  });

  final String? planId;
  final String? initialSourceId;
  final String? initialSegmentId;

  bool get isEditing => planId != null;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  static const _wholeSourceValue = '__whole_source__';
  static const _weekdayLabels = <int, String>{
    DateTime.monday: '一',
    DateTime.tuesday: '二',
    DateTime.wednesday: '三',
    DateTime.thursday: '四',
    DateTime.friday: '五',
    DateTime.saturday: '六',
    DateTime.sunday: '日',
  };

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _loopsController = TextEditingController(text: '10');
  final _minutesController = TextEditingController(text: '10');

  late CalendarDate _startDate;
  late CalendarDate _endDate;
  String? _selectedSourceId;
  String? _selectedSegmentId;
  PracticeGoalType _goalType = PracticeGoalType.loops;
  Set<int> _repeatWeekdays = Set<int>.of(_weekdayLabels.keys);
  bool _reminderEnabled = false;
  ReminderTime _reminderTime = ReminderTime(hour: 20, minute: 0);
  PracticePlan? _editingPlan;
  bool _didInitializeEditingPlan = false;
  bool _isSaving = false;
  bool _showWeekdayError = false;

  @override
  void initState() {
    super.initState();
    final today = CalendarDate.fromDateTime(DateTime.now());
    _startDate = today;
    _endDate = today.addDays(6);
    _selectedSourceId = widget.initialSourceId;
    _selectedSegmentId = widget.initialSegmentId;
  }

  @override
  void didUpdateWidget(covariant PlanEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing &&
        (oldWidget.initialSourceId != widget.initialSourceId ||
            oldWidget.initialSegmentId != widget.initialSegmentId)) {
      _selectedSourceId = widget.initialSourceId;
      _selectedSegmentId = widget.initialSegmentId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _loopsController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _initializeEditingPlan(PracticePlan plan) {
    if (_didInitializeEditingPlan) return;
    _didInitializeEditingPlan = true;
    _editingPlan = plan;
    _nameController.text = plan.name;
    _selectedSourceId = plan.sourceId;
    _selectedSegmentId = plan.segmentId;
    _goalType = plan.goal.type;
    _loopsController.text = (plan.goal.targetLoops ?? 10).toString();
    _minutesController.text = (plan.goal.targetDuration?.inMinutes ?? 10)
        .toString();
    _startDate = plan.startDate;
    _endDate = plan.endDate;
    _repeatWeekdays = Set<int>.of(plan.repeatWeekdays);
    _reminderEnabled = plan.reminderTime != null;
    _reminderTime = plan.reminderTime ?? ReminderTime(hour: 20, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final planId = widget.planId;
    if (planId != null) {
      final plan = ref.watch(practicePlanByIdProvider(planId));
      return plan.when(
        loading: () => _EditorScaffold(
          title: '编辑计划',
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _EditorScaffold(
          title: '编辑计划',
          child: _MessageView(
            icon: Icons.error_outline_rounded,
            title: '暂时无法读取计划',
            message: '请检查后重试。',
            action: FilledButton.icon(
              key: PlanEditorKeys.retryPlanButton,
              onPressed: () => ref.invalidate(practicePlanByIdProvider(planId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ),
        ),
        data: (plan) {
          if (plan == null) {
            return _EditorScaffold(
              title: '编辑计划',
              child: _MessageView(
                icon: Icons.event_busy_outlined,
                title: '这个计划不存在',
                message: '它可能已经被删除。',
                action: FilledButton(
                  onPressed: () => context.go('/plans'),
                  child: const Text('返回计划列表'),
                ),
              ),
            );
          }
          _initializeEditingPlan(plan);
          return _buildWithSources();
        },
      );
    }
    return _buildWithSources();
  }

  Widget _buildWithSources() {
    final sources = ref.watch(practiceSourcesProvider);
    return _EditorScaffold(
      key: PlanEditorKeys.screen,
      title: widget.isEditing ? '编辑计划' : '新建计划',
      child: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _MessageView(
          icon: Icons.library_music_outlined,
          title: '暂时无法读取练习库',
          message: '计划需要关联一个练习内容，请重试。',
          action: FilledButton.icon(
            key: PlanEditorKeys.retrySourcesButton,
            onPressed: () => ref.invalidate(practiceSourcesProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const _EmptyLibraryView();
          return _buildForm(items);
        },
      ),
    );
  }

  Widget _buildForm(List<PracticeSource> sources) {
    final selectedSource = sources
        .where((source) => source.id == _selectedSourceId)
        .firstOrNull;
    final selectedSourceId = selectedSource?.id;
    final segments = selectedSourceId == null
        ? null
        : ref.watch(practiceSegmentsProvider(selectedSourceId));

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: '基本信息',
                  child: TextFormField(
                    key: PlanEditorKeys.nameField,
                    controller: _nameController,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '计划名称',
                      hintText: '例如：一周指弹强化',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return '请输入计划名称';
                      if (name.length > 120) return '计划名称不能超过 120 个字符';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '练习内容',
                  description: '一个计划先聚焦一个整曲或片段，之后可以继续创建其他计划。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyedSubtree(
                        key: ValueKey(
                          'plan_source_selection-'
                          '${selectedSourceId ?? 'none'}-${sources.length}',
                        ),
                        child: DropdownButtonFormField<String>(
                          key: PlanEditorKeys.sourceDropdown,
                          initialValue: selectedSourceId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '来源',
                            border: OutlineInputBorder(),
                          ),
                          items: sources
                              .map(
                                (source) => DropdownMenuItem(
                                  value: source.id,
                                  child: Text(
                                    '${source.title} · '
                                    '${_platformLabel(source.platform)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSourceId = value;
                                    _selectedSegmentId = null;
                                  });
                                },
                          validator: (_) {
                            if (_selectedSourceId == null) return '请选择练习来源';
                            if (selectedSource == null) {
                              return '所选练习来源已不存在，请重新选择';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedSource == null)
                        Text(
                          _selectedSourceId == null
                              ? '请先选择一个练习来源。'
                              : '原练习来源已不存在，请重新选择。',
                          style: TextStyle(
                            color: _selectedSourceId == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.error,
                          ),
                        )
                      else
                        _buildSegmentSelector(selectedSource, segments!),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '练习目标',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<PracticeGoalType>(
                        key: PlanEditorKeys.goalTypeControl,
                        segments: const [
                          ButtonSegment(
                            value: PracticeGoalType.loops,
                            icon: Icon(Icons.repeat_rounded),
                            label: Text('循环次数'),
                          ),
                          ButtonSegment(
                            value: PracticeGoalType.duration,
                            icon: Icon(Icons.timer_outlined),
                            label: Text('练习分钟'),
                          ),
                        ],
                        selected: {_goalType},
                        onSelectionChanged: _isSaving
                            ? null
                            : (selection) =>
                                  setState(() => _goalType = selection.single),
                      ),
                      const SizedBox(height: 14),
                      if (_goalType == PracticeGoalType.loops)
                        TextFormField(
                          key: PlanEditorKeys.loopGoalField,
                          controller: _loopsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '目标循环次数',
                            suffixText: '遍',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => _validatePositiveInteger(
                            value,
                            emptyMessage: '请输入目标循环次数',
                            invalidMessage: '循环次数必须是大于 0 的整数',
                          ),
                        )
                      else
                        TextFormField(
                          key: PlanEditorKeys.durationGoalField,
                          controller: _minutesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: '目标练习时长',
                            suffixText: '分钟',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => _validatePositiveInteger(
                            value,
                            emptyMessage: '请输入目标练习分钟',
                            invalidMessage: '练习分钟必须是大于 0 的整数',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '日期与重复',
                  description: '计划会在起止日期内的所选星期重复出现。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DateButton(
                              key: PlanEditorKeys.startDateButton,
                              label: '开始日期',
                              date: _startDate,
                              enabled: !_isSaving,
                              onPressed: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateButton(
                              key: PlanEditorKeys.endDateButton,
                              label: '截止日期',
                              date: _endDate,
                              enabled: !_isSaving,
                              onPressed: _pickEndDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '练习日',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdayLabels.entries
                            .map(
                              (entry) => FilterChip(
                                key: PlanEditorKeys.weekday(entry.key),
                                label: Text('周${entry.value}'),
                                selected: _repeatWeekdays.contains(entry.key),
                                onSelected: _isSaving
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          if (selected) {
                                            _repeatWeekdays.add(entry.key);
                                          } else {
                                            _repeatWeekdays.remove(entry.key);
                                          }
                                          _showWeekdayError = false;
                                        });
                                      },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      if (_showWeekdayError) ...[
                        const SizedBox(height: 8),
                        Text(
                          '请至少选择一个练习日',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '练习提醒',
                  description: '提醒日期沿用上方所选练习日；系统可能因省电策略略有延迟。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        key: PlanEditorKeys.reminderSwitch,
                        contentPadding: EdgeInsets.zero,
                        value: _reminderEnabled,
                        onChanged: _isSaving
                            ? null
                            : (value) =>
                                  setState(() => _reminderEnabled = value),
                        secondary: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text('练习提醒'),
                        subtitle: Text(
                          _reminderEnabled ? '将在所选练习日按设备本地时间提醒' : '未开启',
                        ),
                      ),
                      if (_reminderEnabled) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: PlanEditorKeys.reminderTimeButton,
                          onPressed: _isSaving ? null : _pickReminderTime,
                          style: OutlinedButton.styleFrom(
                            alignment: AlignmentDirectional.centerStart,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text('提醒时间  ${_reminderTime.hhmm}'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: PlanEditorKeys.saveButton,
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isSaving ? '正在保存…' : '保存计划'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentSelector(
    PracticeSource source,
    AsyncValue<List<PracticeSegment>> segments,
  ) {
    return segments.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedSegmentId == null
                    ? '片段读取失败；仍可将整曲加入计划。'
                    : '所选片段暂时无法读取，请重试。',
              ),
            ),
            TextButton(
              key: PlanEditorKeys.retrySegmentsButton,
              onPressed: () =>
                  ref.invalidate(practiceSegmentsProvider(source.id)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (items) {
        final selectedSegmentExists =
            _selectedSegmentId == null ||
            items.any((segment) => segment.id == _selectedSegmentId);
        final selectedValue = !selectedSegmentExists
            ? null
            : (_selectedSegmentId ?? _wholeSourceValue);
        return KeyedSubtree(
          key: ValueKey(
            'plan_segment_selection-${source.id}-'
            '${selectedValue ?? 'missing'}-${items.length}',
          ),
          child: DropdownButtonFormField<String>(
            key: PlanEditorKeys.segmentDropdown,
            initialValue: selectedValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '练习范围',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: _wholeSourceValue,
                child: Text(
                  '整曲 · ${source.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...items.map(
                (segment) => DropdownMenuItem(
                  value: segment.id,
                  child: Text(
                    '${segment.title} · ${_formatRange(segment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) => setState(() {
                    _selectedSegmentId = value == _wholeSourceValue
                        ? null
                        : value;
                  }),
            validator: (_) =>
                selectedSegmentExists ? null : '所选片段已不存在，请重新选择整曲或其他片段',
          ),
        );
      },
    );
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate.toLocalDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择开始日期',
    );
    if (selected == null || !mounted) return;
    final date = CalendarDate.fromDateTime(selected);
    setState(() {
      _startDate = date;
      if (_endDate < date) _endDate = date;
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate < _startDate
          ? _startDate.toLocalDateTime()
          : _endDate.toLocalDateTime(),
      firstDate: _startDate.toLocalDateTime(),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择截止日期',
    );
    if (selected == null || !mounted) return;
    setState(() => _endDate = CalendarDate.fromDateTime(selected));
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      ),
      helpText: '选择练习提醒时间',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _reminderTime = ReminderTime(
        hour: selected.hour,
        minute: selected.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final formIsValid = _formKey.currentState?.validate() ?? false;
    final weekdaysAreValid = _repeatWeekdays.isNotEmpty;
    if (!weekdaysAreValid) {
      setState(() => _showWeekdayError = true);
    }
    if (!formIsValid || !weekdaysAreValid) return;

    final sourceId = _selectedSourceId;
    if (sourceId == null) return;
    final goal = switch (_goalType) {
      PracticeGoalType.loops => PracticeGoal.loops(
        int.parse(_loopsController.text),
      ),
      PracticeGoalType.duration => PracticeGoal.duration(
        Duration(minutes: int.parse(_minutesController.text)),
      ),
    };

    var reminderTime = _reminderEnabled ? _reminderTime : null;
    var reminderPermissionUnavailable = false;
    if (reminderTime != null) {
      final status = await ref
          .read(practiceReminderGatewayProvider)
          .requestPermission();
      if (!mounted) return;
      if (status != ReminderPermissionStatus.granted) {
        reminderTime = null;
        reminderPermissionUnavailable = true;
        setState(() => _reminderEnabled = false);
      }
    }

    setState(() => _isSaving = true);
    try {
      final service = ref.read(practicePlanServiceProvider);
      final editingPlan = _editingPlan;
      final saved = editingPlan == null
          ? await service.create(
              name: _nameController.text,
              sourceId: sourceId,
              segmentId: _selectedSegmentId,
              goal: goal,
              startDate: _startDate,
              endDate: _endDate,
              repeatWeekdays: Set<int>.of(_repeatWeekdays),
              reminderTime: reminderTime,
            )
          : await service.update(
              editingPlan,
              name: _nameController.text,
              sourceId: sourceId,
              segmentId: _selectedSegmentId,
              goal: goal,
              startDate: _startDate,
              endDate: _endDate,
              repeatWeekdays: Set<int>.of(_repeatWeekdays),
              reminderTime: reminderTime,
            );
      ref.invalidate(practicePlanByIdProvider(saved.id));
      ref.invalidate(practicePlansProvider);
      if (!mounted) return;
      if (reminderPermissionUnavailable) {
        _showMessage('计划已保存，但通知权限未开启，练习提醒已关闭');
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/plans');
      }
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('保存计划失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validatePositiveInteger(
    String? value, {
    required String emptyMessage,
    required String invalidMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return emptyMessage;
    final number = int.tryParse(text);
    if (number == null || number <= 0) return invalidMessage;
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (description case final value?) ...[
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String label;
  final CalendarDate date;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: key,
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: AlignmentDirectional.centerStart,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            '${date.year}年${date.month}月${date.day}日',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  const _EmptyLibraryView();

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.library_music_outlined,
      title: '还没有可加入计划的练习',
      message: '请先通过链接或本地视频新建练习内容，再回来创建计划。',
      action: FilledButton.icon(
        key: PlanEditorKeys.createPracticeButton,
        onPressed: () => context.push('/create?returnTo=plan'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建练习'),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 54,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地视频',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'Bilibili',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页',
  };
}

String _formatRange(PracticeSegment segment) {
  return '${_formatDuration(segment.start)}–${_formatDuration(segment.end)}';
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

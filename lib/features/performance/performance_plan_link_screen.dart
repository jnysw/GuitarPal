import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_recording/practice_recording.dart';
import '../../domain/practice_segment/practice_segment.dart';
import '../plans/practice_plan_providers.dart';
import '../recordings/practice_recording_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'domain/performance_plan_link.dart';
import 'performance_take_providers.dart';

class PerformancePlanLinkScreen extends ConsumerStatefulWidget {
  const PerformancePlanLinkScreen({super.key, required this.recordingId});
  final String recordingId;
  @override
  ConsumerState<PerformancePlanLinkScreen> createState() => _LinkState();
}

class _LinkState extends ConsumerState<PerformancePlanLinkScreen> {
  bool _saving = false, _edited = false;
  String? _selected, _message;

  Future<void> _save(String? planId) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(performancePlanLinksProvider)
          .setPlan(widget.recordingId, planId);
      if (mounted) context.pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException ? e.message : '关联未能保存，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('关联练习计划')),
    body: SafeArea(
      child: ref
          .watch(practiceRecordingsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _error(
              '录音信息读取失败',
              () => ref.invalidate(practiceRecordingsProvider),
            ),
            data: (recordings) {
              final recording = recordings
                  .where((r) => r.id == widget.recordingId)
                  .firstOrNull;
              if (recording == null) {
                return const Center(child: Text('录音已不存在，请返回列表'));
              }
              return ref
                  .watch(practicePlansProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _error(
                      '计划读取失败',
                      () => ref.invalidate(practicePlansProvider),
                    ),
                    data: (plans) => ref
                        .watch(practiceSegmentsProvider(recording.sourceId))
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => _error(
                            '片段读取失败',
                            () => ref.invalidate(
                              practiceSegmentsProvider(recording.sourceId),
                            ),
                          ),
                          data: (segments) =>
                              _content(recording, plans, segments),
                        ),
                  );
            },
          ),
    ),
  );

  Widget _error(String message, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('重试')),
        ],
      ),
    ),
  );

  Widget _content(
    PracticeRecording recording,
    List<PracticePlan> all,
    List<PracticeSegment> segments,
  ) {
    try {
      savedPerformanceTake(recording);
    } on Object {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('请先保存有效的正式演奏，再关联计划'),
        ),
      );
    }
    final take = savedPerformanceTake(recording);
    final plans = all.where((p) => p.sourceId == recording.sourceId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final selected = _edited ? _selected : recording.planId;
    final selectedPlan = plans.where((p) => p.id == selected).firstOrNull;
    final issues = {
      for (final plan in plans)
        plan.id: performancePlanLinkIssue(
          take,
          plan,
          segments.where((s) => s.id == plan.segmentId).firstOrNull,
        ),
    };
    final current = all.where((p) => p.id == recording.planId).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(recording.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '实际录制原曲区间 ${_time(take.preset.startMs)}–${_time(take.endSourceMs)} · ${take.preset.speed.toStringAsFixed(2)}×',
        ),
        const SizedBox(height: 12),
        Text(
          recording.planId == null
              ? '尚未关联计划'
              : current == null
              ? '原关联计划已删除，历史录音仍保留'
              : '当前关联：${current.name}',
        ),
        const SizedBox(height: 8),
        const Text('一条演奏可关联一个同曲计划。更换或移除关联不删除录音，也不会自动完成计划或增加练习时长。'),
        const SizedBox(height: 20),
        if (plans.isEmpty) const Text('还没有同曲计划，可先在计划页新建。'),
        for (final plan in plans)
          Card(
            child: ListTile(
              key: ValueKey('performance_link_plan_${plan.id}'),
              selected: selected == plan.id,
              title: Text(plan.name),
              subtitle: Text(
                issues[plan.id] ??
                    (plan.segmentId == null ? '整曲计划' : '录制区间在此计划片段内'),
              ),
              trailing: selected == plan.id
                  ? const Icon(Icons.check_circle)
                  : const Icon(Icons.circle_outlined),
              enabled: !_saving && issues[plan.id] == null,
              onTap: !_saving && issues[plan.id] == null
                  ? () => setState(() {
                      _edited = true;
                      _selected = plan.id;
                    })
                  : null,
            ),
          ),
        const SizedBox(height: 16),
        if (_message != null)
          Text(
            _message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          key: const Key('performance_link_save'),
          onPressed:
              !_saving &&
                  selectedPlan != null &&
                  issues[selectedPlan.id] == null &&
                  selected != recording.planId
              ? () => _save(selected)
              : null,
          icon: const Icon(Icons.link),
          label: Text(_saving ? '正在保存…' : '保存关联'),
        ),
        if (recording.planId != null)
          TextButton(
            key: const Key('performance_link_remove'),
            onPressed: _saving ? null : () => _save(null),
            child: const Text('移除计划关联，保留演奏'),
          ),
      ],
    );
  }
}

String _time(int ms) =>
    '${ms ~/ 60000}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')}';

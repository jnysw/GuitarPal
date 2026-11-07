import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../library/practice_source_providers.dart';
import '../plans/practice_plan_providers.dart';
import 'domain/stem_practice_target.dart';

Future<StemPracticeTarget?> chooseStemPracticeTarget(
  BuildContext context,
  WidgetRef ref,
) async {
  final sources = await ref
      .read(practiceSourceRepositoryProvider)
      .watchAll()
      .first;
  if (!context.mounted) return null;
  final source = await showModalBottomSheet<PracticeSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('关联练习曲目'),
            subtitle: Text('选择与音频对应的曲目。此关联用于统计，不会自动同步原曲时间轴。'),
          ),
          if (sources.isEmpty) const ListTile(title: Text('请先在练习库创建或导入曲目')),
          for (final source in sources)
            ListTile(
              title: Text(source.title),
              onTap: () => Navigator.pop(context, source),
            ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  final plans = await ref.read(practicePlanRepositoryProvider).watchAll().first;
  if (!context.mounted) return null;
  final eligible = plans
      .where((p) => p.sourceId == source.id && p.segmentId == null)
      .toList();
  return showModalBottomSheet<StemPracticeTarget>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(source.title),
            subtitle: const Text('选择统计归属；本次选择不修改之前的记录'),
          ),
          ListTile(
            title: const Text('仅记入曲目练习'),
            onTap: () => Navigator.pop(
              context,
              StemPracticeTarget(
                sourceId: source.id,
                sourceTitle: source.title,
              ),
            ),
          ),
          for (final PracticePlan plan in eligible)
            ListTile(
              title: Text(plan.name),
              subtitle: const Text('计入此整曲计划'),
              onTap: () => Navigator.pop(
                context,
                StemPracticeTarget(
                  sourceId: source.id,
                  sourceTitle: source.title,
                  planId: plan.id,
                  planName: plan.name,
                ),
              ),
            ),
          const ListTile(subtitle: Text('片段计划需先完成原曲时间轴匹配，暂不显示。')),
        ],
      ),
    ),
  );
}

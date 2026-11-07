import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/stem_practice_target.dart';

class StemPracticeTargetRepository {
  const StemPracticeTargetRepository(this.database);
  final AppDatabase database;
  Future<StemPracticeTarget?> load(String taskId) async {
    final task = await (database.select(
      database.algorithmTasks,
    )..where((r) => r.id.equals(taskId))).getSingleOrNull();
    if (task?.linkedSourceId == null) return null;
    final source = await (database.select(
      database.practiceSources,
    )..where((r) => r.id.equals(task!.linkedSourceId!))).getSingleOrNull();
    if (source == null) return null;
    final plan = task!.linkedPlanId == null
        ? null
        : await (database.select(
            database.practicePlans,
          )..where((r) => r.id.equals(task.linkedPlanId!))).getSingleOrNull();
    final validPlan =
        plan != null && plan.sourceId == source.id && plan.segmentId == null;
    return StemPracticeTarget(
      sourceId: source.id,
      sourceTitle: source.title,
      planId: validPlan ? plan.id : null,
      planName: validPlan ? plan.name : null,
    );
  }

  Future<void> link(String taskId, {String? sourceId, String? planId}) =>
      database.transaction(() async {
        if (sourceId == null && planId != null) {
          throw const FormatException('计划必须关联曲目');
        }
        if (sourceId != null) {
          final source = await (database.select(
            database.practiceSources,
          )..where((r) => r.id.equals(sourceId))).getSingleOrNull();
          if (source == null) throw const FormatException('曲目已不存在，请重新选择');
        }
        if (planId != null) {
          final plan = await (database.select(
            database.practicePlans,
          )..where((r) => r.id.equals(planId))).getSingleOrNull();
          if (plan == null ||
              plan.sourceId != sourceId ||
              plan.segmentId != null) {
            throw const FormatException('请选择该曲目的整曲计划；片段计划需要先匹配原曲时间轴');
          }
        }
        final count =
            await (database.update(
              database.algorithmTasks,
            )..where((r) => r.id.equals(taskId))).write(
              AlgorithmTasksCompanion(
                linkedSourceId: Value(sourceId),
                linkedPlanId: Value(planId),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
        if (count != 1) throw const FormatException('分析任务已移除，无法关联统计');
      });
}

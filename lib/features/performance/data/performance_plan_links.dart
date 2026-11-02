import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/performance_plan_link.dart';
import '../../plans/data/drift_practice_plan_repository.dart';
import '../../recordings/data/drift_practice_recording_repository.dart';
import '../../segments/data/drift_practice_segment_repository.dart';

/// Only updates association columns in a transaction. Audio and capture context
/// are retained; this operation never creates a practice session or sync upload.
class PerformancePlanLinks {
  const PerformancePlanLinks(this.database);
  final db.AppDatabase database;

  Future<void> setPlan(String recordingId, String? planId) =>
      database.transaction(() async {
        final recording = await DriftPracticeRecordingRepository(database)
            .getById(recordingId);
        if (recording == null) throw const FormatException('录音已不存在，请返回列表');
        final take = savedPerformanceTake(recording);
        String? segmentId;
        if (planId != null) {
          final plan = await DriftPracticePlanRepository(database)
              .getById(planId);
          if (plan == null) throw const FormatException('计划已不存在，请重新选择');
          final segment = plan.segmentId == null
              ? null
              : await DriftPracticeSegmentRepository(database)
                    .getById(plan.segmentId!);
          final issue = performancePlanLinkIssue(take, plan, segment);
          if (issue != null) throw FormatException(issue);
          segmentId = plan.segmentId;
        }
        await (database.update(
          database.practiceRecordings,
        )..where((row) => row.id.equals(recordingId))).write(
          db.PracticeRecordingsCompanion(
            planId: Value(planId),
            segmentId: Value(segmentId),
          ),
        );
      });
}

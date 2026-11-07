import 'practice_recording.dart';

abstract interface class PracticeRecordingRepository {
  Stream<List<PracticeRecording>> watchAll();

  Stream<List<PracticeRecording>> watchBySource(String sourceId);

  Stream<List<PracticeRecording>> watchByPlan(String planId);

  Future<PracticeRecording?> getById(String id);

  Future<void> save(PracticeRecording recording);

  Future<void> delete(String id);
}

/// Atomically preserves plan, segment, session and note when an existing stage
/// recording's title or audition settings are saved again.
abstract interface class PerformanceTakeRecordingWriter {
  Future<void> savePerformanceTake(PracticeRecording recording);
}

import 'practice_recording.dart';

abstract interface class PracticeRecordingRepository {
  Stream<List<PracticeRecording>> watchAll();

  Stream<List<PracticeRecording>> watchBySource(String sourceId);

  Stream<List<PracticeRecording>> watchByPlan(String planId);

  Future<PracticeRecording?> getById(String id);

  Future<void> save(PracticeRecording recording);

  Future<void> delete(String id);
}

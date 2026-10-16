import 'practice_segment.dart';

abstract interface class PracticeSegmentRepository {
  Stream<List<PracticeSegment>> watchBySource(String sourceId);

  Future<PracticeSegment?> getById(String id);

  Future<void> save(PracticeSegment segment);

  Future<void> delete(String id);
}

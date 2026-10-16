import 'practice_source.dart';

abstract interface class PracticeSourceRepository {
  Stream<List<PracticeSource>> watchAll();

  Future<PracticeSource?> getById(String id);

  Future<void> save(PracticeSource source);

  Future<void> delete(String id);
}

import 'calendar_date.dart';
import 'practice_plan.dart';

abstract interface class PracticePlanRepository {
  Stream<List<PracticePlan>> watchAll();

  Stream<List<PracticePlan>> watchScheduledFor(CalendarDate date);

  Future<PracticePlan?> getById(String id);

  Future<void> save(PracticePlan plan);

  Future<void> delete(String id);
}

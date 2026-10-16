import '../practice_plan/calendar_date.dart';
import 'practice_session.dart';

abstract interface class PracticeSessionRepository {
  Stream<List<PracticeSession>> watchAll();

  Stream<List<PracticeSession>> watchForDate(CalendarDate date);

  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  );

  Future<void> save(PracticeSession session);
}

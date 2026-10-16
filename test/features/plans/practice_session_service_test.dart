import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_session/practice_session_repository.dart';
import 'package:guitar_pal/features/plans/application/practice_session_service.dart';

void main() {
  late _MemorySessionRepository repository;
  late PracticeSessionService service;
  late PracticePlan plan;

  final localNow = DateTime(2026, 10, 13, 23, 45, 30);

  setUp(() {
    repository = _MemorySessionRepository();
    service = PracticeSessionService(repository, clock: () => localNow);
    plan = PracticePlan(
      id: 'plan-1',
      name: '主歌循环',
      sourceId: 'source-1',
      segmentId: 'segment-1',
      goal: const PracticeGoal.loops(10),
      startDate: CalendarDate(2026, 10, 1),
      endDate: CalendarDate(2026, 12, 31),
      repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
  });

  test('records the local practice date, duration, and loop count', () async {
    final session = await service.record(
      plan: plan,
      activeDuration: const Duration(minutes: 12, seconds: 34),
      loopCount: 8,
    );

    expect(session.planId, 'plan-1');
    expect(session.sourceId, 'source-1');
    expect(session.segmentId, 'segment-1');
    expect(session.practiceDate, CalendarDate(2026, 10, 13));
    expect(session.activeDuration, const Duration(minutes: 12, seconds: 34));
    expect(session.loopCount, 8);
    expect(session.endedAt, localNow.toUtc());
    expect(
      session.startedAt,
      localNow.toUtc().subtract(const Duration(minutes: 12, seconds: 34)),
    );
    expect(session.completed, isTrue);
    expect(repository.sessions, [session]);
  });

  test('allows a duration-only or loops-only manual record', () async {
    final durationOnly = await service.record(
      plan: plan,
      activeDuration: const Duration(minutes: 5),
      loopCount: 0,
    );
    final loopsOnly = await service.record(
      plan: plan,
      activeDuration: Duration.zero,
      loopCount: 4,
    );

    expect(durationOnly.activeDuration, const Duration(minutes: 5));
    expect(durationOnly.loopCount, 0);
    expect(loopsOnly.activeDuration, Duration.zero);
    expect(loopsOnly.loopCount, 4);
    expect(repository.sessions, [durationOnly, loopsOnly]);
  });

  test('rejects a record with zero duration and zero loops', () async {
    await expectLater(
      service.record(plan: plan, activeDuration: Duration.zero, loopCount: 0),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          '请输入本次练习时长或循环次数',
        ),
      ),
    );

    expect(repository.sessions, isEmpty);
  });

  test('rejects negative duration and loop values', () async {
    await expectLater(
      service.record(
        plan: plan,
        activeDuration: const Duration(seconds: -1),
        loopCount: 0,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.record(plan: plan, activeDuration: Duration.zero, loopCount: -1),
      throwsA(isA<FormatException>()),
    );
    expect(repository.sessions, isEmpty);
  });
}

final class _MemorySessionRepository implements PracticeSessionRepository {
  final List<PracticeSession> sessions = [];

  @override
  Stream<List<PracticeSession>> watchAll() => Stream.value(List.of(sessions));

  @override
  Future<void> save(PracticeSession session) async {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
  }

  @override
  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    return Stream.value(
      sessions
          .where(
            (session) =>
                session.practiceDate >= start && session.practiceDate <= end,
          )
          .toList(),
    );
  }

  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate date) {
    return Stream.value(
      sessions.where((session) => session.practiceDate == date).toList(),
    );
  }
}

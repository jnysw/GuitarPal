import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_plan/practice_plan_progress.dart';
import '../../domain/practice_plan/practice_plan_repository.dart';
import '../../domain/practice_session/practice_session.dart';
import '../../domain/practice_session/practice_session_repository.dart';
import '../library/practice_source_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'application/practice_plan_service.dart';
import 'application/practice_session_service.dart';
import 'data/drift_practice_plan_repository.dart';
import 'data/drift_practice_session_repository.dart';

final practicePlanRepositoryProvider = Provider<PracticePlanRepository>((ref) {
  return DriftPracticePlanRepository(ref.watch(databaseProvider));
});

final practiceSessionRepositoryProvider = Provider<PracticeSessionRepository>((
  ref,
) {
  return DriftPracticeSessionRepository(ref.watch(databaseProvider));
});

final practicePlansProvider = StreamProvider<List<PracticePlan>>((ref) {
  return ref.watch(practicePlanRepositoryProvider).watchAll();
});

final practicePlanByIdProvider = FutureProvider.autoDispose
    .family<PracticePlan?, String>((ref, id) {
      return ref.watch(practicePlanRepositoryProvider).getById(id);
    });

final currentCalendarDateProvider = Provider<CalendarDate>((ref) {
  final now = DateTime.now();
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextDay.difference(now) + const Duration(seconds: 1), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return CalendarDate.fromDateTime(now);
});

final scheduledPracticePlansProvider = StreamProvider.autoDispose
    .family<List<PracticePlan>, CalendarDate>((ref, date) {
      return ref.watch(practicePlanRepositoryProvider).watchScheduledFor(date);
    });

final practiceSessionsForDateProvider = StreamProvider.autoDispose
    .family<List<PracticeSession>, CalendarDate>((ref, date) {
      return ref.watch(practiceSessionRepositoryProvider).watchForDate(date);
    });

final planProgressForDateProvider = Provider.autoDispose
    .family<AsyncValue<List<PracticePlanProgress>>, CalendarDate>((ref, date) {
      final plans = ref.watch(scheduledPracticePlansProvider(date));
      final sessions = ref.watch(practiceSessionsForDateProvider(date));
      return plans.when(
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
        data: (planValues) => sessions.when(
          loading: () => const AsyncLoading(),
          error: AsyncError.new,
          data: (sessionValues) => AsyncData(
            planValues
                .map(
                  (plan) =>
                      PracticePlanProgress(plan: plan, sessions: sessionValues),
                )
                .toList(growable: false),
          ),
        ),
      );
    });

final todayPlanProgressProvider =
    Provider<AsyncValue<List<PracticePlanProgress>>>((ref) {
      final date = ref.watch(currentCalendarDateProvider);
      return ref.watch(planProgressForDateProvider(date));
    });

final practicePlanServiceProvider = Provider<PracticePlanService>((ref) {
  return PracticePlanService(
    ref.watch(practicePlanRepositoryProvider),
    ref.watch(practiceSourceRepositoryProvider),
    ref.watch(practiceSegmentRepositoryProvider),
  );
});

final practiceSessionServiceProvider = Provider<PracticeSessionService>((ref) {
  return PracticeSessionService(ref.watch(practiceSessionRepositoryProvider));
});

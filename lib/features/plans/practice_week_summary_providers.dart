import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_week_summary.dart';
import '../../domain/practice_session/practice_session.dart';
import 'practice_plan_providers.dart';

final practiceSessionsForWeekProvider = StreamProvider.autoDispose
    .family<List<PracticeSession>, CalendarDate>((ref, containingDate) {
      final start = PracticeWeekSummary.weekStartFor(containingDate);
      final end = PracticeWeekSummary.weekEndFor(containingDate);
      return ref
          .watch(practiceSessionRepositoryProvider)
          .watchBetween(start, end);
    });

final practiceWeekSummaryProvider = Provider.autoDispose
    .family<AsyncValue<PracticeWeekSummary>, CalendarDate>((
      ref,
      containingDate,
    ) {
      final plans = ref.watch(practicePlansProvider);
      final sessions = ref.watch(
        practiceSessionsForWeekProvider(containingDate),
      );
      return plans.when(
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
        data: (planValues) => sessions.when(
          loading: () => const AsyncLoading(),
          error: AsyncError.new,
          data: (sessionValues) => AsyncData(
            PracticeWeekSummary.calculate(
              containingDate: containingDate,
              plans: planValues,
              sessions: sessionValues,
            ),
          ),
        ),
      );
    });

final thisWeekPracticeSummaryProvider =
    Provider<AsyncValue<PracticeWeekSummary>>((ref) {
      final today = ref.watch(currentCalendarDateProvider);
      return ref.watch(practiceWeekSummaryProvider(today));
    });

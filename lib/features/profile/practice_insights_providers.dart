import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/practice_session/practice_session.dart';
import '../library/practice_source_providers.dart';
import '../plans/practice_plan_providers.dart';
import 'domain/practice_insights.dart';

final allPracticeSessionsProvider = StreamProvider<List<PracticeSession>>((
  ref,
) {
  return ref.watch(practiceSessionRepositoryProvider).watchAll();
});

final practiceInsightsProvider = Provider<AsyncValue<PracticeInsights>>((ref) {
  final today = ref.watch(currentCalendarDateProvider);
  final sessions = ref.watch(allPracticeSessionsProvider);
  final sources = ref.watch(practiceSourcesProvider);
  return sessions.when(
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
    data: (sessionValues) => sources.when(
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
      data: (sourceValues) => AsyncData(
        PracticeInsights.calculate(
          today: today,
          sessions: sessionValues,
          sources: sourceValues,
        ),
      ),
    ),
  );
});

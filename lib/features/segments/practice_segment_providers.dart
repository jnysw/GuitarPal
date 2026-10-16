import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_segment/practice_segment_repository.dart';
import 'application/practice_segment_service.dart';
import 'data/drift_practice_segment_repository.dart';

final practiceSegmentRepositoryProvider = Provider<PracticeSegmentRepository>((
  ref,
) {
  return DriftPracticeSegmentRepository(ref.watch(databaseProvider));
});

final practiceSegmentsProvider = StreamProvider.autoDispose
    .family<List<PracticeSegment>, String>((ref, sourceId) {
      return ref
          .watch(practiceSegmentRepositoryProvider)
          .watchBySource(sourceId);
    });

final practiceSegmentByIdProvider = FutureProvider.autoDispose
    .family<PracticeSegment?, String>((ref, id) {
      return ref.watch(practiceSegmentRepositoryProvider).getById(id);
    });

final practiceSegmentServiceProvider = Provider<PracticeSegmentService>((ref) {
  return PracticeSegmentService(ref.watch(practiceSegmentRepositoryProvider));
});

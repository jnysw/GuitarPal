import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_tools/algorithm_providers.dart';
import '../library/practice_source_providers.dart';
import 'performance_providers.dart';
import 'application/performance_source_resolver.dart';

final performanceSourceResolverProvider = Provider<PerformanceSourceResolver>(
  (ref) => PerformanceSourceResolver(
    ref.watch(practiceSourceRepositoryProvider),
    ref.watch(algorithmTaskRepositoryProvider),
  ),
);
final performanceBackingProvider = FutureProvider.autoDispose
    .family<PerformanceBacking, String>((ref, sourceId) async {
      final preset = await ref.watch(backingPresetStoreProvider).load(sourceId);
      if (preset == null) throw const FormatException('请先准备并保存伴奏方案');
      return ref
          .watch(performanceSourceResolverProvider)
          .resolve(sourceId, preset);
    });

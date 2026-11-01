import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_tools/algorithm_providers.dart';
import '../recordings/practice_recording_providers.dart';
import 'application/performance_take_service.dart';
import 'data/performance_audio_platform.dart';
import 'data/performance_take_store.dart';

final performanceAudioProvider = Provider(
  (ref) => const PerformanceAudioPlatform(),
);
final performanceTakeStoreProvider = Provider(
  (ref) =>
      PerformanceTakeStore(ref.watch(algorithmStemPlatformProvider).directory),
);
final performanceTakeServiceProvider = Provider(
  (ref) => PerformanceTakeService(
    ref.watch(performanceTakeStoreProvider),
    ref.watch(practiceRecordingRepositoryProvider),
    ref.watch(practiceAudioRecorderProvider),
    ref.watch(performanceAudioProvider),
  ),
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import 'application/algorithm_task_service.dart';
import 'data/algorithm_audio_import.dart';
import 'data/algorithm_task_repository.dart';
import 'data/algorithm_stem_store.dart';
import 'data/algorithm_mix_platform.dart';
import 'domain/algorithm_task.dart';
import 'domain/algorithm_configuration.dart';
import 'data/stem_practice_target_repository.dart';
import 'data/video_audio_extractor.dart';

final algorithmAudioImportProvider = Provider<AlgorithmAudioImport>(
  (ref) => const MethodChannelAlgorithmAudioImport(),
);
final algorithmEndpointProvider = Provider<String>(
  (ref) => AlgorithmConfiguration.baseUrl,
);
final videoAudioExtractorProvider = Provider<VideoAudioExtractor>(
  (ref) => const VideoAudioExtractor(),
);
final algorithmTaskRepositoryProvider = Provider<AlgorithmTaskRepository>(
  (ref) => AlgorithmTaskRepository(ref.watch(databaseProvider)),
);
final algorithmTaskServiceProvider = Provider<AlgorithmTaskService>(
  (ref) => AlgorithmTaskService(
    ref.watch(algorithmTaskRepositoryProvider),
    allowLocalHttp: kDebugMode,
  ),
);
final algorithmTasksProvider = StreamProvider<List<AlgorithmTaskRecord>>(
  (ref) => ref.watch(algorithmTaskRepositoryProvider).watchAll(),
);
final algorithmStemPlatformProvider = Provider<AlgorithmStemPlatform>(
  (ref) => const AlgorithmStemPlatform(),
);
final algorithmStemStoreProvider = Provider<AlgorithmStemStore>(
  (ref) =>
      AlgorithmStemStore(ref.watch(algorithmStemPlatformProvider).directory),
);
final algorithmMixPlatformProvider = Provider<AlgorithmMixPlatform>(
  (ref) => const AlgorithmMixPlatform(),
);
final stemMixPreferencesProvider = Provider<StemMixPreferences>(
  (ref) =>
      StemMixPreferences(ref.watch(algorithmStemPlatformProvider).directory),
);
final stemPracticeTargetRepositoryProvider =
    Provider<StemPracticeTargetRepository>(
      (ref) => StemPracticeTargetRepository(ref.watch(databaseProvider)),
    );

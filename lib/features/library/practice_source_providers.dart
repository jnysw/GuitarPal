import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/platform/local_video_gateway.dart';
import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_source/practice_source_repository.dart';
import '../../media/metadata/source_metadata_providers.dart';
import '../audio_tools/algorithm_providers.dart';
import '../performance/performance_providers.dart';
import 'application/practice_library_service.dart';
import 'application/practice_notes_export_service.dart';
import 'application/source_launcher.dart';
import 'data/drift_practice_source_repository.dart';

final practiceSourceRepositoryProvider = Provider<PracticeSourceRepository>((
  ref,
) {
  return DriftPracticeSourceRepository(ref.watch(databaseProvider));
});

final practiceSourcesProvider = StreamProvider<List<PracticeSource>>((ref) {
  return ref.watch(practiceSourceRepositoryProvider).watchAll();
});

final practiceSourceByIdProvider = FutureProvider.autoDispose
    .family<PracticeSource?, String>((ref, id) {
      return ref.watch(practiceSourceRepositoryProvider).getById(id);
    });

final practiceLibraryServiceProvider = Provider<PracticeLibraryService>((ref) {
  return PracticeLibraryService(
    ref.watch(practiceSourceRepositoryProvider),
    localVideoGateway: ref.watch(localVideoGatewayProvider),
    metadataLoader: ref.watch(sourceMetadataLoaderProvider),
    deleteVideoMixPreferences: ref.watch(videoMixPreferencesProvider).delete,
    deletePerformancePreferences: ref.watch(backingPresetStoreProvider).delete,
  );
});

final practiceNotesExportServiceProvider = Provider<PracticeNotesExportService>(
  (ref) => const PracticeNotesExportService(),
);

final sourceLauncherProvider = Provider<SourceLauncher>((ref) {
  return const ExternalSourceLauncher();
});

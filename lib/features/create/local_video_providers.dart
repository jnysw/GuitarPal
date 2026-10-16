import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/platform/local_video_gateway.dart';
import '../library/practice_source_providers.dart';
import 'application/local_video_draft_store.dart';
import 'application/local_video_import_service.dart';

final localVideoDraftStoreProvider = Provider<LocalVideoDraftStore>((ref) {
  return LocalVideoDraftStore();
});

final localVideoImportServiceProvider = Provider<LocalVideoImportService>((
  ref,
) {
  return LocalVideoImportService(
    ref.watch(practiceSourceRepositoryProvider),
    ref.watch(localVideoGatewayProvider),
    const Uuid(),
  );
});

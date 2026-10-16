import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_source_metadata_loader.dart';
import 'source_metadata.dart';

final sourceMetadataLoaderProvider = Provider<SourceMetadataLoader>((ref) {
  return const HttpSourceMetadataLoader();
});

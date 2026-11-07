import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_tools/algorithm_providers.dart';
import 'data/backing_preset_store.dart';

final backingPresetStoreProvider = Provider<BackingPresetStore>(
  (ref) =>
      BackingPresetStore(ref.watch(algorithmStemPlatformProvider).directory),
);

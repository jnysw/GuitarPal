import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio_tools/algorithm_providers.dart';
import 'data/chord_preferences.dart';
import 'domain/chord_library.dart';

final guitarChordLibraryProvider = FutureProvider<GuitarChordLibrary>(
  (ref) async => GuitarChordLibrary.decode(
    await rootBundle.loadString('assets/chords/standard_guitar_v1.json'),
  ),
);
final chordPreferencesStoreProvider = Provider<ChordPreferencesStore>(
  (ref) =>
      ChordPreferencesStore(ref.watch(algorithmStemPlatformProvider).directory),
);
final chordPreferencesProvider =
    AsyncNotifierProvider<ChordPreferencesController, ChordPreferences>(
      ChordPreferencesController.new,
    );

class ChordPreferencesController extends AsyncNotifier<ChordPreferences> {
  @override
  Future<ChordPreferences> build() =>
      ref.watch(chordPreferencesStoreProvider).load();
  Future<bool> save(ChordPreferences value) async {
    state = AsyncData(value);
    try {
      await ref.read(chordPreferencesStoreProvider).save(value);
      return true;
    } on Object {
      return false;
    }
  }
}

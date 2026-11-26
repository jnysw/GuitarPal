import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/chords/domain/chord_library.dart';
import 'package:guitar_pal/features/chords/data/chord_preferences.dart';

void main() {
  final text = File('assets/chords/standard_guitar_v1.json').readAsStringSync();
  final library = GuitarChordLibrary.decode(text);
  test('pinned offline data validates every absolute fret, tone, finger, barre and slash bass', () {
    expect(library.voicings, hasLength(1693));
    expect(library.version, 'df06fa7b425cf5fd29485ff6591236b3557e3fac');
    for (final raw in ['C', 'A:min', 'F', 'Bm', 'C:hdim7', 'Bb:minmaj7']) {
      expect(library.lookup(raw), isNotEmpty, reason: raw);
    }
    expect(library.lookup('C').first.frets, [-1, 3, 2, 0, 1, 0]);
    expect(library.lookup('F').any((v) => v.barres.isNotEmpty), isTrue);
    expect(library.lookup('C').any((v) => v.baseFret >= 8), isTrue);
  });
  test('coverage report accounts for exact supported keys and pinned source identity', () {
    final report = jsonDecode(
      File('docs/ai_audio/chord_library_coverage.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final asset = jsonDecode(text) as Map<String, dynamic>;
    expect(
      asset['source_sha256'],
      'cfe439962b2f444d2c341b1f0261403b4c3a3416e321147286fc608922699974',
    );
    expect(report['voicings'], library.voicings.length);
    expect(
      report['chord_keys'],
      library.voicings.map((v) => v.chordKey).toSet().length,
    );
    final coverage = report['quality_coverage'] as Map<String, dynamic>;
    expect(coverage.length, 168);
    for (final entry in coverage.entries) {
      expect(entry.value, greaterThan(0), reason: entry.key);
      expect(
        entry.value,
        library.voicings.where((v) => v.chordKey == entry.key).length,
      );
    }
  });
  test('enharmonic spellings share lookup while qualities and inversions remain distinct', () {
    expect(
      library.lookup('Db:min7').map((v) => v.id),
      library.lookup('C#:min7').map((v) => v.id),
    );
    expect(GuitarChord.parse('Cm7♭5')!.key, GuitarChord.parse('C:hdim7')!.key);
    expect(GuitarChord.parse('C:min/b3')!.key, '0:min/3');
    expect(GuitarChord.parse('C:maj/3')!.key, '0:maj/4');
    expect(
      library.lookup('C:maj/3').map((v) => v.id),
      library.lookup('C/E').map((v) => v.id),
    );
    final inversion = library.lookup('C/E');
    expect(inversion, isNotEmpty);
    for (final v in inversion) {
      final notes = [
        for (var i = 0; i < 6; i++)
          if (v.frets[i] >= 0) standardGuitarTuning[i] + v.frets[i],
      ]..sort();
      expect(notes.first % 12, 4);
    }
    expect(library.lookup('C'), isNot(equals(inversion)));
    for (final label in [
      'N',
      'X',
      'C:weird',
      'C:13',
      'C/E/Am',
      'C/no',
      'C:dim/E',
    ]) {
      expect(library.lookup(label), isEmpty, reason: label);
    }
  });
  test(
    'corrupted tone, finger, barre and duplicate identifiers are rejected',
    () {
      Map<String, dynamic> data() => jsonDecode(text) as Map<String, dynamic>;
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (d) => d['tuning_midi'][0] = 41,
        (d) => d['voicings'][0][2][1] = 4,
        (d) => d['voicings'][0][3][1] = 0,
        (d) => d['voicings'][0][5] = [
          [1, 0, 7, 1],
        ],
        (d) => d['voicings'][1][0] = d['voicings'][0][0],
      ]) {
        final d = data();
        mutation(d);
        expect(
          () => GuitarChordLibrary.decode(jsonEncode(d)),
          throwsFormatException,
        );
      }
    },
  );
  test('preferences are serialized, persisted and read by a new store; missing IDs can fall back', () async {
    final root = Directory.systemTemp.createTempSync('gp_chord_prefs_');
    try {
      final store = ChordPreferencesStore(() async => root);
      expect((await store.load()).showDiagrams, isFalse);
      final p = ChordPreferences(
        showDiagrams: true,
        leftHanded: true,
        preferred: {'0:maj': library.lookup('C')[1].id},
      );
      await Future.wait([
        store.save(p),
        store.save(p.copyWith(leftHanded: false)),
      ]);
      final read = await ChordPreferencesStore(() async => root).load();
      expect(read.showDiagrams, isTrue);
      expect(read.leftHanded, isFalse);
      expect(read.preferred['0:maj'], p.preferred['0:maj']);
      expect(root.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
      final file = File('${root.path}/chord_display_v1.json');
      await file.writeAsString('{"version":99}');
      await expectLater(store.load(), throwsFormatException);
      await store.save(p);
      expect((await store.load()).showDiagrams, isTrue);
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}

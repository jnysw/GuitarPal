import 'dart:convert';

const standardGuitarTuning = [40, 45, 50, 55, 59, 64];
const chordIntervals = <String, List<int>>{
  'maj': [0, 4, 7],
  'min': [0, 3, 7],
  '7': [0, 4, 7, 10],
  'maj7': [0, 4, 7, 11],
  'min7': [0, 3, 7, 10],
  'dim': [0, 3, 6],
  'dim7': [0, 3, 6, 9],
  'hdim7': [0, 3, 6, 10],
  'aug': [0, 4, 8],
  'sus2': [0, 2, 7],
  'sus4': [0, 5, 7],
  'maj6': [0, 4, 7, 9],
  'min6': [0, 3, 7, 9],
  'minmaj7': [0, 3, 7, 11],
};

/// Structured pitch-class lookup; display spelling and raw analysis stay intact.
class GuitarChord {
  const GuitarChord(this.root, this.quality, this.bass);
  final int root;
  final String quality;
  final int? bass;
  String get key => '$root:$quality${bass == null ? '' : '/$bass'}';
  static int? pitchClass(String note) {
    final match = RegExp(r'^([A-G])([#b]?)$').firstMatch(note);
    if (match == null) return null;
    return ({
              'C': 0,
              'D': 2,
              'E': 4,
              'F': 5,
              'G': 7,
              'A': 9,
              'B': 11,
            }[match[1]]! +
            (match[2] == '#'
                ? 1
                : match[2] == 'b'
                ? -1
                : 0)) %
        12;
  }

  static GuitarChord? parse(String raw) {
    final label = raw.trim().replaceAll('♭', 'b').replaceAll('♯', '#');
    final parts = label.split('/');
    if (parts.length > 2) return null;
    final match = RegExp(r'^([A-G][#b]?)(?::)?(.*)$').firstMatch(parts[0]);
    if (match == null) return null;
    const aliases = {
      '': 'maj',
      'major': 'maj',
      'maj': 'maj',
      'm': 'min',
      'min': 'min',
      'minor': 'min',
      '7': '7',
      'maj7': 'maj7',
      'M7': 'maj7',
      'min7': 'min7',
      'm7': 'min7',
      'dim': 'dim',
      'dim7': 'dim7',
      'hdim7': 'hdim7',
      'm7b5': 'hdim7',
      'aug': 'aug',
      'sus2': 'sus2',
      'sus4': 'sus4',
      '6': 'maj6',
      'maj6': 'maj6',
      'm6': 'min6',
      'min6': 'min6',
      'minmaj7': 'minmaj7',
      'mmaj7': 'minmaj7',
      'm(maj7)': 'minmaj7',
    };
    final quality = aliases[match[2]];
    final root = pitchClass(match[1]!);
    if (quality == null || root == null) return null;
    int? bass;
    if (parts.length == 2) {
      bass = pitchClass(parts[1]);
      if (bass == null) {
        // Harte slash degrees are relative to root, not absolute pitch names.
        final degree = RegExp(r'^(bb|b|#)?([1-7])$').firstMatch(parts[1]);
        if (degree == null) return null;
        final interval = [0, 2, 4, 5, 7, 9, 11][int.parse(degree[2]!) - 1];
        bass =
            (root +
                interval +
                switch (degree[1]) {
                  'bb' => -2,
                  'b' => -1,
                  '#' => 1,
                  _ => 0,
                }) %
            12;
      }
    }
    return GuitarChord(root, quality, bass);
  }
}

class GuitarVoicing {
  GuitarVoicing(
    this.id,
    this.chordKey,
    List<int> frets,
    List<int> fingers,
    this.baseFret,
    List<List<int>> barres,
  ) : frets = List.unmodifiable(frets),
      fingers = List.unmodifiable(fingers),
      barres = List.unmodifiable(barres.map((b) => List<int>.unmodifiable(b)));
  final String id, chordKey;
  final List<int> frets, fingers;
  final int baseFret;
  final List<List<int>> barres;
  String get description => [
    if (frets.contains(0)) '开放和弦',
    if (barres.isNotEmpty) '横按',
    if (baseFret > 4) '高把位',
  ].join(' · ');
  String get stringDescription => List.generate(
    6,
    (i) =>
        '${6 - i}弦${frets[i] < 0
            ? '不弹'
            : frets[i] == 0
            ? '空弦'
            : '${frets[i]}品，${fingers[i]}指'}',
  ).join('；');
}

class GuitarChordLibrary {
  GuitarChordLibrary._(this.version, this.voicings);
  final String version;
  final List<GuitarVoicing> voicings;
  late final Map<String, List<GuitarVoicing>> _index = () {
    final result = <String, List<GuitarVoicing>>{};
    for (final v in voicings) {
      result.putIfAbsent(v.chordKey, () => []).add(v);
    }
    for (final values in result.values) {
      values.sort(_compare);
    }
    return result;
  }();
  List<GuitarVoicing> lookup(String raw) {
    final chord = GuitarChord.parse(raw);
    return chord == null
        ? const []
        : List.unmodifiable(_index[chord.key] ?? const []);
  }

  static int _compare(GuitarVoicing a, GuitarVoicing b) {
    List<int> rank(GuitarVoicing v) {
      final pressed = v.frets.where((f) => f > 0).toList()..sort();
      return [
        v.barres.length,
        pressed.isEmpty ? 0 : pressed.last - pressed.first,
        v.baseFret,
        pressed.length,
      ];
    }

    final x = rank(a), y = rank(b);
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return x[i].compareTo(y[i]);
    }
    return a.id.compareTo(b.id);
  }

  factory GuitarChordLibrary.decode(String source) {
    if (source.length > 2000000) throw const FormatException('指法库过大');
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['schema_version'] != 1 ||
        json['string_order'] != 'low_to_high' ||
        jsonEncode(json['tuning_midi']) != jsonEncode(standardGuitarTuning)) {
      throw const FormatException('指法库版本或定弦无效');
    }
    final rows = json['voicings'] as List<dynamic>;
    if (rows.length > 10000) throw const FormatException('指法库条数过多');
    final ids = <String>{};
    final result = <GuitarVoicing>[];
    for (final dynamic row in rows) {
      final r = row as List<dynamic>;
      if (r.length != 6) throw const FormatException('指法字段无效');
      final v = GuitarVoicing(
        r[0] as String,
        r[1] as String,
        (r[2] as List).cast<int>(),
        (r[3] as List).cast<int>(),
        r[4] as int,
        (r[5] as List).map((b) => (b as List).cast<int>()).toList(),
      );
      final match = RegExp(r'^(\d{1,2}):([a-z0-9]+)(?:/(\d{1,2}))?$')
          .firstMatch(v.chordKey);
      if (!ids.add(v.id) ||
          match == null ||
          v.frets.length != 6 ||
          v.fingers.length != 6 ||
          v.baseFret < 1 ||
          v.baseFret > 24) {
        throw const FormatException('指法结构无效');
      }
      final root = int.parse(match[1]!);
      final quality = chordIntervals[match[2]];
      final bass = match[3] == null ? null : int.parse(match[3]!);
      if (root > 11 || quality == null || (bass != null && bass > 11)) {
        throw const FormatException('和弦音高无效');
      }
      final tones = quality.map((n) => (root + n) % 12).toSet();
      final midi = <int>[];
      for (var i = 0; i < 6; i++) {
        final f = v.frets[i], finger = v.fingers[i];
        if (f < -1 ||
            f > 24 ||
            finger < 0 ||
            finger > 4 ||
            (f > 0) != (finger > 0) ||
            (f > 0 && (f < v.baseFret || f >= v.baseFret + 4))) {
          throw const FormatException('指法品位无效');
        }
        if (f >= 0) midi.add(standardGuitarTuning[i] + f);
      }
      final pitches = midi.map((n) => n % 12).toSet();
      if (!pitches.containsAll(tones) ||
          !{...tones, ?bass}.containsAll(pitches) ||
          (bass != null && (midi..sort()).first % 12 != bass)) {
        throw const FormatException('指法和弦音或低音不匹配');
      }
      for (final b in v.barres) {
        if (b.length != 4 ||
            b[0] < v.baseFret ||
            b[0] >= v.baseFret + 4 ||
            b[1] < 0 ||
            b[2] > 5 ||
            b[1] >= b[2] ||
            b[3] < 1 ||
            b[3] > 4 ||
            v.frets[b[1]] != b[0] ||
            v.frets[b[2]] != b[0] ||
            v.fingers[b[1]] != b[3] ||
            v.fingers[b[2]] != b[3]) {
          throw const FormatException('横按无效');
        }
      }
      result.add(v);
    }
    return GuitarChordLibrary._(
      json['source_version'] as String,
      List.unmodifiable(result),
    );
  }
}

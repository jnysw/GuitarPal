import 'dart:convert';
import 'dart:io';

class ChordPreferences {
  ChordPreferences({
    this.showDiagrams = false,
    this.leftHanded = false,
    Map<String, String> preferred = const {},
  }) : preferred = Map.unmodifiable(preferred);
  final bool showDiagrams, leftHanded;
  final Map<String, String> preferred;
  ChordPreferences copyWith({
    bool? showDiagrams,
    bool? leftHanded,
    Map<String, String>? preferred,
  }) => ChordPreferences(
    showDiagrams: showDiagrams ?? this.showDiagrams,
    leftHanded: leftHanded ?? this.leftHanded,
    preferred: preferred ?? this.preferred,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'showDiagrams': showDiagrams,
    'leftHanded': leftHanded,
    'preferred': preferred,
  };
  factory ChordPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['showDiagrams'] is! bool ||
        json['leftHanded'] is! bool ||
        json['preferred'] is! Map) {
      throw const FormatException('指法设置无效');
    }
    final preferred = (json['preferred'] as Map).cast<String, String>();
    if (preferred.length > 1024 ||
        preferred.entries.any(
          (e) =>
              !RegExp(r'^\d{1,2}:[a-z0-9]+(?:/\d{1,2})?$').hasMatch(e.key) ||
              e.value.isEmpty ||
              e.value.length > 128,
        )) {
      throw const FormatException('指法偏好无效');
    }
    return ChordPreferences(
      showDiagrams: json['showDiagrams'] as bool,
      leftHanded: json['leftHanded'] as bool,
      preferred: preferred,
    );
  }
}

/// One global local preference; no transport or analysis-result mutation.
class ChordPreferencesStore {
  ChordPreferencesStore(this.root);
  final Future<Directory> Function() root;
  Future<void> _tail = Future.value();
  Future<File> _file() async =>
      File('${(await root()).path}/chord_display_v1.json');
  Future<ChordPreferences> load() async {
    await _tail;
    final file = await _file();
    if (!await file.exists()) return ChordPreferences();
    if (await file.length() > 262144) throw const FormatException('指法设置过大');
    return ChordPreferences.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> save(ChordPreferences preferences) {
    final payload = jsonEncode(
      ChordPreferences.fromJson(preferences.toJson()).toJson(),
    );
    final write = _tail.then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.part');
      try {
        await temp.writeAsString(payload, flush: true);
        await temp.rename(file.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
    _tail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}

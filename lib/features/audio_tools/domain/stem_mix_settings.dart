import '../../../media/playback/playback_speed.dart';
import 'legacy_algorithm_models.dart';

enum StemMixMode { instruments, vocalsAndBacking }

const stemMixIds = [
  'vocals',
  'drums',
  'bass',
  'guitar',
  'piano',
  'other',
  'instrumental',
];

class StemMixControl {
  const StemMixControl({
    this.volume = 1,
    this.muted = false,
    this.solo = false,
    this.pan = 0,
  });
  final double volume;
  final bool muted;
  final bool solo;
  final double pan;
  StemMixControl copyWith({
    double? volume,
    bool? muted,
    bool? solo,
    double? pan,
  }) => StemMixControl(
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    solo: solo ?? this.solo,
    pan: pan ?? this.pan,
  );
  Map<String, Object?> toJson() => {
    'volume': volume,
    'muted': muted,
    'solo': solo,
    'pan': pan,
  };
  factory StemMixControl.fromJson(Map<String, Object?> json) {
    final volume = _gain(json['volume']);
    final pan = json['pan'] ?? 0;
    if (pan is! num || !pan.isFinite || pan < -1 || pan > 1) {
      throw const FormatException('声像无效');
    }
    if (json['muted'] is! bool || json['solo'] is! bool) {
      throw const FormatException('音轨开关无效');
    }
    return StemMixControl(
      volume: volume,
      muted: json['muted'] as bool,
      solo: json['solo'] as bool,
      pan: pan.toDouble(),
    );
  }
}

class StemMixLoop {
  const StemMixLoop(this.startMs, this.endMs);
  final int startMs;
  final int endMs;
  void validate(int durationMs) {
    if (startMs < 0 || endMs > durationMs || endMs - startMs < 250) {
      throw const FormatException('A-B 区间至少 0.25 秒，且不能超出音轨');
    }
  }
}

class StemMixSettings {
  StemMixSettings({
    this.mode = StemMixMode.instruments,
    this.master = .8,
    this.speed = 1,
    this.loop,
    Map<String, StemMixControl>? controls,
  }) : controls = Map.unmodifiable({
         for (final id in stemMixIds)
           id: controls?[id] ?? const StemMixControl(),
       });
  final StemMixMode mode;
  final double master;
  final double speed;
  final StemMixLoop? loop;
  final Map<String, StemMixControl> controls;
  bool includes(String id) => mode == StemMixMode.vocalsAndBacking
      ? {'vocals', 'instrumental'}.contains(id)
      : stemMixIds.contains(id) && id != 'instrumental';

  Map<String, double> effectiveGains(Iterable<String> loadedIds) {
    final ids = loadedIds.toList();
    if (ids.isEmpty ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !includes(id))) {
      throw const FormatException('混音音轨与模式不一致');
    }
    // Solo applies only to loaded tracks in this mode; missing files cannot mute everything.
    final anySolo = ids.any((id) => controls[id]!.solo);
    return {
      for (final id in ids)
        id: controls[id]!.muted || (anySolo && !controls[id]!.solo)
            ? 0
            : controls[id]!.volume,
    };
  }

  StemMixSettings copyWith({
    StemMixMode? mode,
    double? master,
    double? speed,
    StemMixLoop? loop,
    bool clearLoop = false,
    Map<String, StemMixControl>? controls,
  }) => StemMixSettings(
    mode: mode ?? this.mode,
    master: master ?? this.master,
    speed: speed ?? this.speed,
    loop: clearLoop ? null : loop ?? this.loop,
    controls: controls ?? this.controls,
  );

  Map<String, Object?> platformConfiguration(Iterable<String> loadedIds) => {
    'gains': effectiveGains(loadedIds),
    'pans': {for (final id in loadedIds) id: controls[id]!.pan},
    'master': master,
    'speed': speed,
    'loopStartMs': loop?.startMs,
    'loopEndMs': loop?.endMs,
  };
  Map<String, Object?> toJson() => {
    'version': 1,
    'mode': mode.name,
    'master': master,
    'speed': speed,
    'loop': loop == null
        ? null
        : {'startMs': loop!.startMs, 'endMs': loop!.endMs},
    'controls': controls.map((id, value) => MapEntry(id, value.toJson())),
  };
  factory StemMixSettings.fromJson(Map<String, Object?> json, int durationMs) {
    if (json['version'] != 1) throw const FormatException('练习设置版本不支持');
    final mode = StemMixMode.values
        .where((mode) => mode.name == json['mode'])
        .firstOrNull;
    if (mode == null) throw const FormatException('混音模式无效');
    final speed = json['speed'];
    if (speed is! num ||
        !speed.isFinite ||
        speed < minPlaybackSpeed ||
        speed > maxPlaybackSpeed) {
      throw const FormatException('倍速设置无效');
    }
    final raw = algorithmObject(json['controls']);
    if (raw.length != stemMixIds.length ||
        raw.keys.any((id) => !stemMixIds.contains(id))) {
      throw const FormatException('音轨设置无效');
    }
    StemMixLoop? loop;
    if (json['loop'] != null) {
      final value = algorithmObject(json['loop']);
      loop = StemMixLoop(
        algorithmInteger(value['startMs']),
        algorithmInteger(value['endMs']),
      );
      loop.validate(durationMs);
    }
    return StemMixSettings(
      mode: mode,
      master: _gain(json['master']),
      speed: normalizePlaybackSpeed(speed.toDouble()),
      loop: loop,
      controls: raw.map(
        (id, value) =>
            MapEntry(id, StemMixControl.fromJson(algorithmObject(value))),
      ),
    );
  }
}

double _gain(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const FormatException('音量无效');
  }
  return value.toDouble();
}

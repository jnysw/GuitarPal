import 'legacy_algorithm_models.dart';
import 'stem_mix_settings.dart';

const videoStemIds = ['vocals', 'drums', 'bass', 'guitar', 'piano', 'other'];

/// Only the selected analysis and per-track controls. Transport belongs to the video/plan.
class VideoMixSelection {
  VideoMixSelection({
    required this.taskId,
    required this.inputSha256,
    required this.useStems,
    Map<String, StemMixControl>? controls,
  }) : controls = Map.unmodifiable(
         controls ??
             {for (final id in videoStemIds) id: const StemMixControl()},
       ) {
    algorithmId(taskId);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(inputSha256) ||
        this.controls.isEmpty ||
        this.controls.length > 16 ||
        (this.controls.containsKey('instrumental') &&
            this.controls.keys.any(
              (id) => !{'vocals', 'instrumental'}.contains(id),
            ))) {
      throw const FormatException('视频分轨设置无效');
    }
    for (final entry in this.controls.entries) {
      algorithmId(entry.key);
      final control = entry.value;
      StemMixControl.fromJson(control.toJson());
    }
  }
  final String taskId, inputSha256;
  final bool useStems;
  final Map<String, StemMixControl> controls;
  Map<String, double> get gains {
    final anySolo = controls.values.any((c) => c.solo);
    return controls.map(
      (id, c) => MapEntry(id, c.muted || (anySolo && !c.solo) ? 0.0 : c.volume),
    );
  }

  Map<String, double> get pans => controls.map((id, c) => MapEntry(id, c.pan));
  VideoMixSelection forTracks(Iterable<String> ids) => VideoMixSelection(
    taskId: taskId,
    inputSha256: inputSha256,
    useStems: useStems,
    controls: {
      for (final id in ids) id: controls[id] ?? const StemMixControl(),
    },
  );
  VideoMixSelection withMode(bool stems) => VideoMixSelection(
    taskId: taskId,
    inputSha256: inputSha256,
    useStems: stems,
    controls: controls,
  );
  Map<String, Object?> toJson() => {
    'version': 2,
    'taskId': taskId,
    'inputSha256': inputSha256,
    'useStems': useStems,
    'controls': controls.map((id, value) => MapEntry(id, value.toJson())),
  };
  factory VideoMixSelection.fromJson(Map<String, Object?> json) {
    final controls = algorithmObject(json['controls']);
    if (!{1, 2}.contains(json['version']) ||
        json['useStems'] is! bool ||
        (json['version'] == 1 &&
            (controls.length != videoStemIds.length ||
                controls.keys.any((id) => !videoStemIds.contains(id))))) {
      throw const FormatException('视频分轨设置版本或音轨无效');
    }
    return VideoMixSelection(
      taskId: algorithmId(json['taskId']),
      inputSha256: algorithmText(json['inputSha256']),
      useStems: json['useStems'] as bool,
      controls: controls.map(
        (id, value) =>
            MapEntry(id, StemMixControl.fromJson(algorithmObject(value))),
      ),
    );
  }
}

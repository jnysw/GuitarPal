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
    Iterable<String>? selectedTrackIds,
  }) : controls = Map.unmodifiable(
         controls ??
             {for (final id in videoStemIds) id: const StemMixControl()},
       ),
       selectedTrackIds = selectedTrackIds == null
           ? null
           : Set.unmodifiable(selectedTrackIds) {
    algorithmId(taskId);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(inputSha256) ||
        this.controls.isEmpty ||
        this.controls.length > 16 ||
        ((this.selectedTrackIds ?? this.controls.keys).contains(
              'instrumental',
            ) &&
            (this.selectedTrackIds ?? this.controls.keys).any(
              (id) => !{'vocals', 'instrumental'}.contains(id),
            ))) {
      throw const FormatException('视频分轨设置无效');
    }
    if (selectedTrackIds != null &&
        (selectedTrackIds.isEmpty ||
            selectedTrackIds.length != this.selectedTrackIds!.length ||
            selectedTrackIds.any((id) => !this.controls.containsKey(id)))) {
      throw const FormatException('所选音轨与设置不一致');
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

  /// Null preserves the pre-v3 meaning: apply the manifest's default mix.
  final Set<String>? selectedTrackIds;
  Map<String, StemMixControl> get activeControls => selectedTrackIds == null
      ? controls
      : {for (final id in selectedTrackIds!) id: controls[id]!};
  Map<String, double> get gains {
    final active = activeControls;
    final anySolo = active.values.any((c) => c.solo);
    return active.map(
      (id, c) => MapEntry(id, c.muted || (anySolo && !c.solo) ? 0.0 : c.volume),
    );
  }

  Map<String, double> get pans =>
      activeControls.map((id, c) => MapEntry(id, c.pan));
  VideoMixSelection forTracks(
    Iterable<String> ids, {
    Iterable<String>? availableIds,
  }) => VideoMixSelection(
    taskId: taskId,
    inputSha256: inputSha256,
    useStems: useStems,
    controls: {
      for (final entry in controls.entries)
        if (availableIds == null || availableIds.contains(entry.key))
          entry.key: entry.value,
      for (final id in ids) id: controls[id] ?? const StemMixControl(),
    },
    selectedTrackIds: ids,
  );
  VideoMixSelection withMode(bool stems) => VideoMixSelection(
    taskId: taskId,
    inputSha256: inputSha256,
    useStems: stems,
    controls: controls,
    selectedTrackIds: selectedTrackIds,
  );
  Map<String, Object?> toJson() => {
    'version': 3,
    'taskId': taskId,
    'inputSha256': inputSha256,
    'useStems': useStems,
    'controls': controls.map((id, value) => MapEntry(id, value.toJson())),
    'selectedTrackIds': selectedTrackIds?.toList(),
  };
  factory VideoMixSelection.fromJson(Map<String, Object?> json) {
    final controls = algorithmObject(json['controls']);
    if (!{1, 2, 3}.contains(json['version']) ||
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
      selectedTrackIds: json['version'] == 3 && json['selectedTrackIds'] != null
          ? algorithmList(json['selectedTrackIds']).map(algorithmId).toList()
          : null,
    );
  }
}

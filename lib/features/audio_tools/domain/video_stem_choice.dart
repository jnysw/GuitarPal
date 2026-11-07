import 'legacy_algorithm_models.dart';

/// A playable subset of the manifest; derived sums cannot duplicate their sources.
List<LegacyStemFile> videoStemSubset(
  LegacySeparationResult result,
  Iterable<String> ids,
) {
  final values = ids.toList();
  final selected = values.toSet();
  if (selected.isEmpty ||
      selected.length != values.length ||
      selected.any((id) => !result.stems.any((s) => s.id == id))) {
    throw const FormatException('请选择结果中有效且不重复的音轨');
  }
  final stems = result.stems.where((s) => selected.contains(s.id)).toList();
  final backingPair =
      selected.length == 2 &&
      selected.contains('vocals') &&
      selected.contains('instrumental') &&
      stems.any((s) => s.id == 'vocals' && s.origin == 'model') &&
      stems.any((s) => s.id == 'instrumental' && s.origin == 'derived');
  if (stems.length > 1 &&
      stems.any((s) => s.origin == 'derived') &&
      !backingPair) {
    throw const FormatException('合成音轨请单独使用；人声可与合成伴奏一起使用');
  }
  return List.unmodifiable(stems);
}

Set<String> toggleVideoStem(
  LegacySeparationResult result,
  Set<String> current,
  String id,
) {
  final stem = result.stems.firstWhere(
    (s) => s.id == id,
    orElse: () => throw const FormatException('音轨不在当前清单中'),
  );
  final next = Set<String>.of(current);
  if (next.remove(id)) return next;
  if (stem.origin == 'derived') {
    final retainVocals =
        id == 'instrumental' &&
        next.contains('vocals') &&
        result.stems.any((s) => s.id == 'vocals' && s.origin == 'model');
    return {if (retainVocals) 'vocals', id};
  }
  next.removeWhere(
    (selected) => result.stems.any(
      (s) =>
          s.id == selected &&
          s.origin == 'derived' &&
          !(id == 'vocals' && selected == 'instrumental'),
    ),
  );
  next.add(id);
  videoStemSubset(result, next);
  return next;
}

class VideoStemLoadChoice {
  VideoStemLoadChoice(Iterable<String> ids, {this.localOnly = false})
    : ids = Set.unmodifiable(ids);
  final Set<String> ids;
  final bool localOnly;
}

class StemCacheStatus {
  const StemCacheStatus({required this.complete, required this.receivedBytes});
  final bool complete;

  /// Only complete or conditionally resumable bytes, never unsafe partial data.
  final int receivedBytes;
}

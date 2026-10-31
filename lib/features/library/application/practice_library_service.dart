import '../../../core/platform/local_video_gateway.dart';
import '../../../domain/practice_source/practice_source.dart';
import '../../../domain/practice_source/practice_source_repository.dart';
import '../../../media/metadata/source_metadata.dart';

class PracticeLibraryService {
  PracticeLibraryService(
    this._repository, {
    this.localVideoGateway,
    this.metadataLoader,
    this.deleteVideoMixPreferences,
    this.deletePerformancePreferences,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PracticeSourceRepository _repository;
  final LocalVideoGateway? localVideoGateway;
  final SourceMetadataLoader? metadataLoader;
  final Future<void> Function(String sourceId)? deleteVideoMixPreferences;
  final Future<void> Function(String sourceId)? deletePerformancePreferences;
  final DateTime Function() _clock;

  Future<void> rename(PracticeSource source, String requestedTitle) async {
    final title = requestedTitle.trim();
    if (title.isEmpty) {
      throw const FormatException('练习名称不能为空');
    }
    if (title.length > 300) {
      throw const FormatException('练习名称不能超过 300 个字符');
    }
    if (title == source.title) return;

    await _repository.save(
      source.copyWith(title: title, updatedAt: _clock().toUtc()),
    );
  }

  /// Stores media metadata discovered by a player after import.
  ///
  /// The latest source is fetched first so a delayed player callback cannot
  /// overwrite a rename or another concurrent edit with stale source data.
  Future<void> recordDuration(PracticeSource source, Duration duration) async {
    if (duration <= Duration.zero) return;

    final current = await _repository.getById(source.id);
    if (current == null || current.duration == duration) return;

    await _repository.save(
      current.copyWith(duration: duration, updatedAt: _clock().toUtc()),
    );
  }

  /// Updates the user's explicit learning state for a library source.
  ///
  /// This is intentionally independent from playback-session `completed`,
  /// which only means that one recording was finalized normally.
  Future<void> setCompleted(PracticeSource source, bool completed) async {
    final current = await _repository.getById(source.id);
    if (current == null || current.isCompleted == completed) return;

    final now = _clock().toUtc();
    await _repository.save(
      current.copyWith(completedAt: completed ? now : null, updatedAt: now),
    );
  }

  /// Stores an overall note for the source. Segment-specific notes remain on
  /// their respective A-B practice segments.
  Future<void> updateNote(PracticeSource source, String requestedNote) async {
    final normalized = requestedNote.trim();
    if (normalized.length > 4000) {
      throw const FormatException('曲目笔记不能超过 4000 个字符');
    }
    final note = normalized.isEmpty ? null : normalized;
    final current = await _repository.getById(source.id);
    if (current == null || current.note == note) return;

    await _repository.save(
      current.copyWith(note: note, updatedAt: _clock().toUtc()),
    );
  }

  /// Refreshes optional public preview information without overwriting a name
  /// the user has chosen. Placeholder adapter titles may be upgraded.
  Future<bool> refreshMetadata(PracticeSource source) async {
    final uri = source.canonicalUri;
    final loader = metadataLoader;
    if (uri == null ||
        loader == null ||
        source.platform == SourcePlatform.local) {
      return false;
    }

    final metadata = await loader.load(uri);
    if (metadata == null || metadata.isEmpty) return false;
    final current = await _repository.getById(source.id);
    if (current == null) return false;

    final refreshedTitle = _isPlaceholderTitle(current.title)
        ? metadata.title ?? current.title
        : current.title;
    final refreshedThumbnail = metadata.thumbnailUri ?? current.thumbnailUri;
    if (refreshedTitle == current.title &&
        refreshedThumbnail == current.thumbnailUri) {
      return false;
    }

    await _repository.save(
      current.copyWith(
        title: refreshedTitle,
        thumbnailUri: refreshedThumbnail,
        updatedAt: _clock().toUtc(),
      ),
    );
    return true;
  }

  Future<void> delete(PracticeSource source) async {
    await _repository.delete(source.id);
    try {
      await deleteVideoMixPreferences?.call(source.id);
    } on Object {
      // A settings cleanup failure must not undo a successful library deletion.
    }

    try {
      await deletePerformancePreferences?.call(source.id);
    } on Object {
      /* The deleted song stays deleted if local cleanup fails. */
    }

    final uri = source.canonicalUri;
    if (source.platform != SourcePlatform.local ||
        uri == null ||
        uri.scheme != 'file' ||
        localVideoGateway == null) {
      return;
    }

    try {
      await localVideoGateway!.deleteManagedVideo(uri.toFilePath());
    } on Object {
      // The database is the source of truth. A stale private file can be
      // reclaimed later without making a completed library deletion fail.
    }
  }

  bool _isPlaceholderTitle(String title) {
    return const {
      'YouTube 练习内容',
      'Bilibili 练习内容',
      '抖音练习内容',
      '小红书练习内容',
      '网页练习内容',
    }.contains(title);
  }
}

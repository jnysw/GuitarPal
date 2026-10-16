enum SourcePlatform {
  local,
  youtube,
  bilibili,
  douyin,
  xiaohongshu,
  genericWeb,
}

enum SourceKind { video, webReference, file }

class PracticeSource {
  static const Object _unchangedCompletedAt = Object();
  static const Object _unchangedThumbnailUri = Object();
  static const Object _unchangedNote = Object();

  const PracticeSource({
    required this.id,
    required this.platform,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.originalUri,
    this.canonicalUri,
    this.externalId,
    this.thumbnailUri,
    this.duration,
    this.note,
    this.completedAt,
  });

  final String id;
  final SourcePlatform platform;
  final SourceKind kind;
  final Uri? originalUri;
  final Uri? canonicalUri;
  final String? externalId;
  final String title;
  final Uri? thumbnailUri;
  final Duration? duration;
  final String? note;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => completedAt != null;

  PracticeSource copyWith({
    String? title,
    Duration? duration,
    Object? thumbnailUri = _unchangedThumbnailUri,
    Object? note = _unchangedNote,
    Object? completedAt = _unchangedCompletedAt,
    DateTime? updatedAt,
  }) {
    if (!identical(completedAt, _unchangedCompletedAt) &&
        completedAt != null &&
        completedAt is! DateTime) {
      throw ArgumentError.value(
        completedAt,
        'completedAt',
        'must be a DateTime or null',
      );
    }
    if (!identical(thumbnailUri, _unchangedThumbnailUri) &&
        thumbnailUri != null &&
        thumbnailUri is! Uri) {
      throw ArgumentError.value(
        thumbnailUri,
        'thumbnailUri',
        'must be a Uri or null',
      );
    }
    if (!identical(note, _unchangedNote) && note != null && note is! String) {
      throw ArgumentError.value(note, 'note', 'must be a String or null');
    }
    return PracticeSource(
      id: id,
      platform: platform,
      kind: kind,
      originalUri: originalUri,
      canonicalUri: canonicalUri,
      externalId: externalId,
      title: title ?? this.title,
      thumbnailUri: identical(thumbnailUri, _unchangedThumbnailUri)
          ? this.thumbnailUri
          : thumbnailUri as Uri?,
      duration: duration ?? this.duration,
      note: identical(note, _unchangedNote) ? this.note : note as String?,
      completedAt: identical(completedAt, _unchangedCompletedAt)
          ? this.completedAt
          : completedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

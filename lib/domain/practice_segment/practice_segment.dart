class PracticeSegment {
  static const Object _unchangedNote = Object();

  PracticeSegment({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.start,
    required this.end,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.preferredSpeed = 1.0,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (start.isNegative) {
      throw ArgumentError.value(start, 'start', 'must not be negative');
    }
    if (end <= start) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
    if (!preferredSpeed.isFinite ||
        preferredSpeed < 0.5 ||
        preferredSpeed > 2.0) {
      throw ArgumentError.value(
        preferredSpeed,
        'preferredSpeed',
        'must be between 0.5 and 2.0',
      );
    }
  }

  final String id;
  final String sourceId;
  final String title;
  final Duration start;
  final Duration end;
  final String? note;
  final double preferredSpeed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => end - start;

  PracticeSegment copyWith({
    String? title,
    Duration? start,
    Duration? end,
    Object? note = _unchangedNote,
    double? preferredSpeed,
    DateTime? updatedAt,
  }) {
    if (!identical(note, _unchangedNote) && note != null && note is! String) {
      throw ArgumentError.value(note, 'note', 'must be a String or null');
    }

    return PracticeSegment(
      id: id,
      sourceId: sourceId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      note: identical(note, _unchangedNote) ? this.note : note as String?,
      preferredSpeed: preferredSpeed ?? this.preferredSpeed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

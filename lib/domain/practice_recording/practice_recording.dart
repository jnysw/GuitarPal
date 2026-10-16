enum PracticeRecordingKind { segmentTake, planOutcome }

class PracticeRecording {
  static const Object _unchangedPlanId = Object();
  static const Object _unchangedSessionId = Object();
  static const Object _unchangedSegmentId = Object();
  static const Object _unchangedReferenceEnd = Object();
  static const Object _unchangedNote = Object();

  PracticeRecording({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.filePath,
    required this.duration,
    required this.referenceStart,
    required this.referenceSpeed,
    required this.title,
    required this.recordedAt,
    this.planId,
    this.sessionId,
    this.segmentId,
    this.referenceEnd,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (!_isSafeRelativePath(filePath)) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'must be a safe relative path',
      );
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    if (referenceStart.isNegative) {
      throw ArgumentError.value(
        referenceStart,
        'referenceStart',
        'must not be negative',
      );
    }
    if (referenceEnd != null && referenceEnd! <= referenceStart) {
      throw ArgumentError.value(
        referenceEnd,
        'referenceEnd',
        'must follow referenceStart',
      );
    }
    if (!referenceSpeed.isFinite ||
        referenceSpeed < 0.5 ||
        referenceSpeed > 2.0) {
      throw ArgumentError.value(
        referenceSpeed,
        'referenceSpeed',
        'must be between 0.5 and 2.0',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (kind == PracticeRecordingKind.planOutcome &&
        (planId == null || planId!.trim().isEmpty)) {
      throw ArgumentError.value(
        planId,
        'planId',
        'is required for a plan outcome',
      );
    }
  }

  final String id;
  final String sourceId;
  final String? segmentId;
  final String? planId;
  final String? sessionId;
  final PracticeRecordingKind kind;
  final String filePath;
  final Duration duration;
  final Duration referenceStart;
  final Duration? referenceEnd;
  final double referenceSpeed;
  final String title;
  final String? note;
  final DateTime recordedAt;

  PracticeRecording copyWith({
    Object? segmentId = _unchangedSegmentId,
    Object? planId = _unchangedPlanId,
    Object? sessionId = _unchangedSessionId,
    PracticeRecordingKind? kind,
    Duration? duration,
    Duration? referenceStart,
    Object? referenceEnd = _unchangedReferenceEnd,
    double? referenceSpeed,
    String? title,
    Object? note = _unchangedNote,
  }) {
    return PracticeRecording(
      id: id,
      sourceId: sourceId,
      segmentId: identical(segmentId, _unchangedSegmentId)
          ? this.segmentId
          : segmentId as String?,
      planId: identical(planId, _unchangedPlanId)
          ? this.planId
          : planId as String?,
      sessionId: identical(sessionId, _unchangedSessionId)
          ? this.sessionId
          : sessionId as String?,
      kind: kind ?? this.kind,
      filePath: filePath,
      duration: duration ?? this.duration,
      referenceStart: referenceStart ?? this.referenceStart,
      referenceEnd: identical(referenceEnd, _unchangedReferenceEnd)
          ? this.referenceEnd
          : referenceEnd as Duration?,
      referenceSpeed: referenceSpeed ?? this.referenceSpeed,
      title: title ?? this.title,
      note: identical(note, _unchangedNote) ? this.note : note as String?,
      recordedAt: recordedAt,
    );
  }

  static bool _isSafeRelativePath(String value) {
    final normalized = value.trim().replaceAll('\\', '/');
    return normalized.isNotEmpty &&
        !normalized.startsWith('/') &&
        !RegExp(r'^[A-Za-z]:/').hasMatch(normalized) &&
        !normalized.split('/').contains('..');
  }
}

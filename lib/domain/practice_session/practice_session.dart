import '../practice_plan/calendar_date.dart';

class PracticeSession {
  PracticeSession({
    required this.id,
    required this.sourceId,
    required this.practiceDate,
    required this.startedAt,
    required this.activeDuration,
    required this.loopCount,
    required this.completed,
    this.planId,
    this.segmentId,
    this.endedAt,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (activeDuration.isNegative) {
      throw ArgumentError.value(
        activeDuration,
        'activeDuration',
        'must not be negative',
      );
    }
    if (loopCount < 0) {
      throw ArgumentError.value(loopCount, 'loopCount', 'must not be negative');
    }
    if (endedAt != null && endedAt!.isBefore(startedAt)) {
      throw ArgumentError.value(endedAt, 'endedAt', 'must follow startedAt');
    }
  }

  final String id;
  final String? planId;
  final String sourceId;
  final String? segmentId;
  final CalendarDate practiceDate;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration activeDuration;
  final int loopCount;

  /// Whether this session was finalized by a normal player shutdown.
  ///
  /// A `false` value represents the latest recovery checkpoint of a session
  /// that may still be in progress, or whose process was stopped before it
  /// could be finalized. It does not make the already persisted practice
  /// activity invalid. Use [hasPracticeActivity] when deciding whether a
  /// session contributes to practice progress.
  final bool completed;

  bool get hasPracticeActivity {
    return activeDuration > Duration.zero || loopCount > 0;
  }
}

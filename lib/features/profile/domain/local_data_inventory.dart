import '../../../domain/practice_plan/practice_plan.dart';
import '../../../domain/practice_recording/practice_recording.dart';
import '../../../domain/practice_segment/practice_segment.dart';
import '../../../domain/practice_session/practice_session.dart';
import '../../../domain/practice_source/practice_source.dart';

class LocalDataInventory {
  const LocalDataInventory({
    required this.sourceCount,
    required this.segmentCount,
    required this.planCount,
    required this.sessionCount,
    required this.recordingCount,
    required this.noteCount,
    required this.recordingDuration,
  });

  factory LocalDataInventory.calculate({
    required Iterable<PracticeSource> sources,
    required Iterable<PracticeSegment> segments,
    required Iterable<PracticePlan> plans,
    required Iterable<PracticeSession> sessions,
    required Iterable<PracticeRecording> recordings,
  }) {
    final sourceValues = sources.toList(growable: false);
    final segmentValues = segments.toList(growable: false);
    final planValues = plans.toList(growable: false);
    final sessionValues = sessions.toList(growable: false);
    final recordingValues = recordings.toList(growable: false);
    return LocalDataInventory(
      sourceCount: sourceValues.length,
      segmentCount: segmentValues.length,
      planCount: planValues.length,
      sessionCount: sessionValues.length,
      recordingCount: recordingValues.length,
      noteCount:
          sourceValues.where((source) => _hasText(source.note)).length +
          segmentValues.where((segment) => _hasText(segment.note)).length +
          recordingValues.where((recording) => _hasText(recording.note)).length,
      recordingDuration: recordingValues.fold(
        Duration.zero,
        (total, recording) => total + recording.duration,
      ),
    );
  }

  final int sourceCount;
  final int segmentCount;
  final int planCount;
  final int sessionCount;
  final int recordingCount;
  final int noteCount;
  final Duration recordingDuration;

  int get metadataItemCount =>
      sourceCount + segmentCount + planCount + sessionCount;

  bool get isEmpty => metadataItemCount == 0 && recordingCount == 0;
}

bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

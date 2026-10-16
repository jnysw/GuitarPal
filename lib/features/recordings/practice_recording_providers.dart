import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/platform/practice_audio_analyzer.dart';
import '../../core/platform/practice_audio_recorder.dart';
import '../../domain/practice_recording/practice_recording.dart';
import '../../domain/practice_recording/practice_recording_repository.dart';
import 'data/drift_practice_recording_repository.dart';

final practiceAudioRecorderProvider = Provider<PracticeAudioRecorder>((ref) {
  return const MethodChannelPracticeAudioRecorder();
});

final practiceAudioAnalyzerProvider = Provider<PracticeAudioAnalyzer>((ref) {
  return const MethodChannelPracticeAudioAnalyzer();
});

final practiceRecordingRepositoryProvider =
    Provider<PracticeRecordingRepository>((ref) {
      return DriftPracticeRecordingRepository(ref.watch(databaseProvider));
    });

final practiceRecordingsProvider = StreamProvider<List<PracticeRecording>>((
  ref,
) {
  return ref.watch(practiceRecordingRepositoryProvider).watchAll();
});

final practiceRecordingsForSourceProvider = StreamProvider.autoDispose
    .family<List<PracticeRecording>, String>((ref, sourceId) {
      return ref
          .watch(practiceRecordingRepositoryProvider)
          .watchBySource(sourceId);
    });

final practiceRecordingsForPlanProvider = StreamProvider.autoDispose
    .family<List<PracticeRecording>, String>((ref, planId) {
      return ref.watch(practiceRecordingRepositoryProvider).watchByPlan(planId);
    });

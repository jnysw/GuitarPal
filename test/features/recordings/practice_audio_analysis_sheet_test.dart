import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_analyzer.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/recordings/presentation/practice_audio_analysis_sheet.dart';

void main() {
  testWidgets(
    'labels an insufficient rhythm sample without inventing a score',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            practiceAudioAnalyzerProvider.overrideWithValue(
              const _FixedAnalyzer(
                PracticeAudioAnalysis(
                  duration: Duration(seconds: 2),
                  waveform: [0.0, 0.2, 0.5, 0.1],
                  averageLoudnessDbfs: -30,
                  peakLevelDbfs: -8,
                  silenceRatio: 0.65,
                  onsetCount: 2,
                  sampleRate: 44100,
                  channelCount: 1,
                  algorithmVersion: 'energy-onset-v1',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PracticeAudioAnalysisSheet(recording: _recording()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('实验音频分析'), findsOneWidget);
      expect(
        find.byKey(const Key('practice_audio_analysis_waveform')),
        findsOneWidget,
      );
      expect(find.textContaining('不是演奏评分'), findsOneWidget);
      expect(
        find.byKey(const Key('analysis_rhythm_insufficient')),
        findsOneWidget,
      );
      expect(find.textContaining('得分'), findsNothing);
    },
  );
}

PracticeRecording _recording() {
  return PracticeRecording(
    id: 'take-1',
    sourceId: 'source-1',
    kind: PracticeRecordingKind.segmentTake,
    filePath: 'practice_recordings/take-1.m4a',
    duration: const Duration(seconds: 2),
    referenceStart: Duration.zero,
    referenceSpeed: 1,
    title: '测试录音',
    recordedAt: DateTime.utc(2026, 10, 15),
  );
}

class _FixedAnalyzer implements PracticeAudioAnalyzer {
  const _FixedAnalyzer(this.analysis);

  final PracticeAudioAnalysis analysis;

  @override
  Future<PracticeAudioAnalysis> analyzeRecording(String relativePath) async {
    return analysis;
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_analyzer.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records, commits, resolves, and deletes a private M4A file', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;

    const recorder = MethodChannelPracticeAudioRecorder();
    const analyzer = MethodChannelPracticeAudioAnalyzer();
    String? committedRelativePath;
    addTearDown(() async {
      if (await recorder.isRecording()) await recorder.cancel();
      final path = committedRelativePath;
      if (path != null) {
        await recorder.deleteRecording(path);
      }
    });

    expect(
      await recorder.permissionStatus(),
      MicrophonePermissionStatus.granted,
      reason: 'Grant RECORD_AUDIO to the integration-test app before running.',
    );

    final recordingId = 'integration_${DateTime.now().microsecondsSinceEpoch}';
    await recorder.start(recordingId: recordingId);
    expect(await recorder.isRecording(), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final result = await recorder.stop();
    committedRelativePath = result.relativePath;

    expect(result.relativePath, 'practice_recordings/$recordingId.m4a');
    expect(result.duration, greaterThan(const Duration(seconds: 1)));
    expect(File(result.absolutePath).lengthSync(), greaterThan(0));
    final resolvedPath = await recorder.resolveAbsolutePath(
      result.relativePath,
    );
    expect(File(resolvedPath).existsSync(), isTrue);
    expect(
      File(resolvedPath).resolveSymbolicLinksSync(),
      File(result.absolutePath).resolveSymbolicLinksSync(),
    );

    final analysis = await analyzer.analyzeRecording(result.relativePath);
    expect(analysis.duration, greaterThan(const Duration(seconds: 1)));
    expect(analysis.waveform, isNotEmpty);
    expect(
      analysis.waveform.every((value) => value >= 0 && value <= 1),
      isTrue,
    );
    expect(analysis.sampleRate, greaterThan(0));
    expect(analysis.channelCount, greaterThan(0));
    expect(analysis.averageLoudnessDbfs, inInclusiveRange(-120, 0));
    expect(analysis.peakLevelDbfs, inInclusiveRange(-120, 0));
    expect(analysis.silenceRatio, inInclusiveRange(0, 1));
    expect(analysis.algorithmVersion, 'energy-onset-v1');

    await recorder.playRecording(result.relativePath);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final playback = await recorder.playbackSnapshot();
    expect(playback.isLoaded, isTrue);
    expect(playback.duration, greaterThan(Duration.zero));
    await recorder.seekPlayback(const Duration(milliseconds: 500));
    await recorder.pausePlayback();
    await recorder.stopPlayback();

    await recorder.deleteRecording(result.relativePath);
    committedRelativePath = null;
    expect(File(result.absolutePath).existsSync(), isFalse);
  });
}

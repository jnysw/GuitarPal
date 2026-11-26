import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/features/performance/data/performance_audio_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const mic = MethodChannelPracticeAudioRecorder();
  const extra = PerformanceAudioPlatform();
  testWidgets(
    'native performance capture records timing environment and committed audio supports quiet playback and recovery',
    (tester) async {
      final id =
          'integration_performance_${DateTime.now().microsecondsSinceEpoch}';
      String? path = 'practice_recordings/$id.m4a';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('原生录音验证'))),
      );
      await tester.pumpAndSettle();
      try {
        expect(
          await mic.permissionStatus(),
          MicrophonePermissionStatus.granted,
        );
        final env = await extra.environment();
        expect(env['freeBytes'] as num, greaterThan(64 * 1024 * 1024));
        expect(env['actualRouteVerified'], isFalse);
        final started = await extra.start(id);
        expect(
          started['startedAtElapsedMs'] as num,
          greaterThanOrEqualTo(env['elapsedRealtimeMs'] as num),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1300));
        final result = await mic.stop();
        path = result.relativePath;
        expect(result.duration.inMilliseconds, greaterThan(1000));
        expect(File(result.absolutePath).lengthSync(), greaterThan(0));
        final recovered = await extra.recover(id);
        expect(recovered.duration, result.duration);
        await extra.play(path, 0, 0);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect((await mic.playbackSnapshot()).isPlaying, isTrue);
        await extra.setVolume(.25);
        await mic.pausePlayback();
        expect((await mic.playbackSnapshot()).isPlaying, isFalse);
      } finally {
        await mic.stopPlayback();
        if (await mic.isRecording()) await mic.cancel();
        if (path != null) await mic.deleteRecording(path);
      }
    },
  );
  testWidgets(
    'native onStop commits a performance take for recovery instead of deleting it',
    (tester) async {
      final id =
          'integration_background_${DateTime.now().microsecondsSinceEpoch}';
      String? path = 'practice_recordings/$id.m4a';
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('原生录音验证'))),
      );
      await tester.pumpAndSettle();
      try {
        await extra.start(id);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        debugPrint('PERFORMANCE_NATIVE_BACKGROUND_READY');
        // Host validation sends HOME and restores MainActivity during this window.
        await Future<void>.delayed(const Duration(seconds: 4));
        expect(await mic.isRecording(), isFalse);
        final result = await extra.recover(id);
        path = result.relativePath;
        expect(result.duration.inMilliseconds, greaterThan(1000));
        expect(File(result.absolutePath).lengthSync(), greaterThan(0));
      } finally {
        if (await mic.isRecording()) await mic.cancel();
        if (path != null) await mic.deleteRecording(path);
      }
    },
    skip: !const bool.fromEnvironment('CHECK_NATIVE_CAPTURE_BACKGROUND'),
  );
}

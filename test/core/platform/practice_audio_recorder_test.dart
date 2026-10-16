import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guitarpal/practice_audio_recording_test');
  const recorder = MethodChannelPracticeAudioRecorder(channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes permission states and sends the recording id', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'permissionStatus' => 'denied',
            'requestPermission' => 'granted',
            'start' => null,
            _ => null,
          };
        });

    expect(
      await recorder.permissionStatus(),
      MicrophonePermissionStatus.denied,
    );
    expect(
      await recorder.requestPermission(),
      MicrophonePermissionStatus.granted,
    );
    await recorder.start(recordingId: 'take-123');

    expect(calls.last.method, 'start');
    expect(calls.last.arguments, {'recordingId': 'take-123'});
  });

  test('decodes the committed M4A result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'stop');
          return <String, Object?>{
            'relativePath': 'practice_recordings/take-123.m4a',
            'absolutePath': '/app/files/practice_recordings/take-123.m4a',
            'durationMilliseconds': 4321,
          };
        });

    final result = await recorder.stop();

    expect(result.relativePath, 'practice_recordings/take-123.m4a');
    expect(result.absolutePath, endsWith('/take-123.m4a'));
    expect(result.duration, const Duration(milliseconds: 4321));
  });

  test('rejects incomplete native recording results', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{'durationMilliseconds': 0};
        });

    await expectLater(recorder.stop(), throwsFormatException);
  });

  test('controls recording playback and decodes its snapshot', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'playbackSnapshot') {
            return <String, Object?>{
              'isLoaded': true,
              'isPlaying': true,
              'positionMilliseconds': 1250,
              'durationMilliseconds': 4321,
            };
          }
          return null;
        });

    await recorder.playRecording(
      'practice_recordings/take-123.m4a',
      position: const Duration(milliseconds: 500),
    );
    await recorder.seekPlayback(const Duration(milliseconds: 900));
    await recorder.pausePlayback();
    final snapshot = await recorder.playbackSnapshot();
    await recorder.stopPlayback();

    expect(calls.first.method, 'playRecording');
    expect(calls.first.arguments, {
      'relativePath': 'practice_recordings/take-123.m4a',
      'positionMilliseconds': 500,
    });
    expect(calls[1].method, 'seekPlayback');
    expect(calls[1].arguments, {'positionMilliseconds': 900});
    expect(snapshot.isLoaded, isTrue);
    expect(snapshot.isPlaying, isTrue);
    expect(snapshot.position, const Duration(milliseconds: 1250));
    expect(snapshot.duration, const Duration(milliseconds: 4321));
    expect(calls.last.method, 'stopPlayback');
  });

  test('rejects malformed recording playback snapshots', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{'isLoaded': true};
        });

    await expectLater(recorder.playbackSnapshot(), throwsFormatException);
  });
}

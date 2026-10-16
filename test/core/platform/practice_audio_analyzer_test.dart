import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guitarpal/practice_audio_analysis_test');
  const analyzer = MethodChannelPracticeAudioAnalyzer(channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests and decodes a native recording analysis', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return <String, Object?>{
            'durationMilliseconds': 4321,
            'waveform': <double>[0.1, 0.4, 0.8],
            'averageLoudnessDbfs': -21.5,
            'peakLevelDbfs': -3.2,
            'silenceRatio': 0.12,
            'onsetCount': 8,
            'medianOnsetIntervalMilliseconds': 480,
            'onsetIntervalVariation': 0.08,
            'sampleRate': 44100,
            'channelCount': 1,
            'algorithmVersion': 'energy-onset-v1',
          };
        });

    final result = await analyzer.analyzeRecording(
      'practice_recordings/take-123.m4a',
    );

    expect(received?.method, 'analyzeRecording');
    expect(received?.arguments, {
      'relativePath': 'practice_recordings/take-123.m4a',
    });
    expect(result.duration, const Duration(milliseconds: 4321));
    expect(result.waveform, [0.1, 0.4, 0.8]);
    expect(result.averageLoudnessDbfs, -21.5);
    expect(result.peakLevelDbfs, -3.2);
    expect(result.silenceRatio, 0.12);
    expect(result.onsetCount, 8);
    expect(result.medianOnsetInterval, const Duration(milliseconds: 480));
    expect(result.onsetIntervalVariation, 0.08);
    expect(result.hasRhythmEstimate, isTrue);
  });

  test('keeps an insufficient onset result explicitly inconclusive', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'durationMilliseconds': 2000,
            'waveform': <double>[0, 0.2],
            'averageLoudnessDbfs': -35,
            'peakLevelDbfs': -12,
            'silenceRatio': 0.7,
            'onsetCount': 2,
            'medianOnsetIntervalMilliseconds': null,
            'onsetIntervalVariation': null,
            'sampleRate': 44100,
            'channelCount': 1,
            'algorithmVersion': 'energy-onset-v1',
          };
        });

    final result = await analyzer.analyzeRecording(
      'practice_recordings/quiet.m4a',
    );

    expect(result.hasRhythmEstimate, isFalse);
    expect(result.medianOnsetInterval, isNull);
  });

  test('rejects malformed or out-of-range native values', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'durationMilliseconds': 1000,
            'waveform': <double>[1.2],
            'averageLoudnessDbfs': -20,
            'peakLevelDbfs': -2,
            'silenceRatio': 0.1,
            'onsetCount': 1,
            'sampleRate': 44100,
            'channelCount': 1,
            'algorithmVersion': 'energy-onset-v1',
          };
        });

    await expectLater(
      analyzer.analyzeRecording('practice_recordings/bad.m4a'),
      throwsFormatException,
    );
  });
}

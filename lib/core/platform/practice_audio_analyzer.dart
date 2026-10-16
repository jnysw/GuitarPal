import 'package:flutter/services.dart';

class PracticeAudioAnalysis {
  const PracticeAudioAnalysis({
    required this.duration,
    required this.waveform,
    required this.averageLoudnessDbfs,
    required this.peakLevelDbfs,
    required this.silenceRatio,
    required this.onsetCount,
    required this.sampleRate,
    required this.channelCount,
    required this.algorithmVersion,
    this.medianOnsetInterval,
    this.onsetIntervalVariation,
  });

  final Duration duration;
  final List<double> waveform;
  final double averageLoudnessDbfs;
  final double peakLevelDbfs;
  final double silenceRatio;
  final int onsetCount;
  final Duration? medianOnsetInterval;
  final double? onsetIntervalVariation;
  final int sampleRate;
  final int channelCount;
  final String algorithmVersion;

  bool get hasRhythmEstimate =>
      onsetCount >= 4 &&
      medianOnsetInterval != null &&
      onsetIntervalVariation != null;
}

abstract interface class PracticeAudioAnalyzer {
  Future<PracticeAudioAnalysis> analyzeRecording(String relativePath);
}

class MethodChannelPracticeAudioAnalyzer implements PracticeAudioAnalyzer {
  const MethodChannelPracticeAudioAnalyzer([
    this._channel = const MethodChannel(
      'com.guitarpal/practice_audio_recording',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<PracticeAudioAnalysis> analyzeRecording(String relativePath) async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'analyzeRecording',
      {'relativePath': relativePath},
    );
    if (value == null) {
      throw const FormatException('没有收到音频分析结果');
    }

    final durationMilliseconds = _integer(value['durationMilliseconds']);
    final waveformValue = value['waveform'];
    final averageLoudnessDbfs = _number(value['averageLoudnessDbfs']);
    final peakLevelDbfs = _number(value['peakLevelDbfs']);
    final silenceRatio = _number(value['silenceRatio']);
    final onsetCount = _integer(value['onsetCount']);
    final sampleRate = _integer(value['sampleRate']);
    final channelCount = _integer(value['channelCount']);
    final algorithmVersion = value['algorithmVersion'];

    if (durationMilliseconds == null ||
        durationMilliseconds <= 0 ||
        waveformValue is! List ||
        waveformValue.isEmpty ||
        averageLoudnessDbfs == null ||
        peakLevelDbfs == null ||
        silenceRatio == null ||
        onsetCount == null ||
        onsetCount < 0 ||
        sampleRate == null ||
        sampleRate <= 0 ||
        channelCount == null ||
        channelCount <= 0 ||
        algorithmVersion is! String ||
        algorithmVersion.isEmpty) {
      throw const FormatException('音频分析结果不完整');
    }

    final waveform = waveformValue
        .map(_number)
        .whereType<double>()
        .toList(growable: false);
    if (waveform.length != waveformValue.length ||
        waveform.any((value) => !value.isFinite || value < 0 || value > 1) ||
        !averageLoudnessDbfs.isFinite ||
        !peakLevelDbfs.isFinite ||
        !silenceRatio.isFinite ||
        silenceRatio < 0 ||
        silenceRatio > 1) {
      throw const FormatException('音频分析结果包含无效数值');
    }

    final medianMilliseconds = _integer(
      value['medianOnsetIntervalMilliseconds'],
    );
    final intervalVariation = _number(value['onsetIntervalVariation']);
    if ((medianMilliseconds != null && medianMilliseconds <= 0) ||
        (intervalVariation != null &&
            (!intervalVariation.isFinite || intervalVariation < 0))) {
      throw const FormatException('音频节奏分析结果包含无效数值');
    }
    return PracticeAudioAnalysis(
      duration: Duration(milliseconds: durationMilliseconds),
      waveform: waveform,
      averageLoudnessDbfs: averageLoudnessDbfs,
      peakLevelDbfs: peakLevelDbfs,
      silenceRatio: silenceRatio,
      onsetCount: onsetCount,
      medianOnsetInterval: medianMilliseconds == null
          ? null
          : Duration(milliseconds: medianMilliseconds),
      onsetIntervalVariation: intervalVariation,
      sampleRate: sampleRate,
      channelCount: channelCount,
      algorithmVersion: algorithmVersion,
    );
  }

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;

  static int? _integer(Object? value) => value is num ? value.toInt() : null;
}

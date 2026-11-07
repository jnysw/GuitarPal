/// Exact resampled-input coordinates supplied by the chord service, never guessed.
class ChordTimeline {
  ChordTimeline.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 ||
        json['coordinate_system'] != 'trimmed_input_seconds') {
      throw const FormatException('和弦时间映射版本不支持');
    }
    int integer(String key) {
      final v = json[key];
      if (v is! num || !v.isFinite || v.toInt() != v) {
        throw const FormatException('和弦采样坐标无效');
      }
      return v.toInt();
    }

    sampleRate = integer('sample_rate_hz');
    inputSamples = integer('input_sample_count');
    startSample = integer('analysis_start_sample');
    analysisSamples = integer('analysis_sample_count');
    hopSamples = integer('frame_hop_samples');
    if (sampleRate < 8000 ||
        sampleRate > 192000 ||
        inputSamples <= 0 ||
        inputSamples > sampleRate * 601 ||
        startSample < 0 ||
        analysisSamples <= 0 ||
        startSample + analysisSamples > inputSamples ||
        hopSamples <= 0 ||
        hopSamples > sampleRate) {
      throw const FormatException('和弦采样映射越界');
    }
  }
  late final int sampleRate,
      inputSamples,
      startSample,
      analysisSamples,
      hopSamples;
  Duration _time(int samples) =>
      Duration(microseconds: (samples * 1000000 / sampleRate).round());
  Duration get inputDuration => _time(inputSamples);
  Duration get offset => _time(startSample);
  Duration get analysisDuration => _time(analysisSamples);
  int get offsetMs => (startSample * 1000 / sampleRate).round();
}

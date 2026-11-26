/// Millisecond coordinates for one immutable, already extracted audio input.
/// Playback speed never changes these content coordinates.
class AudioTimeMapping {
  AudioTimeMapping({
    required this.sourceOffsetMs,
    required this.inputDurationMs,
    this.sourceDurationMs,
    this.trimStartMs = 0,
    this.userAlignmentMs = 0,
  }) {
    if (sourceOffsetMs < 0 ||
        inputDurationMs < 2000 ||
        inputDurationMs > 600000) {
      throw const FormatException('分析区间必须为 2 秒至 10 分钟，且起点不能为负');
    }
    if (sourceDurationMs != null &&
        sourceOffsetMs + inputDurationMs > sourceDurationMs!) {
      throw const FormatException('分析区间超出来源时长');
    }
    if (trimStartMs != 0) {
      throw const FormatException('v1 分析必须保留首尾静音，禁止隐式裁剪');
    }
  }

  final int sourceOffsetMs;
  final int inputDurationMs;
  final int? sourceDurationMs;
  final int trimStartMs;
  final int userAlignmentMs;

  int get coverageEndMs => sourceOffsetMs + inputDurationMs;

  int inputToSource(int inputMs) {
    if (inputMs < 0 || inputMs > inputDurationMs) {
      throw const FormatException('输入时间超出分析区间');
    }
    return sourceOffsetMs + inputMs;
  }

  /// Alignment belongs only to display; it never rewrites machine segments.
  int sourceToDisplay(int sourceMs) {
    final displayMs = sourceMs + userAlignmentMs;
    if (displayMs < 0 ||
        (sourceDurationMs != null && displayMs > sourceDurationMs!)) {
      throw const FormatException('人工校准后的时间超出来源范围');
    }
    return displayMs;
  }

  /// Round once at the PCM boundary, with integer half-up rounding.
  static int samplesToMilliseconds(int samples, int sampleRate) {
    if (samples < 0 || sampleRate <= 0) {
      throw const FormatException('样本数或采样率无效');
    }
    return (samples * 1000 + sampleRate ~/ 2) ~/ sampleRate;
  }
}

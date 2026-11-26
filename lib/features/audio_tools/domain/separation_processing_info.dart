/// Optional server timings. They describe computation, not upload/download time.
class SeparationProcessingInfo {
  const SeparationProcessingInfo({
    this.queue,
    this.preparing,
    this.loading,
    this.inference,
    this.encoding,
    this.publishing,
    this.processing,
    this.gpu,
  });
  final Duration? queue,
      preparing,
      loading,
      inference,
      encoding,
      publishing,
      processing;
  final bool? gpu;

  static SeparationProcessingInfo? fromResult(Map<String, Object?> result) {
    final value = result['diagnostics'];
    final data = value is Map ? value : const <String, Object?>{};
    Duration? ms(Object? n) => n is num && n.isFinite && n >= 0 && n <= 86400000
        ? Duration(microseconds: (n * 1000).round())
        : null;
    final fallback = result['processing_time_seconds'];
    final info = SeparationProcessingInfo(
      queue: ms(data['queue_ms']),
      preparing: ms(data['decode_resample_ms']),
      loading: ms(data['model_load_ms']),
      inference: ms(data['inference_ms']),
      encoding: ms(data['encode_ms']),
      publishing: ms(data['publish_ms']),
      processing:
          ms(data['worker_total_ms']) ??
          ms(fallback is num ? fallback * 1000 : null),
      gpu: data['device'] == 'cpu'
          ? false
          : data['device'] is String &&
                RegExp(r'^cuda(?::\d+)?$').hasMatch(data['device'] as String)
          ? true
          : null,
    );
    return [
          info.queue,
          info.preparing,
          info.loading,
          info.inference,
          info.encoding,
          info.publishing,
          info.processing,
        ].any((d) => d != null)
        ? info
        : null;
  }
}

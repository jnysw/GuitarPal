enum AlgorithmTaskState {
  submitting,
  submissionUnknown,
  queued,
  processing,
  completed,
  failed,
  unavailable,
  lost,
  invalidResult,
}

class AlgorithmTaskRecord {
  const AlgorithmTaskRecord({
    required this.id,
    required this.endpoint,
    required this.inputPath,
    required this.inputName,
    required this.inputSizeBytes,
    required this.inputDurationMs,
    required this.ownsInput,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    required this.failures,
    this.recordingId,
    this.remoteJobId,
    this.progress,
    this.message,
    this.resultJson,
    this.nextPollAt,
  });

  final String id;
  final String endpoint;
  final String inputPath;
  final String inputName;
  final int inputSizeBytes;
  final int inputDurationMs;
  final bool ownsInput;
  final String? recordingId;
  final AlgorithmTaskState state;
  final String? remoteJobId;
  final int? progress;
  final String? message;
  final String? resultJson;
  final int failures;
  final DateTime? nextPollAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get shouldPoll =>
      remoteJobId != null &&
      {
        AlgorithmTaskState.queued,
        AlgorithmTaskState.processing,
        AlgorithmTaskState.unavailable,
      }.contains(state);
}

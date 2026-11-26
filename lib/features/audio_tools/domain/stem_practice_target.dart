class StemPracticeTarget {
  const StemPracticeTarget({
    required this.sourceId,
    required this.sourceTitle,
    this.planId,
    this.planName,
  });
  final String sourceId;
  final String sourceTitle;
  final String? planId;
  final String? planName;
  String get label =>
      planName == null ? sourceTitle : '$sourceTitle · $planName';
}

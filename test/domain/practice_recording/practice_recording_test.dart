import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';

void main() {
  test('stores the reference snapshot for a segment take', () {
    final recording = _recording();

    expect(recording.kind, PracticeRecordingKind.segmentTake);
    expect(recording.referenceStart, const Duration(seconds: 12));
    expect(recording.referenceEnd, const Duration(seconds: 20));
    expect(recording.referenceSpeed, 0.83);
  });

  test('plan outcomes require a plan and can be promoted from a take', () {
    expect(
      () => _recording(kind: PracticeRecordingKind.planOutcome),
      throwsArgumentError,
    );

    final outcome = _recording().copyWith(
      kind: PracticeRecordingKind.planOutcome,
      planId: 'plan-1',
    );
    expect(outcome.kind, PracticeRecordingKind.planOutcome);
    expect(outcome.planId, 'plan-1');
  });

  test('rejects unsafe file paths and invalid reference ranges', () {
    expect(() => _recording(filePath: '/tmp/take.m4a'), throwsArgumentError);
    expect(
      () => _recording(filePath: '../practice_recordings/take.m4a'),
      throwsArgumentError,
    );
    expect(
      () => _recording(referenceEnd: const Duration(seconds: 10)),
      throwsArgumentError,
    );
  });
}

PracticeRecording _recording({
  PracticeRecordingKind kind = PracticeRecordingKind.segmentTake,
  String filePath = 'practice_recordings/take-1.m4a',
  Duration? referenceEnd = const Duration(seconds: 20),
}) {
  return PracticeRecording(
    id: 'take-1',
    sourceId: 'source-1',
    segmentId: 'segment-1',
    kind: kind,
    filePath: filePath,
    duration: const Duration(seconds: 8),
    referenceStart: const Duration(seconds: 12),
    referenceEnd: referenceEnd,
    referenceSpeed: 0.83,
    title: '主歌试录',
    recordedAt: DateTime.utc(2026, 10, 14, 13),
  );
}

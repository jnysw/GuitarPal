import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12);

  test('exposes the selected segment duration', () {
    final segment = PracticeSegment(
      id: 'segment-1',
      sourceId: 'source-1',
      title: 'Call',
      start: const Duration(seconds: 4),
      end: const Duration(seconds: 9),
      createdAt: now,
      updatedAt: now,
    );

    expect(segment.duration, const Duration(seconds: 5));
    expect(segment.note, isNull);
    expect(segment.preferredSpeed, 1.0);
  });

  test('copyWith updates practice preferences and can clear a note', () {
    final original = PracticeSegment(
      id: 'segment-1',
      sourceId: 'source-1',
      title: 'Call',
      start: const Duration(seconds: 4),
      end: const Duration(seconds: 9),
      note: 'Slow down before the bend',
      preferredSpeed: 0.75,
      createdAt: now,
      updatedAt: now,
    );

    final updatedAt = now.add(const Duration(minutes: 1));
    final updated = original.copyWith(
      title: 'Response',
      note: null,
      preferredSpeed: 1.25,
      updatedAt: updatedAt,
    );

    expect(updated.id, original.id);
    expect(updated.sourceId, original.sourceId);
    expect(updated.createdAt, original.createdAt);
    expect(updated.title, 'Response');
    expect(updated.note, isNull);
    expect(updated.preferredSpeed, 1.25);
    expect(updated.updatedAt, updatedAt);
  });

  test('rejects an invalid time range', () {
    expect(
      () => PracticeSegment(
        id: 'segment-1',
        sourceId: 'source-1',
        title: 'Invalid',
        start: const Duration(seconds: 9),
        end: const Duration(seconds: 4),
        createdAt: now,
        updatedAt: now,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a preferred speed outside the supported range', () {
    expect(
      () => PracticeSegment(
        id: 'segment-1',
        sourceId: 'source-1',
        title: 'Invalid speed',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        preferredSpeed: double.nan,
        createdAt: now,
        updatedAt: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => PracticeSegment(
        id: 'segment-1',
        sourceId: 'source-1',
        title: 'Invalid speed',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        preferredSpeed: 2.5,
        createdAt: now,
        updatedAt: now,
      ),
      throwsArgumentError,
    );
  });
}

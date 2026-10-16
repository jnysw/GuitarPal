import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_card.dart';

void main() {
  testWidgets('shows timing, preferred speed, note, and edit actions', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 13);
    final segment = PracticeSegment(
      id: 'segment-card',
      sourceId: 'source-1',
      title: '副歌换和弦',
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 7),
      note: '留意第三拍的闷音',
      preferredSpeed: 0.75,
      createdAt: now,
      updatedAt: now,
    );
    var opened = false;
    var edited = false;
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeSegmentCard(
            segment: segment,
            onOpen: () => opened = true,
            onEdit: () => edited = true,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('副歌换和弦'), findsOneWidget);
    expect(find.text('0:02 – 0:07 · 0:05'), findsOneWidget);
    expect(find.text('0.75x'), findsOneWidget);
    expect(find.text('留意第三拍的闷音'), findsOneWidget);

    await tester.tap(find.text('副歌换和弦'));
    expect(opened, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('segment_actions_segment-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit_segment_segment-card')));
    await tester.pumpAndSettle();
    expect(edited, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('segment_actions_segment-card')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_segment_segment-card')));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}

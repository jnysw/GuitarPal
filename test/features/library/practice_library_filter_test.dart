import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/domain/practice_library_filter.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14);
  final pendingBilibili = PracticeSource(
    id: 'pending-bilibili',
    platform: SourcePlatform.bilibili,
    kind: SourceKind.webReference,
    title: '待练 B站内容',
    createdAt: now,
    updatedAt: now,
  );
  final completedBilibili = pendingBilibili.copyWith(completedAt: now);

  test('empty filter matches every source', () {
    const filter = PracticeLibraryFilter();
    expect(filter.isActive, isFalse);
    expect(filter.matches(pendingBilibili, hasPlan: false), isTrue);
    expect(filter.matches(completedBilibili, hasPlan: true), isTrue);
  });

  test('combines platform, completion, and plan predicates', () {
    const filter = PracticeLibraryFilter(
      platform: SourcePlatform.bilibili,
      completion: LibraryCompletionFilter.completed,
      plan: LibraryPlanFilter.planned,
    );

    expect(filter.activeCount, 3);
    expect(filter.matches(completedBilibili, hasPlan: true), isTrue);
    expect(filter.matches(completedBilibili, hasPlan: false), isFalse);
    expect(filter.matches(pendingBilibili, hasPlan: true), isFalse);
    expect(
      filter.matches(
        PracticeSource(
          id: 'local',
          platform: SourcePlatform.local,
          kind: SourceKind.video,
          title: '本地',
          completedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        hasPlan: true,
      ),
      isFalse,
    );
  });
}

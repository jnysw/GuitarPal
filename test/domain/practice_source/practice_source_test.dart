import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/source_capabilities.dart';

void main() {
  test('PracticeSource keeps domain data independent of Flutter', () {
    final createdAt = DateTime.utc(2026, 9, 27);
    final source = PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.youtube,
      kind: SourceKind.video,
      originalUri: Uri.parse('https://youtu.be/example'),
      title: 'Fingerstyle exercise',
      duration: const Duration(minutes: 3),
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(source.platform, SourcePlatform.youtube);
    expect(source.duration, const Duration(minutes: 3));
    expect(source.isCompleted, isFalse);
  });

  test('copyWith preserves, sets, and clears completion time', () {
    final now = DateTime.utc(2026, 10, 14, 9);
    final source = PracticeSource(
      id: 'source-status',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      title: '状态测试',
      createdAt: now,
      updatedAt: now,
    );
    final completedAt = DateTime.utc(2026, 10, 14, 10);
    final completed = source.copyWith(completedAt: completedAt);

    expect(completed.isCompleted, isTrue);
    expect(completed.completedAt, completedAt);
    expect(completed.copyWith().completedAt, completedAt);
    expect(completed.copyWith(completedAt: null).isCompleted, isFalse);
  });

  test('copyWith preserves, sets, and clears thumbnail URI', () {
    final now = DateTime.utc(2026, 10, 14, 9);
    final original = Uri.parse('https://example.com/old.jpg');
    final replacement = Uri.parse('https://example.com/new.jpg');
    final source = PracticeSource(
      id: 'source-thumbnail',
      platform: SourcePlatform.genericWeb,
      kind: SourceKind.webReference,
      title: '封面测试',
      thumbnailUri: original,
      createdAt: now,
      updatedAt: now,
    );

    expect(source.copyWith().thumbnailUri, original);
    expect(
      source.copyWith(thumbnailUri: replacement).thumbnailUri,
      replacement,
    );
    expect(source.copyWith(thumbnailUri: null).thumbnailUri, isNull);
  });

  test('copyWith preserves, sets, and clears the source note', () {
    final now = DateTime.utc(2026, 10, 14, 9);
    final source = PracticeSource(
      id: 'source-note',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      title: '笔记测试',
      note: '保持节拍稳定',
      createdAt: now,
      updatedAt: now,
    );

    expect(source.copyWith().note, '保持节拍稳定');
    expect(source.copyWith(note: '注意换把').note, '注意换把');
    expect(source.copyWith(note: null).note, isNull);
  });

  test('reference capabilities never claim playback controls', () {
    expect(SourceCapabilities.reference.canOpen, isTrue);
    expect(SourceCapabilities.reference.canPlayInline, isFalse);
    expect(SourceCapabilities.reference.canSeek, isFalse);
    expect(SourceCapabilities.reference.canLoop, isFalse);
  });

  test('local video capabilities support the full practice controls', () {
    expect(SourceCapabilities.localVideo.canPlayInline, isTrue);
    expect(SourceCapabilities.localVideo.canSeek, isTrue);
    expect(SourceCapabilities.localVideo.canChangeSpeed, isTrue);
    expect(SourceCapabilities.localVideo.canLoop, isTrue);
  });
}

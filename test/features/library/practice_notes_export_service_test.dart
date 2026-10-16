import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/application/practice_notes_export_service.dart';

void main() {
  const service = PracticeNotesExportService();
  final now = DateTime.utc(2026, 10, 14, 9);

  test('exports source and noted segments as readable Markdown', () {
    final source = PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.video,
      title: '  交替拨弦\n练习  ',
      originalUri: Uri.parse('https://www.bilibili.com/video/BV1notes'),
      duration: const Duration(minutes: 3, seconds: 15, milliseconds: 250),
      note: ' 保持右手放松\n逐步提速 ',
      createdAt: now,
      updatedAt: now,
    );
    final segments = [
      PracticeSegment(
        id: 'later',
        sourceId: source.id,
        title: ' 第二段 ',
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 40, milliseconds: 125),
        note: '注意换弦',
        preferredSpeed: 0.87,
        createdAt: now,
        updatedAt: now,
      ),
      PracticeSegment(
        id: 'without-note',
        sourceId: source.id,
        title: '不导出的片段',
        start: const Duration(seconds: 20),
        end: const Duration(seconds: 25),
        createdAt: now,
        updatedAt: now,
      ),
      PracticeSegment(
        id: 'first',
        sourceId: source.id,
        title: '第一段',
        start: const Duration(seconds: 12, milliseconds: 340),
        end: const Duration(seconds: 18, milliseconds: 905),
        note: '节拍要稳定',
        preferredSpeed: 0.71,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final export = service.build(source: source, segments: segments);

    expect(export.subject, '交替拨弦 练习 · GuitarPal 练习笔记');
    expect(export.markdown, startsWith('# 交替拨弦 练习'));
    expect(export.markdown, contains('- 来源：B站'));
    expect(
      export.markdown,
      contains('- 原链接：https://www.bilibili.com/video/BV1notes'),
    );
    expect(export.markdown, contains('- 时长：3:15.250'));
    expect(export.markdown, contains('保持右手放松\n逐步提速'));
    expect(export.markdown, contains('- 区间：0:12.340 – 0:18.905'));
    expect(export.markdown, contains('- 建议倍速：0.71x'));
    expect(export.markdown, isNot(contains('不导出的片段')));
    expect(
      export.markdown.indexOf('### 第一段'),
      lessThan(export.markdown.indexOf('### 第二段')),
    );
    expect(export.markdown, endsWith('由 GuitarPal 导出'));
  });

  test('detects notes and does not expose local file paths', () {
    final source = PracticeSource(
      id: 'local-source',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      title: '本地练习',
      canonicalUri: Uri.file('/private/app/video.mp4'),
      createdAt: now,
      updatedAt: now,
    );
    final segment = PracticeSegment(
      id: 'segment-1',
      sourceId: source.id,
      title: '主歌',
      start: Duration.zero,
      end: const Duration(seconds: 10),
      note: '  分解和弦  ',
      createdAt: now,
      updatedAt: now,
    );

    expect(service.hasExportableNotes(source, const []), isFalse);
    expect(service.hasExportableNotes(source, [segment]), isTrue);

    final markdown = service
        .build(source: source, segments: [segment])
        .markdown;
    expect(markdown, contains('_未填写曲目总体笔记_'));
    expect(markdown, contains('分解和弦'));
    expect(markdown, isNot(contains('/private/app/video.mp4')));
  });
}

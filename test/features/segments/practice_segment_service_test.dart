import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment_repository.dart';
import 'package:guitar_pal/features/segments/application/practice_segment_service.dart';

void main() {
  late _MemorySegmentRepository repository;
  late PracticeSegmentService service;

  setUp(() {
    repository = _MemorySegmentRepository();
    service = PracticeSegmentService(
      repository,
      clock: () => DateTime.utc(2026, 10, 12, 10),
    );
  });

  test('creates a trimmed persistent segment', () async {
    final segment = await service.create(
      sourceId: 'source-1',
      title: '  第一乐句  ',
      start: const Duration(seconds: 3),
      end: const Duration(seconds: 8),
      note: '  先用慢速找准音  ',
      preferredSpeed: 0.75,
    );

    expect(segment.title, '第一乐句');
    expect(segment.note, '先用慢速找准音');
    expect(segment.preferredSpeed, 0.75);
    expect(segment.duration, const Duration(seconds: 5));
    expect(segment.createdAt, DateTime.utc(2026, 10, 12, 10));
    expect(repository.segments.single.id, segment.id);
  });

  test('rejects a blank title and invalid range', () async {
    expect(
      () => service.create(
        sourceId: 'source-1',
        title: '   ',
        start: Duration.zero,
        end: const Duration(seconds: 2),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.create(
        sourceId: 'source-1',
        title: '无效区间',
        start: const Duration(seconds: 3),
        end: const Duration(seconds: 2),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'updates editable fields without changing identity or creation time',
    () async {
      final createdAt = DateTime.utc(2026, 10, 10, 8);
      final original = PracticeSegment(
        id: 'segment-1',
        sourceId: 'source-1',
        title: '旧标题',
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 5),
        note: '旧笔记',
        preferredSpeed: 0.75,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      await repository.save(original);

      final updated = await service.update(
        original,
        title: '  新标题  ',
        start: const Duration(seconds: 4),
        end: const Duration(seconds: 10),
        note: '   ',
        preferredSpeed: 1.25,
        sourceDuration: const Duration(seconds: 12),
      );

      expect(updated.id, original.id);
      expect(updated.sourceId, original.sourceId);
      expect(updated.createdAt, createdAt);
      expect(updated.updatedAt, DateTime.utc(2026, 10, 12, 10));
      expect(updated.title, '新标题');
      expect(updated.start, const Duration(seconds: 4));
      expect(updated.end, const Duration(seconds: 10));
      expect(updated.note, isNull);
      expect(updated.preferredSpeed, 1.25);
      expect(repository.segments, [updated]);
    },
  );

  test('normalizes preferred speed to the supported 0.01 step', () async {
    final segment = await service.create(
      sourceId: 'source-1',
      title: '精确倍速',
      start: Duration.zero,
      end: const Duration(seconds: 10),
      preferredSpeed: 1.237,
    );

    expect(segment.preferredSpeed, 1.24);
    expect(repository.segments.single.preferredSpeed, 1.24);
  });

  test('validates note, speed, negative start, and source duration', () async {
    Future<PracticeSegment> create({
      Duration start = Duration.zero,
      Duration end = const Duration(seconds: 2),
      String? note,
      double preferredSpeed = 1.0,
      Duration? sourceDuration,
    }) {
      return service.create(
        sourceId: 'source-1',
        title: '片段',
        start: start,
        end: end,
        note: note,
        preferredSpeed: preferredSpeed,
        sourceDuration: sourceDuration,
      );
    }

    expect(
      () => create(note: List.filled(2001, 'x').join()),
      throwsA(isA<FormatException>()),
    );
    expect(() => create(preferredSpeed: 2.1), throwsA(isA<FormatException>()));
    expect(
      () => create(start: const Duration(milliseconds: -1)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => create(
        end: const Duration(seconds: 3),
        sourceDuration: const Duration(seconds: 2),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

final class _MemorySegmentRepository implements PracticeSegmentRepository {
  final List<PracticeSegment> segments = [];

  @override
  Future<void> delete(String id) async {
    segments.removeWhere((segment) => segment.id == id);
  }

  @override
  Future<PracticeSegment?> getById(String id) async {
    return segments.where((segment) => segment.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSegment segment) async {
    final index = segments.indexWhere((item) => item.id == segment.id);
    if (index == -1) {
      segments.add(segment);
    } else {
      segments[index] = segment;
    }
  }

  @override
  Stream<List<PracticeSegment>> watchBySource(String sourceId) {
    return Stream.value(
      segments.where((segment) => segment.sourceId == sourceId).toList(),
    );
  }
}

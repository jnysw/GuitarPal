import 'package:uuid/uuid.dart';

import '../../../domain/practice_segment/practice_segment.dart';
import '../../../domain/practice_segment/practice_segment_repository.dart';
import '../../../media/playback/playback_speed.dart';

class PracticeSegmentService {
  PracticeSegmentService(
    this._repository, {
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PracticeSegmentRepository _repository;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<PracticeSegment> create({
    required String sourceId,
    required String title,
    required Duration start,
    required Duration end,
    String? note,
    double preferredSpeed = 1.0,
    Duration? sourceDuration,
  }) async {
    final normalizedTitle = _normalizeTitle(title);
    final normalizedNote = _normalizeNote(note);
    _validateRange(start, end, sourceDuration: sourceDuration);
    _validateSpeed(preferredSpeed);
    final normalizedSpeed = normalizePlaybackSpeed(preferredSpeed);

    final now = _clock().toUtc();
    final segment = PracticeSegment(
      id: _uuid.v4(),
      sourceId: sourceId,
      title: normalizedTitle,
      start: start,
      end: end,
      note: normalizedNote,
      preferredSpeed: normalizedSpeed,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.save(segment);
    return segment;
  }

  Future<PracticeSegment> update(
    PracticeSegment segment, {
    required String title,
    required Duration start,
    required Duration end,
    String? note,
    required double preferredSpeed,
    Duration? sourceDuration,
  }) async {
    final normalizedTitle = _normalizeTitle(title);
    final normalizedNote = _normalizeNote(note);
    _validateRange(start, end, sourceDuration: sourceDuration);
    _validateSpeed(preferredSpeed);
    final normalizedSpeed = normalizePlaybackSpeed(preferredSpeed);

    final updated = segment.copyWith(
      title: normalizedTitle,
      start: start,
      end: end,
      note: normalizedNote,
      preferredSpeed: normalizedSpeed,
      updatedAt: _clock().toUtc(),
    );
    await _repository.save(updated);
    return updated;
  }

  Future<void> delete(PracticeSegment segment) {
    return _repository.delete(segment.id);
  }

  String _normalizeTitle(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw const FormatException('请输入片段名称');
    }
    if (normalized.length > 120) {
      throw const FormatException('片段名称不能超过 120 个字符');
    }
    return normalized;
  }

  String? _normalizeNote(String? note) {
    final normalized = note?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.length > 2000) {
      throw const FormatException('片段笔记不能超过 2000 个字符');
    }
    return normalized;
  }

  void _validateRange(
    Duration start,
    Duration end, {
    Duration? sourceDuration,
  }) {
    if (start.isNegative) {
      throw const FormatException('片段开始时间不能为负数');
    }
    if (end <= start) {
      throw const FormatException('片段结束时间必须晚于开始时间');
    }
    if (sourceDuration != null && end > sourceDuration) {
      throw const FormatException('片段结束时间不能超过视频时长');
    }
  }

  void _validateSpeed(double preferredSpeed) {
    if (!preferredSpeed.isFinite ||
        preferredSpeed < 0.5 ||
        preferredSpeed > 2.0) {
      throw const FormatException('默认倍速必须在 0.5x 到 2.0x 之间');
    }
  }
}

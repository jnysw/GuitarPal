import '../../../domain/practice_segment/practice_segment.dart';
import '../../../domain/practice_source/practice_source.dart';

class PracticeNotesExport {
  const PracticeNotesExport({required this.subject, required this.markdown});

  final String subject;
  final String markdown;
}

class PracticeNotesExportService {
  const PracticeNotesExportService();

  bool hasExportableNotes(
    PracticeSource source,
    List<PracticeSegment> segments,
  ) {
    return _hasText(source.note) || segments.any((item) => _hasText(item.note));
  }

  PracticeNotesExport build({
    required PracticeSource source,
    required List<PracticeSegment> segments,
  }) {
    final notedSegments =
        segments.where((item) => _hasText(item.note)).toList(growable: false)
          ..sort((left, right) => left.start.compareTo(right.start));
    final buffer = StringBuffer()
      ..writeln('# ${_singleLine(source.title)}')
      ..writeln()
      ..writeln('- 来源：${_platformLabel(source.platform)}');

    final sourceUri = source.platform == SourcePlatform.local
        ? null
        : source.originalUri ?? source.canonicalUri;
    if (sourceUri != null) {
      buffer.writeln('- 原链接：$sourceUri');
    }
    if (source.duration case final duration? when duration > Duration.zero) {
      buffer.writeln('- 时长：${_formatTimecode(duration)}');
    }

    buffer
      ..writeln()
      ..writeln('## 曲目笔记')
      ..writeln()
      ..writeln(_normalizedNote(source.note) ?? '_未填写曲目总体笔记_')
      ..writeln()
      ..writeln('## A-B 片段笔记')
      ..writeln();

    if (notedSegments.isEmpty) {
      buffer.writeln('_暂无带笔记的片段_');
    } else {
      for (var index = 0; index < notedSegments.length; index++) {
        final segment = notedSegments[index];
        buffer
          ..writeln('### ${_singleLine(segment.title)}')
          ..writeln()
          ..writeln(
            '- 区间：${_formatTimecode(segment.start)} – '
            '${_formatTimecode(segment.end)}',
          )
          ..writeln('- 建议倍速：${segment.preferredSpeed.toStringAsFixed(2)}x')
          ..writeln()
          ..writeln(_normalizedNote(segment.note));
        if (index != notedSegments.length - 1) buffer.writeln();
      }
    }

    buffer
      ..writeln()
      ..writeln('---')
      ..writeln('由 GuitarPal 导出');

    return PracticeNotesExport(
      subject: '${_singleLine(source.title)} · GuitarPal 练习笔记',
      markdown: buffer.toString().trimRight(),
    );
  }
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String? _normalizedNote(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _singleLine(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地视频',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'B站',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页链接',
  };
}

String _formatTimecode(Duration value) {
  final totalMilliseconds = value.inMilliseconds;
  final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (totalMilliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final seconds = (totalMilliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final milliseconds = totalMilliseconds % 1000;
  final secondsText = seconds.toString().padLeft(2, '0');
  final millisecondsText = milliseconds == 0
      ? ''
      : '.${milliseconds.toString().padLeft(3, '0')}';
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '$secondsText$millisecondsText';
  }
  return '$minutes:$secondsText$millisecondsText';
}

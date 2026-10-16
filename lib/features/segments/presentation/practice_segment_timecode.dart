/// Parses a practice timecode written as `m:ss`, `h:mm:ss`, or either form
/// with one to three fractional-second digits.
///
/// Minutes may be greater than 59 in the two-component form. In the
/// three-component form, both minutes and seconds must be between 00 and 59.
/// Surrounding whitespace is ignored. Returns `null` when [value] is not a
/// valid timecode.
Duration? tryParsePracticeTimecode(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2 && parts.length != 3) return null;
  final leadingParts = parts.take(parts.length - 1).toList(growable: false);
  if (leadingParts.any((part) => !_isAsciiDigits(part))) return null;

  final secondsMatch = RegExp(r'^(\d{2})(?:\.(\d{1,3}))?$')
      .firstMatch(parts.last);
  if (secondsMatch == null) return null;
  final seconds = int.parse(secondsMatch.group(1)!);
  if (seconds > 59) return null;
  final fraction = secondsMatch.group(2);
  final milliseconds = fraction == null
      ? 0
      : int.parse(fraction.padRight(3, '0'));

  if (parts.length == 2) {
    final minutes = int.tryParse(parts.first);
    if (minutes == null) return null;
    return Duration(
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (minutes > 59 || parts[1].length != 2) return null;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: milliseconds,
  );
}

/// Formats [duration] as `m:ss[.SSS]`, or `h:mm:ss[.SSS]` when it is at least
/// one hour. Fractional trailing zeroes are omitted while millisecond precision
/// is preserved.
String formatPracticeTimecode(Duration duration) {
  if (duration.isNegative) {
    throw ArgumentError.value(duration, 'duration', 'must not be negative');
  }

  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ Duration.secondsPerHour;
  final minutes =
      (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  final secondsText = seconds.toString().padLeft(2, '0');
  final milliseconds = duration.inMilliseconds % 1000;
  final fraction = milliseconds == 0
      ? ''
      : '.${milliseconds.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';

  if (hours == 0) {
    final totalMinutes = totalSeconds ~/ Duration.secondsPerMinute;
    return '$totalMinutes:$secondsText$fraction';
  }

  return '$hours:${minutes.toString().padLeft(2, '0')}:$secondsText$fraction';
}

bool _isAsciiDigits(String value) {
  if (value.isEmpty) return false;
  for (final codeUnit in value.codeUnits) {
    if (codeUnit < 0x30 || codeUnit > 0x39) return false;
  }
  return true;
}

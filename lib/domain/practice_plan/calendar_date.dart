/// A timezone-free calendar day used by plans and daily progress.
///
/// Persisting a `DateTime` for a day-only value can move the date across
/// midnight when UTC and local time are converted. `CalendarDate` stores only
/// the year, month, and day so a plan scheduled for October 13 stays on that
/// day in every layer of the app.
class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(this.year, this.month, this.day) {
    final normalized = DateTime(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(dayKey, 'date', 'must be a valid date');
    }
  }

  factory CalendarDate.fromDateTime(DateTime value) {
    final local = value.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  factory CalendarDate.fromDayKey(int value) {
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    return CalendarDate(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  int get dayKey => year * 10000 + month * 100 + day;

  int get weekday => DateTime(year, month, day).weekday;

  DateTime toLocalDateTime() => DateTime(year, month, day);

  CalendarDate addDays(int days) {
    return CalendarDate.fromDateTime(
      DateTime(year, month, day).add(Duration(days: days)),
    );
  }

  @override
  int compareTo(CalendarDate other) => dayKey.compareTo(other.dayKey);

  bool operator <(CalendarDate other) => compareTo(other) < 0;

  bool operator <=(CalendarDate other) => compareTo(other) <= 0;

  bool operator >(CalendarDate other) => compareTo(other) > 0;

  bool operator >=(CalendarDate other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    return other is CalendarDate && other.dayKey == dayKey;
  }

  @override
  int get hashCode => dayKey.hashCode;

  @override
  String toString() {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}

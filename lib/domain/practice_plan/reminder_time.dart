/// A timezone-free local clock time used by practice-plan reminders.
///
/// The persisted representation is [minutesSinceMidnight]. A plan stores this
/// value as nullable: `null` means that reminders are disabled. The device's
/// current local timezone is intentionally applied only when a notification is
/// scheduled, so changing timezone keeps a reminder at the same wall-clock
/// time (for example, 20:30).
class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime._(this.hour, this.minute);

  factory ReminderTime({required int hour, required int minute}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be between 0 and 59');
    }
    return ReminderTime._(hour, minute);
  }

  factory ReminderTime.fromMinutesSinceMidnight(int value) {
    if (value < 0 || value >= minutesPerDay) {
      throw ArgumentError.value(
        value,
        'minutesSinceMidnight',
        'must be between 0 and 1439',
      );
    }
    return ReminderTime._(value ~/ 60, value % 60);
  }

  static const int minutesPerDay = 24 * 60;

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  /// A locale-independent value suitable for compact plan-card labels.
  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(ReminderTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) {
    return other is ReminderTime &&
        other.minutesSinceMidnight == minutesSinceMidnight;
  }

  @override
  int get hashCode => minutesSinceMidnight.hashCode;

  @override
  String toString() => hhmm;
}

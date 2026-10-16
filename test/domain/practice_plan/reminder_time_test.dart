import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/reminder_time.dart';

void main() {
  group('ReminderTime', () {
    test('converts to and from minutes since midnight', () {
      final time = ReminderTime(hour: 20, minute: 30);

      expect(time.minutesSinceMidnight, 1230);
      expect(ReminderTime.fromMinutesSinceMidnight(1230), time);
    });

    test('formats a stable zero-padded 24-hour label', () {
      expect(ReminderTime(hour: 7, minute: 5).hhmm, '07:05');
      expect(ReminderTime(hour: 0, minute: 0).toString(), '00:00');
      expect(ReminderTime(hour: 23, minute: 59).hhmm, '23:59');
    });

    test('accepts the complete minute-of-day boundary', () {
      expect(
        ReminderTime.fromMinutesSinceMidnight(0),
        ReminderTime(hour: 0, minute: 0),
      );
      expect(
        ReminderTime.fromMinutesSinceMidnight(1439),
        ReminderTime(hour: 23, minute: 59),
      );
    });

    test('rejects invalid clock fields and persisted values', () {
      expect(() => ReminderTime(hour: -1, minute: 0), throwsArgumentError);
      expect(() => ReminderTime(hour: 24, minute: 0), throwsArgumentError);
      expect(() => ReminderTime(hour: 12, minute: -1), throwsArgumentError);
      expect(() => ReminderTime(hour: 12, minute: 60), throwsArgumentError);
      expect(
        () => ReminderTime.fromMinutesSinceMidnight(-1),
        throwsArgumentError,
      );
      expect(
        () => ReminderTime.fromMinutesSinceMidnight(1440),
        throwsArgumentError,
      );
    });

    test('sorts by wall-clock time', () {
      final times = [
        ReminderTime(hour: 20, minute: 0),
        ReminderTime(hour: 7, minute: 30),
        ReminderTime(hour: 12, minute: 15),
      ]..sort();

      expect(times.map((time) => time.hhmm), ['07:30', '12:15', '20:00']);
    });
  });
}

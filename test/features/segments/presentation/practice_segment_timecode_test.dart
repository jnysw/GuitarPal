import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_timecode.dart';

void main() {
  group('tryParsePracticeTimecode', () {
    test('parses minute and hour timecodes', () {
      expect(tryParsePracticeTimecode('0:00'), Duration.zero);
      expect(
        tryParsePracticeTimecode('12:34'),
        const Duration(minutes: 12, seconds: 34),
      );
      expect(
        tryParsePracticeTimecode(' 1:02:03 '),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(tryParsePracticeTimecode('90:00'), const Duration(minutes: 90));
      expect(
        tryParsePracticeTimecode('0:01.125'),
        const Duration(seconds: 1, milliseconds: 125),
      );
      expect(
        tryParsePracticeTimecode('1:02:03.5'),
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500),
      );
    });

    test('rejects malformed or out-of-range timecodes', () {
      for (final value in [
        '',
        '12',
        '-1:00',
        '1:2',
        '1:60',
        '1:60:00',
        '1:00:60',
        '1:02.1234',
        '1:02:03:04',
        'one:02',
      ]) {
        expect(
          tryParsePracticeTimecode(value),
          isNull,
          reason: '$value should be rejected',
        );
      }
    });
  });

  group('formatPracticeTimecode', () {
    test('uses m:ss below one hour and h:mm:ss from one hour', () {
      expect(formatPracticeTimecode(Duration.zero), '0:00');
      expect(
        formatPracticeTimecode(const Duration(minutes: 12, seconds: 4)),
        '12:04',
      );
      expect(
        formatPracticeTimecode(
          const Duration(hours: 2, minutes: 3, seconds: 4),
        ),
        '2:03:04',
      );
    });

    test('round-trips millisecond precision and trims fractional zeroes', () {
      expect(
        formatPracticeTimecode(
          const Duration(minutes: 1, seconds: 2, milliseconds: 900),
        ),
        '1:02.9',
      );
      const precise = Duration(minutes: 1, seconds: 2, milliseconds: 125);
      expect(
        tryParsePracticeTimecode(formatPracticeTimecode(precise)),
        precise,
      );
    });

    test('rejects negative durations', () {
      expect(
        () => formatPracticeTimecode(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });
}

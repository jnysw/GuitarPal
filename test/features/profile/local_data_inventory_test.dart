import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/profile/domain/local_data_inventory.dart';

void main() {
  test('counts local metadata, notes, and optional recordings separately', () {
    final now = DateTime.utc(2026, 10, 26, 9);
    final inventory = LocalDataInventory.calculate(
      sources: [
        PracticeSource(
          id: 'source-1',
          platform: SourcePlatform.local,
          kind: SourceKind.video,
          title: '练习曲目',
          note: '整曲笔记',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      segments: [
        PracticeSegment(
          id: 'segment-1',
          sourceId: 'source-1',
          title: '主歌',
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 8),
          note: '片段笔记',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      plans: [
        PracticePlan(
          id: 'plan-1',
          name: '每日练习',
          sourceId: 'source-1',
          goal: const PracticeGoal.loops(5),
          startDate: CalendarDate(2026, 10, 26),
          endDate: CalendarDate(2026, 11, 26),
          repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
          createdAt: now,
          updatedAt: now,
        ),
      ],
      sessions: [
        PracticeSession(
          id: 'session-1',
          sourceId: 'source-1',
          practiceDate: CalendarDate(2026, 10, 26),
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 10)),
          activeDuration: const Duration(minutes: 10),
          loopCount: 5,
          completed: true,
        ),
      ],
      recordings: [
        PracticeRecording(
          id: 'recording-1',
          sourceId: 'source-1',
          kind: PracticeRecordingKind.segmentTake,
          filePath: 'recordings/recording-1.m4a',
          duration: const Duration(seconds: 90),
          referenceStart: Duration.zero,
          referenceSpeed: 1,
          title: '第一次录音',
          note: '录音复盘',
          recordedAt: now,
        ),
      ],
    );

    expect(inventory.sourceCount, 1);
    expect(inventory.segmentCount, 1);
    expect(inventory.planCount, 1);
    expect(inventory.sessionCount, 1);
    expect(inventory.recordingCount, 1);
    expect(inventory.noteCount, 3);
    expect(inventory.metadataItemCount, 4);
    expect(inventory.recordingDuration, const Duration(seconds: 90));
    expect(inventory.isEmpty, isFalse);
  });

  test('empty inventory remains a valid migration preview', () {
    final inventory = LocalDataInventory.calculate(
      sources: const [],
      segments: const [],
      plans: const [],
      sessions: const [],
      recordings: const [],
    );

    expect(inventory.metadataItemCount, 0);
    expect(inventory.recordingCount, 0);
    expect(inventory.isEmpty, isTrue);
  });
}

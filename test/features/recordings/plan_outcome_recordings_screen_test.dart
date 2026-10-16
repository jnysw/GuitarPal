import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_repository.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording_repository.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/library/practice_source_providers.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/recordings/presentation/plan_outcome_recordings_screen.dart';

void main() {
  testWidgets('compares two plan outcomes at a shared position', (
    tester,
  ) async {
    final plan = _plan();
    final older = _outcome(
      'older',
      title: '第一周成果',
      recordedAt: DateTime.utc(2026, 10, 8, 12),
      duration: const Duration(seconds: 5),
    );
    final newer = _outcome(
      'newer',
      title: '第二周成果',
      recordedAt: DateTime.utc(2026, 10, 15, 12),
      duration: const Duration(seconds: 6),
    );
    final recordings = _MemoryRecordingRepository([newer, older]);
    final recorder = _FakeAudioRecorder({
      older.filePath: older.duration,
      newer.filePath: newer.duration,
    });
    addTearDown(recordings.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practicePlanRepositoryProvider.overrideWithValue(
            _MemoryPlanRepository(plan),
          ),
          practiceSourceRepositoryProvider.overrideWithValue(
            _MemorySourceRepository(_source()),
          ),
          practiceRecordingRepositoryProvider.overrideWithValue(recordings),
          practiceAudioRecorderProvider.overrideWithValue(recorder),
        ],
        child: const MaterialApp(
          home: PlanOutcomeRecordingsScreen(planId: 'plan-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('第一周成果'), findsOneWidget);
    expect(find.text('第二周成果'), findsOneWidget);
    expect(find.text('成果时间线'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('select_plan_outcome_older')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select_plan_outcome_newer')));
    await tester.pump();
    expect(find.byKey(const Key('plan_outcome_comparison')), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan_outcome_compare_play_pause')));
    await tester.pump();
    expect(recorder.playedPath, older.filePath);

    recorder.position = const Duration(seconds: 2);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('较新 ·'));
    await tester.pump();
    expect(recorder.playedPath, newer.filePath);
    expect(recorder.playedPosition, const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('plan_outcome_play_sequence')));
    await tester.pump();
    expect(recorder.playedPath, older.filePath);
    recorder
      ..position = older.duration
      ..playing = false;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(recorder.playedPath, newer.filePath);
    expect(recorder.playedPosition, Duration.zero);
  });

  testWidgets('deletes an outcome and its private audio file', (tester) async {
    final outcome = _outcome(
      'only',
      title: '待删除成果',
      recordedAt: DateTime.utc(2026, 10, 15, 12),
      duration: const Duration(seconds: 5),
    );
    final recordings = _MemoryRecordingRepository([outcome]);
    final recorder = _FakeAudioRecorder({outcome.filePath: outcome.duration});
    addTearDown(recordings.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practicePlanRepositoryProvider.overrideWithValue(
            _MemoryPlanRepository(_plan()),
          ),
          practiceSourceRepositoryProvider.overrideWithValue(
            _MemorySourceRepository(_source()),
          ),
          practiceRecordingRepositoryProvider.overrideWithValue(recordings),
          practiceAudioRecorderProvider.overrideWithValue(recorder),
        ],
        child: const MaterialApp(
          home: PlanOutcomeRecordingsScreen(planId: 'plan-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('delete_plan_outcome_only')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm_delete_plan_outcome')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('待删除成果'), findsNothing);
    expect(recorder.deletedPaths, [outcome.filePath]);
  });
}

final _now = DateTime.utc(2026, 10, 15, 12);

PracticePlan _plan() {
  return PracticePlan(
    id: 'plan-1',
    name: '副歌稳定计划',
    sourceId: 'source-1',
    segmentId: 'segment-1',
    goal: const PracticeGoal.loops(5),
    startDate: CalendarDate(2026, 10, 1),
    endDate: CalendarDate(2026, 10, 31),
    repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
    createdAt: _now,
    updatedAt: _now,
  );
}

PracticeSource _source() {
  return PracticeSource(
    id: 'source-1',
    platform: SourcePlatform.bilibili,
    kind: SourceKind.video,
    title: '测试曲目',
    externalId: 'BV1test',
    createdAt: _now,
    updatedAt: _now,
  );
}

PracticeRecording _outcome(
  String id, {
  required String title,
  required DateTime recordedAt,
  required Duration duration,
}) {
  return PracticeRecording(
    id: id,
    sourceId: 'source-1',
    segmentId: 'segment-1',
    planId: 'plan-1',
    kind: PracticeRecordingKind.planOutcome,
    filePath: 'practice_recordings/$id.m4a',
    duration: duration,
    referenceStart: const Duration(seconds: 10),
    referenceEnd: const Duration(seconds: 20),
    referenceSpeed: 0.75,
    title: title,
    recordedAt: recordedAt,
  );
}

class _MemoryPlanRepository implements PracticePlanRepository {
  _MemoryPlanRepository(this.plan);

  PracticePlan? plan;

  @override
  Future<void> delete(String id) async => plan = null;

  @override
  Future<PracticePlan?> getById(String id) async => plan;

  @override
  Future<void> save(PracticePlan plan) async => this.plan = plan;

  @override
  Stream<List<PracticePlan>> watchAll() {
    return Stream.value(<PracticePlan>[?plan]);
  }

  @override
  Stream<List<PracticePlan>> watchScheduledFor(CalendarDate date) => watchAll();
}

class _MemorySourceRepository implements PracticeSourceRepository {
  _MemorySourceRepository(this.source);

  PracticeSource? source;

  @override
  Future<void> delete(String id) async => source = null;

  @override
  Future<PracticeSource?> getById(String id) async => source;

  @override
  Future<void> save(PracticeSource source) async => this.source = source;

  @override
  Stream<List<PracticeSource>> watchAll() {
    return Stream.value(<PracticeSource>[?source]);
  }
}

class _MemoryRecordingRepository implements PracticeRecordingRepository {
  _MemoryRecordingRepository(Iterable<PracticeRecording> seed)
    : items = [...seed];

  final List<PracticeRecording> items;
  final _changes = StreamController<void>.broadcast();

  void dispose() => _changes.close();

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
    _changes.add(null);
  }

  @override
  Future<PracticeRecording?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> save(PracticeRecording recording) async {
    items.removeWhere((item) => item.id == recording.id);
    items.add(recording);
    _changes.add(null);
  }

  @override
  Stream<List<PracticeRecording>> watchAll() async* {
    yield List.unmodifiable(items);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(items);
    }
  }

  @override
  Stream<List<PracticeRecording>> watchByPlan(String planId) async* {
    await for (final values in watchAll()) {
      yield values.where((item) => item.planId == planId).toList();
    }
  }

  @override
  Stream<List<PracticeRecording>> watchBySource(String sourceId) async* {
    await for (final values in watchAll()) {
      yield values.where((item) => item.sourceId == sourceId).toList();
    }
  }
}

class _FakeAudioRecorder implements PracticeAudioRecorder {
  _FakeAudioRecorder(this.durations);

  final Map<String, Duration> durations;
  final List<String> deletedPaths = [];
  String? playedPath;
  Duration playedPosition = Duration.zero;
  Duration position = Duration.zero;
  bool playing = false;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> deleteRecording(String relativePath) async {
    deletedPaths.add(relativePath);
  }

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> pausePlayback() async => playing = false;

  @override
  Future<MicrophonePermissionStatus> permissionStatus() async {
    return MicrophonePermissionStatus.granted;
  }

  @override
  Future<void> playRecording(
    String relativePath, {
    Duration position = Duration.zero,
  }) async {
    playedPath = relativePath;
    playedPosition = position;
    this.position = position;
    playing = true;
  }

  @override
  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot() async {
    return PracticeAudioPlaybackSnapshot(
      isLoaded: playedPath != null,
      isPlaying: playing,
      position: position,
      duration: durations[playedPath] ?? Duration.zero,
    );
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    return MicrophonePermissionStatus.granted;
  }

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    return '/app/files/$relativePath';
  }

  @override
  Future<void> seekPlayback(Duration position) async {
    this.position = position;
  }

  @override
  Future<void> start({required String recordingId}) async {}

  @override
  Future<PracticeAudioRecordingResult> stop() {
    throw UnimplementedError();
  }

  @override
  Future<void> stopPlayback() async {
    playedPath = null;
    playing = false;
  }
}

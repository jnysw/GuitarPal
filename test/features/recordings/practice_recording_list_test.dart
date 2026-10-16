import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_analyzer.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording_repository.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/recordings/presentation/practice_recording_list.dart';

void main() {
  testWidgets('plays, edits, and deletes saved segment takes', (tester) async {
    final first = _recording('take-1', title: '第一次副歌', planId: 'plan-1');
    final second = _recording('take-2', title: '第二次副歌');
    final repository = _MemoryRecordingRepository([first, second]);
    final recorder = _FakeAudioRecorder();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceAudioRecorderProvider.overrideWithValue(recorder),
          practiceAudioAnalyzerProvider.overrideWithValue(
            const _FakeAudioAnalyzer(),
          ),
          practiceRecordingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PracticeRecordingList(
                sourceId: 'source-1',
                segments: [
                  PracticeSegment(
                    id: 'segment-1',
                    sourceId: 'source-1',
                    title: '副歌',
                    start: Duration(seconds: 10),
                    end: Duration(seconds: 20),
                    createdAt: _fixedDate,
                    updatedAt: _fixedDate,
                  ),
                ],
                canStartPractice: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('第一次副歌'), findsOneWidget);
    expect(find.text('第二次副歌'), findsOneWidget);
    expect(find.text('副歌'), findsNWidgets(2));
    expect(find.text('0:10–0:20'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('play_recording_take-1')));
    await tester.pump();
    expect(recorder.playedPath, 'practice_recordings/take-1.m4a');
    expect(find.text('0:00 / 0:04'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording_menu_take-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('音频分析（实验）'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('practice_audio_analysis_sheet')),
      findsOneWidget,
    );
    expect(find.text('-18.5 dBFS'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('recording_menu_take-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑名称与复盘'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('practice_recording_title_field')),
      '稳定后的副歌',
    );
    await tester.enterText(
      find.byKey(const Key('practice_recording_note_field')),
      '右手节奏更稳定',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('稳定后的副歌'), findsOneWidget);
    expect(find.text('右手节奏更稳定'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('recording_menu_take-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存为计划成果'));
    await tester.pumpAndSettle();
    expect(
      repository.items.singleWhere((item) => item.id == 'take-1').kind,
      PracticeRecordingKind.planOutcome,
    );
    expect(find.text('稳定后的副歌'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('recording_menu_take-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除录音'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm_delete_practice_recording')),
    );
    await tester.pumpAndSettle();
    expect(find.text('第二次副歌'), findsNothing);
    expect(recorder.deletedPaths, ['practice_recordings/take-2.m4a']);
  });

  testWidgets('shows a practice action when there are no recordings', (
    tester,
  ) async {
    final repository = _MemoryRecordingRepository([]);
    var started = false;
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceAudioRecorderProvider.overrideWithValue(_FakeAudioRecorder()),
          practiceRecordingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PracticeRecordingList(
              sourceId: 'source-1',
              segments: const [],
              canStartPractice: true,
              onStartPractice: () => started = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('还没有练习录音。进入播放器后，可以录下整曲或当前 A-B 片段并与原曲切换回听。'),
      findsOneWidget,
    );
    await tester.tap(find.text('开始练习并录音'));
    expect(started, isTrue);
  });
}

final _fixedDate = DateTime.utc(2026, 10, 14, 12);

PracticeRecording _recording(
  String id, {
  required String title,
  String? planId,
}) {
  return PracticeRecording(
    id: id,
    sourceId: 'source-1',
    segmentId: 'segment-1',
    planId: planId,
    kind: PracticeRecordingKind.segmentTake,
    filePath: 'practice_recordings/$id.m4a',
    duration: const Duration(seconds: 4),
    referenceStart: const Duration(seconds: 10),
    referenceEnd: const Duration(seconds: 20),
    referenceSpeed: 0.75,
    title: title,
    recordedAt: _fixedDate,
  );
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
  String? playedPath;
  final List<String> deletedPaths = [];
  bool playing = false;
  Duration position = Duration.zero;

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
  Future<void> pausePlayback() async {
    playing = false;
  }

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
    this.position = position;
    playing = true;
  }

  @override
  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot() async {
    return PracticeAudioPlaybackSnapshot(
      isLoaded: playedPath != null,
      isPlaying: playing,
      position: position,
      duration: const Duration(seconds: 4),
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
    position = Duration.zero;
  }
}

class _FakeAudioAnalyzer implements PracticeAudioAnalyzer {
  const _FakeAudioAnalyzer();

  @override
  Future<PracticeAudioAnalysis> analyzeRecording(String relativePath) async {
    return const PracticeAudioAnalysis(
      duration: Duration(seconds: 4),
      waveform: [0.1, 0.4, 0.8, 0.3],
      averageLoudnessDbfs: -18.5,
      peakLevelDbfs: -2.4,
      silenceRatio: 0.08,
      onsetCount: 9,
      medianOnsetInterval: Duration(milliseconds: 500),
      onsetIntervalVariation: 0.06,
      sampleRate: 44100,
      channelCount: 1,
      algorithmVersion: 'energy-onset-v1',
    );
  }
}

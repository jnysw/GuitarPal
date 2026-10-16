import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording_repository.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/recordings/presentation/practice_recording_panel.dart';

void main() {
  testWidgets('records, compares, and saves a segment take', (tester) async {
    final recorder = _FakeAudioRecorder();
    final repository = _MemoryRecordingRepository();
    var referencePosition = const Duration(seconds: 12);
    var referencePlaying = false;
    final workflowStates = <bool>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceAudioRecorderProvider.overrideWithValue(recorder),
          practiceRecordingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PracticeRecordingPanel(
                sourceId: 'source-1',
                planId: 'plan-1',
                captureReference: () => const PracticeRecordingReference(
                  start: Duration(seconds: 10),
                  end: Duration(seconds: 20),
                  speed: 0.75,
                  segmentId: 'segment-1',
                  segmentTitle: '副歌',
                ),
                referencePosition: () => referencePosition,
                referenceIsPlaying: () => referencePlaying,
                seekReference: (position) async {
                  referencePosition = position;
                },
                playReference: () async {
                  referencePlaying = true;
                },
                pauseReference: () async {
                  referencePlaying = false;
                },
                onWorkflowActiveChanged: workflowStates.add,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('录下这次练习'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_recording_start')));
    await tester.pump();
    expect(find.text('准备演奏'), findsOneWidget);
    expect(referencePosition, const Duration(seconds: 10));

    for (var index = 0; index < 3; index += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(recorder.startedRecordingId, isNotNull);
    expect(find.byKey(const Key('practice_recording_stop')), findsOneWidget);
    expect(referencePlaying, isTrue);

    await tester.tap(find.byKey(const Key('practice_recording_stop')));
    await tester.pump();
    expect(find.text('对比并保存'), findsOneWidget);
    expect(referencePlaying, isFalse);

    await tester.tap(find.text('我的录音'));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('practice_recording_preview_play_pause')),
    );
    await tester.pump();
    expect(recorder.playedPath, 'practice_recordings/take.m4a');
    expect(recorder.playedPosition, Duration.zero);

    await tester.tap(find.byKey(const Key('practice_recording_save')));
    await tester.pump();
    expect(repository.items, hasLength(1));
    final saved = repository.items.single;
    expect(saved.sourceId, 'source-1');
    expect(saved.planId, 'plan-1');
    expect(saved.segmentId, 'segment-1');
    expect(saved.kind, PracticeRecordingKind.segmentTake);
    expect(saved.referenceStart, const Duration(seconds: 10));
    expect(saved.referenceEnd, const Duration(seconds: 20));
    expect(saved.referenceSpeed, 0.75);
    expect(saved.filePath, 'practice_recordings/take.m4a');
    expect(workflowStates, [true, false]);
  });

  testWidgets('offers settings after microphone permission is blocked', (
    tester,
  ) async {
    final recorder = _FakeAudioRecorder(
      permission: MicrophonePermissionStatus.permanentlyDenied,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceAudioRecorderProvider.overrideWithValue(recorder),
          practiceRecordingRepositoryProvider.overrideWithValue(
            _MemoryRecordingRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PracticeRecordingPanel(
              sourceId: 'source-1',
              captureReference: () => const PracticeRecordingReference(
                start: Duration.zero,
                speed: 1,
              ),
              referencePosition: () => Duration.zero,
              referenceIsPlaying: () => false,
              seekReference: (_) async {},
              playReference: () async {},
              pauseReference: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('practice_recording_start')));
    await tester.pump();
    expect(
      find.byKey(const Key('practice_recording_open_settings')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('practice_recording_open_settings')));
    await tester.pump();
    expect(recorder.didOpenSettings, isTrue);
  });

  testWidgets('explicitly saves a take as a plan outcome', (tester) async {
    final recorder = _FakeAudioRecorder();
    final repository = _MemoryRecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceAudioRecorderProvider.overrideWithValue(recorder),
          practiceRecordingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PracticeRecordingPanel(
                sourceId: 'source-1',
                planId: 'plan-1',
                captureReference: () => const PracticeRecordingReference(
                  start: Duration(seconds: 10),
                  end: Duration(seconds: 20),
                  speed: 0.8,
                  segmentId: 'segment-1',
                ),
                referencePosition: () => const Duration(seconds: 10),
                referenceIsPlaying: () => false,
                seekReference: (_) async {},
                playReference: () async {},
                pauseReference: () async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('practice_recording_start')));
    await tester.pump();
    for (var index = 0; index < 3; index += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('practice_recording_stop')));
    await tester.pump();
    expect(
      find.byKey(const Key('practice_recording_save_outcome')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('practice_recording_save_outcome')));
    await tester.pump();

    expect(repository.items, hasLength(1));
    expect(repository.items.single.kind, PracticeRecordingKind.planOutcome);
    expect(repository.items.single.planId, 'plan-1');
  });
}

class _FakeAudioRecorder implements PracticeAudioRecorder {
  _FakeAudioRecorder({this.permission = MicrophonePermissionStatus.granted});

  MicrophonePermissionStatus permission;
  String? startedRecordingId;
  String? playedPath;
  Duration? playedPosition;
  bool didOpenSettings = false;
  bool recording = false;
  bool playbackLoaded = false;
  bool playbackPlaying = false;
  Duration playbackPosition = Duration.zero;

  @override
  Future<void> cancel() async {
    recording = false;
  }

  @override
  Future<void> deleteRecording(String relativePath) async {}

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<void> openAppSettings() async {
    didOpenSettings = true;
  }

  @override
  Future<void> pausePlayback() async {
    playbackPlaying = false;
  }

  @override
  Future<MicrophonePermissionStatus> permissionStatus() async => permission;

  @override
  Future<void> playRecording(
    String relativePath, {
    Duration position = Duration.zero,
  }) async {
    playedPath = relativePath;
    playedPosition = position;
    playbackLoaded = true;
    playbackPlaying = true;
    playbackPosition = position;
  }

  @override
  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot() async {
    return PracticeAudioPlaybackSnapshot(
      isLoaded: playbackLoaded,
      isPlaying: playbackPlaying,
      position: playbackPosition,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async => permission;

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    return '/app/files/$relativePath';
  }

  @override
  Future<void> seekPlayback(Duration position) async {
    playbackPosition = position;
  }

  @override
  Future<void> start({required String recordingId}) async {
    startedRecordingId = recordingId;
    recording = true;
  }

  @override
  Future<PracticeAudioRecordingResult> stop() async {
    recording = false;
    return const PracticeAudioRecordingResult(
      relativePath: 'practice_recordings/take.m4a',
      absolutePath: '/app/files/practice_recordings/take.m4a',
      duration: Duration(seconds: 4),
    );
  }

  @override
  Future<void> stopPlayback() async {
    playbackLoaded = false;
    playbackPlaying = false;
    playbackPosition = Duration.zero;
  }
}

class _MemoryRecordingRepository implements PracticeRecordingRepository {
  final List<PracticeRecording> items = [];

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<PracticeRecording?> getById(String id) async {
    return items.where((item) => item.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeRecording recording) async {
    items.removeWhere((item) => item.id == recording.id);
    items.add(recording);
  }

  @override
  Stream<List<PracticeRecording>> watchAll() => Stream.value(items);

  @override
  Stream<List<PracticeRecording>> watchByPlan(String planId) {
    return Stream.value(items.where((item) => item.planId == planId).toList());
  }

  @override
  Stream<List<PracticeRecording>> watchBySource(String sourceId) {
    return Stream.value(
      items.where((item) => item.sourceId == sourceId).toList(),
    );
  }
}

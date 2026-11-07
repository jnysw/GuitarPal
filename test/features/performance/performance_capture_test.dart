import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/features/performance/application/performance_capture_controller.dart';
import 'package:guitar_pal/features/performance/application/performance_stage_controller.dart';
import 'package:guitar_pal/features/performance/application/performance_take_service.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/plans/application/practice_playback_session_recorder.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_stage_controller_test.dart'
    show StagePlayer, StageStore, StageSessions;

void main() {
  late Directory root;
  late StagePlayer player;
  late PerformanceStageController stage;
  late PerformanceCaptureController capture;
  late FakePerformanceMic mic;
  late FakePerformanceAudio extra;
  late PerformanceTakeService service;
  late MemoryPerformanceRecordings repo;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('gp_capture_');
    final c = fixtureCandidate(root);
    player = StagePlayer();
    mic = FakePerformanceMic();
    extra = FakePerformanceAudio(mic);
    repo = MemoryPerformanceRecordings();
    stage = PerformanceStageController(
      platform: player,
      store: StageStore(root),
      candidate: c,
      preset: BackingPreset.forCandidate(c, {'bass', 'drums'}),
      recorder: PracticePlaybackSessionRecorder(
        StageSessions(),
        sourceId: 'source',
      ),
      verify: (_) async {},
    );
    await stage.initialize();
    service = PerformanceTakeService(
      PerformanceTakeStore(() async => root),
      repo,
      mic,
      extra,
    );
    capture = PerformanceCaptureController(
      stage,
      mic,
      extra,
      service,
      countdownStep: Duration.zero,
      trialDuration: const Duration(milliseconds: 10),
    );
    await capture.restore();
  });
  tearDown(() async {
    capture.dispose();
    stage.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await player.meter.close();
    await repo.changes.close();
    root.deleteSync(recursive: true);
  });
  test('permission denial and disk preflight cannot start microphone or accompaniment', () async {
    mic.permission = MicrophonePermissionStatus.permanentlyDenied;
    await capture.begin(trial: false);
    expect(capture.permanentlyDenied, isTrue);
    expect(player.plays, 0);
    expect(mic.recording, isFalse);
    mic.permission = MicrophonePermissionStatus.granted;
    extra.freeBytes = 1024;
    await capture.begin(trial: false);
    expect(capture.error, contains('空间'));
    expect(capture.draft, isNull);
    expect(player.plays, 0);
  });
  test('interrupted permission request cannot start late on resume', () async {
    mic.permission = MicrophonePermissionStatus.denied;
    mic.permissionGate = Completer();
    final pending = capture.begin(trial: false);
    await Future<void>.delayed(Duration.zero);
    await capture.interrupt();
    capture.resume();
    mic.permissionGate!.complete(MicrophonePermissionStatus.granted);
    await pending;
    expect(mic.recording, isFalse);
    expect(player.plays, 0);
    expect(capture.draft, isNull);
  });
  test('formal capture freezes actual preset, stops once and survives background as unsaved raw audio', () async {
    await stage.setMaster(.37);
    await capture.begin(trial: false);
    expect(capture.recording, isTrue);
    expect(stage.playing, isTrue);
    expect(mic.recording, isTrue);
    await Future.wait([capture.interrupt(), capture.stop()]);
    expect(mic.stops, 1);
    expect(mic.recording, isFalse);
    expect(stage.playing, isFalse);
    final take = capture.draft!;
    expect(take.preset.master, .37);
    expect(take.durationMs, 2000);
    expect(repo.rows, isEmpty);
    expect((await service.store.load(take.id))!.durationMs, 2000);
    capture.resume();
    expect(stage.playing, isFalse);
    await service.save(take, '今日演奏');
    repo.failRead = true;
    await capture.refreshDraft();
    expect(capture.draft, isNotNull);
    expect(capture.error, contains('草稿状态'));
    repo.failRead = false;
    await capture.refreshDraft();
    expect(capture.error, isNull);
    expect(capture.draft, isNull);
    expect(repo.rows.length, 1);
  });
  test('trial does not play accompaniment, auto-stops and cannot be saved as a performance', () async {
    await capture.begin(trial: true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(player.plays, 0);
    expect(mic.recording, isFalse);
    expect(capture.draft!.trial, isTrue);
    await expectLater(
      service.save(capture.draft!, '试录'),
      throwsFormatException,
    );
    await service.discard(capture.draft!);
    await capture.refreshDraft();
    expect(capture.draft, isNull);
  });
  test('audio device inventory change stops rather than resuming a discontinuous take', () async {
    await capture.begin(trial: false);
    extra.route = 'speaker';
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(mic.recording, isFalse);
    expect(capture.draft!.reason, 'routeChanged');
  });
}

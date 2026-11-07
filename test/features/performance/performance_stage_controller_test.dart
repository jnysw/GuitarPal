import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_session/practice_session_repository.dart';
import 'package:guitar_pal/features/plans/application/practice_playback_session_recorder.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_mix_platform.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/performance/application/performance_stage_controller.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';

import 'performance_backing_test.dart' show fixtureCandidate;

void main() {
  late Directory root;
  late StagePlayer player;
  late StageStore store;
  late StageSessions sessions;
  late DateTime now;
  late PerformanceStageController stage;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gp_stage_');
    player = StagePlayer();
    store = StageStore(root);
    sessions = StageSessions();
    now = DateTime(2026, 10, 31, 10);
    final c = fixtureCandidate(root);
    stage = PerformanceStageController(
      platform: player,
      store: store,
      candidate: c,
      preset: BackingPreset.forCandidate(c, {'drums', 'bass'}),
      recorder: PracticePlaybackSessionRecorder(
        sessions,
        sourceId: 'source',
        clock: () => now,
      ),
      verify: (_) async {},
    );
  });
  tearDown(() async {
    stage.dispose();
    await Future<void>.delayed(Duration.zero);
    await player.meter.close();
    root.deleteSync(recursive: true);
  });
  test('stage loads cached backing paused and cannot download missing tracks on stage', () async {
    await stage.initialize();
    expect(stage.phase, PerformanceStagePhase.ready);
    expect(player.plays, 0);
    expect(sessions.values, isEmpty);
    await stage.suspend();
    stage.resume();
    store.available = false;
    await stage.toggle();
    expect(stage.phase, PerformanceStagePhase.error);
    expect(store.downloads, 0);
    expect(stage.error, contains('准备页'));
  });
  test('one recorder counts actual playing only across pause seek background resume and leave', () async {
    await stage.initialize();
    await stage.toggle();
    expect(stage.playing, isTrue);
    now = now.add(const Duration(seconds: 2));
    await stage.toggle();
    expect(stage.playing, isFalse);
    now = now.add(const Duration(seconds: 3));
    await stage.seek(2000);
    await stage.toggle();
    now = now.add(const Duration(seconds: 1));
    await stage.setMaster(.37);
    await stage.suspend();
    expect(stage.playing, isFalse);
    expect(player.playing, isFalse);
    now = now.add(const Duration(seconds: 10));
    stage.resume();
    expect(player.plays, 2);
    expect(stage.playing, isFalse);
    await stage.toggle();
    expect(stage.positionMs, 2000);
    expect(stage.master, .37);
    expect(player.master, .37);
    now = now.add(const Duration(seconds: 1));
    await stage.leave();
    expect(sessions.values.length, 1);
    expect(sessions.values.single.activeDuration, const Duration(seconds: 4));
    expect(sessions.values.single.completed, isTrue);
  });
  test('meters accept current generation and epoch only, quiet on mute pause and background', () async {
    await stage.initialize();
    await stage.toggle();
    player.emit(left: .25, right: .04);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, greaterThan(stage.right));
    final left = stage.left;
    player.emit(left: 1, right: 1, generation: 0);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, left);
    await stage.seek(3000);
    expect(stage.left, 0);
    player.emit(left: .8, right: .8, epoch: player.epoch - 1);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, 0);
    player.emit(left: .4, right: .4);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, greaterThan(0));
    await stage.setMaster(0);
    player.emit(left: 1, right: 1);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, 0);
    expect(stage.right, 0);
    await stage.setMaster(.8);
    player.emit(left: .4, right: .4, volume: 0);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, 0);
    await stage.toggle();
    player.emit(left: 1, right: 1);
    await Future<void>.delayed(Duration.zero);
    expect(stage.left, 0);
    await stage.suspend();
    stage.resume();
    expect(stage.playing, isFalse);
    expect(stage.left, 0);
  });
  test(
    'native end yields a finish state and replay retains one session identity',
    () async {
      await stage.initialize();
      await stage.toggle();
      now = now.add(const Duration(seconds: 8));
      player.position = 8000;
      player.playing = false;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(stage.phase, PerformanceStagePhase.finished);
      await stage.toggle();
      expect(player.position, 0);
      expect(stage.playing, isTrue);
      now = now.add(const Duration(seconds: 1));
      await stage.leave();
      expect(sessions.values.length, 1);
      expect(sessions.values.single.activeDuration, const Duration(seconds: 9));
    },
  );
  test(
    'failed final save is retryable using the same session and stopped audio',
    () async {
      await stage.initialize();
      await stage.toggle();
      now = now.add(const Duration(seconds: 1));
      sessions.fail = true;
      await expectLater(stage.leave(), throwsStateError);
      expect(player.playing, isFalse);
      sessions.fail = false;
      await stage.leave();
      expect(sessions.values.length, 1);
      expect(sessions.values.single.activeDuration, const Duration(seconds: 1));
    },
  );
}

class StageSessions implements PracticeSessionRepository {
  final Map<String, PracticeSession> rows = {};
  bool fail = false;
  List<PracticeSession> get values => rows.values.toList();
  @override
  Future<void> save(PracticeSession s) async {
    if (fail) throw StateError('write failed');
    rows[s.id] = s;
  }

  @override
  Stream<List<PracticeSession>> watchAll() => Stream.value(values);
  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate d) => watchAll();
  @override
  Stream<List<PracticeSession>> watchBetween(CalendarDate a, CalendarDate b) =>
      watchAll();
}

class StageStore extends AlgorithmStemStore {
  StageStore(this.folder) : super(() async => folder);
  final Directory folder;
  bool available = true;
  int downloads = 0;
  @override
  Future<File?> localFile(String id, LegacyStemFile stem) async =>
      available ? File('${folder.path}/${stem.id}.wav') : null;
  @override
  Future<Map<String, String>> downloadBatch(
    String id,
    List<LegacyStemFile> stems, {
    StemDownloadCancellation? cancellation,
    void Function(StemDownloadProgress)? onProgress,
  }) async {
    downloads++;
    throw StateError('Stage must not download');
  }
}

class StagePlayer extends AlgorithmMixPlatform {
  final meter = StreamController<Map<String, Object?>>.broadcast();
  @override
  Stream<Map<String, Object?>> get levels => meter.stream;
  bool loaded = false, playing = false;
  int position = 0, generation = 0, epoch = 0, plays = 0;
  double master = .8;
  @override
  Future<void> load(Map<String, String> paths) async {
    generation++;
    epoch = 0;
    loaded = true;
    playing = false;
  }

  @override
  Future<void> configureTracks(
    Map<String, StemMixControl> controls, {
    required double master,
    required double speed,
  }) async {
    this.master = master;
  }

  @override
  Future<void> play() async {
    playing = true;
    plays++;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> seek(int v) async {
    position = v;
    epoch++;
  }

  @override
  Future<void> stop() async {
    loaded = false;
    playing = false;
    generation++;
  }

  @override
  Future<Map<String, Object?>> snapshot() async => {
    'isLoaded': loaded,
    'isPlaying': playing,
    'positionMs': position,
    'durationMs': 8000,
    'completedLoops': 0,
    'generation': generation,
    'epoch': epoch,
  };
  void emit({
    required double left,
    required double right,
    int? generation,
    int? epoch,
    double volume = 1,
  }) => meter.add({
    'generation': generation ?? this.generation,
    'epoch': epoch ?? this.epoch,
    'isPlaying': playing,
    'positionMs': position,
    'systemVolume': volume,
    'leftRms': left,
    'rightRms': right,
    'leftPeak': left,
    'rightPeak': right,
  });
}

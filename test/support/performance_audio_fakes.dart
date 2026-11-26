import 'dart:async';

import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording_repository.dart';
import 'package:guitar_pal/features/performance/data/performance_audio_platform.dart';

class MemoryPerformanceRecordings implements PracticeRecordingRepository {
  final rows = <String, PracticeRecording>{};
  final changes = StreamController<void>.broadcast();
  bool fail = false, failRead = false;
  @override
  Future<void> save(PracticeRecording r) async {
    if (fail) throw StateError('write failed');
    rows[r.id] = r;
    changes.add(null);
  }

  @override
  Future<PracticeRecording?> getById(String id) async {
    if (failRead) throw StateError('read failed');
    return rows[id];
  }

  @override
  Future<void> delete(String id) async {
    rows.remove(id);
    changes.add(null);
  }

  @override
  Stream<List<PracticeRecording>> watchAll() async* {
    yield rows.values.toList();
    await for (final _ in changes.stream) {
      yield rows.values.toList();
    }
  }

  @override
  Stream<List<PracticeRecording>> watchBySource(String id) =>
      watchAll().map((all) => all.where((r) => r.sourceId == id).toList());
  @override
  Stream<List<PracticeRecording>> watchByPlan(String id) =>
      watchAll().map((all) => all.where((r) => r.planId == id).toList());
}

class FakePerformanceMic implements PracticeAudioRecorder {
  bool recording = false, playing = false;
  String? id, playbackPath;
  int position = 0, stops = 0;
  Duration duration = const Duration(seconds: 2);
  MicrophonePermissionStatus permission = MicrophonePermissionStatus.granted;
  final files = <String>{};
  Completer<MicrophonePermissionStatus>? permissionGate;
  @override
  Future<MicrophonePermissionStatus> permissionStatus() async => permission;
  @override
  Future<MicrophonePermissionStatus> requestPermission() async =>
      permissionGate == null ? permission : await permissionGate!.future;
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> start({required String recordingId}) async {
    id = recordingId;
    recording = true;
  }

  @override
  Future<PracticeAudioRecordingResult> stop() async {
    stops++;
    if (!recording) throw StateError('not recording');
    recording = false;
    final path = 'practice_recordings/$id.m4a';
    files.add(path);
    return PracticeAudioRecordingResult(
      relativePath: path,
      absolutePath: '/private/$path',
      duration: duration,
    );
  }

  @override
  Future<void> cancel() async {
    recording = false;
  }

  @override
  Future<bool> isRecording() async => recording;
  @override
  Future<void> playRecording(
    String path, {
    Duration position = Duration.zero,
  }) async {
    await resolveAbsolutePath(path);
    playbackPath = path;
    this.position = position.inMilliseconds;
    playing = true;
  }

  @override
  Future<void> pausePlayback() async {
    playing = false;
  }

  @override
  Future<void> seekPlayback(Duration p) async {
    position = p.inMilliseconds;
  }

  @override
  Future<PracticeAudioPlaybackSnapshot> playbackSnapshot() async =>
      PracticeAudioPlaybackSnapshot(
        isLoaded: playbackPath != null,
        isPlaying: playing,
        position: Duration(milliseconds: position),
        duration: duration,
      );
  @override
  Future<void> stopPlayback() async {
    playing = false;
    playbackPath = null;
  }

  @override
  Future<String> resolveAbsolutePath(String p) async {
    if (!files.contains(p)) throw StateError('missing');
    return '/private/$p';
  }

  @override
  Future<void> deleteRecording(String p) async {
    files.remove(p);
  }
}

class FakePerformanceAudio extends PerformanceAudioPlatform {
  FakePerformanceAudio(this.mic);
  final FakePerformanceMic mic;
  int freeBytes = 1024 * 1024 * 1024;
  String route = 'wired';
  double volume = 1;
  @override
  Future<Map<String, Object?>> environment() async => {
    'freeBytes': freeBytes,
    'availableOutputDevices': [route],
    'actualRouteVerified': false,
  };
  @override
  Future<Map<String, Object?>> start(String id) async {
    await mic.start(recordingId: id);
    return {'startedAtElapsedMs': 1000};
  }

  @override
  Future<PracticeAudioRecordingResult> recover(String id) async {
    final path = 'practice_recordings/$id.m4a';
    await mic.resolveAbsolutePath(path);
    return PracticeAudioRecordingResult(
      relativePath: path,
      absolutePath: '/private/$path',
      duration: mic.duration,
    );
  }

  @override
  Future<void> play(String path, int position, double volume) async {
    this.volume = volume;
    await mic.playRecording(path, position: Duration(milliseconds: position));
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }
}

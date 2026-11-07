import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

void main() {
  late _FakeLocalVideoPlayerBridge bridge;
  late LocalVideoPlaybackController controller;

  setUp(() {
    bridge = _FakeLocalVideoPlayerBridge();
    controller = LocalVideoPlaybackController(bridge);
  });

  tearDown(() {
    controller.dispose();
  });

  test('subscribes to and decodes native playback snapshots', () {
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    bridge.emit({
      'ready': true,
      'playing': true,
      'positionMilliseconds': 12500.4,
      'durationMilliseconds': 90000,
      'speed': 1.25,
      'volume': 0.42,
      'hasVideoFrame': true,
      'videoWidth': 1920,
      'videoHeight': 1080,
      'error': '',
    });

    expect(controller.isReady, isTrue);
    expect(controller.isPlaying, isTrue);
    expect(controller.position, const Duration(milliseconds: 12500));
    expect(controller.duration, const Duration(seconds: 90));
    expect(controller.speed, 1.25);
    expect(controller.volume, 0.42);
    expect(controller.hasVideoFrame, isTrue);
    expect(controller.videoWidth, 1920);
    expect(controller.videoHeight, 1080);
    expect(controller.playerError, isNull);
    expect(notifications, 1);
  });

  test('end-of-media loops resume playback intent but an explicit pause is respected', () async {
    await controller.activateLoopRange(
      LoopRange(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ),
    );
    await controller.play();
    bridge.emit({
      'ready': true,
      'playing': false,
      'ended': true,
      'positionMilliseconds': 4000,
      'durationMilliseconds': 10000,
    });
    await Future<void>.delayed(const Duration(milliseconds: 275));
    expect(bridge.playCalls, 2);
    await controller.pause();
    bridge.emit({
      'ready': true,
      'playing': false,
      'positionMilliseconds': 2000,
      'durationMilliseconds': 10000,
    });
    bridge.emit({
      'ready': true,
      'playing': false,
      'ended': true,
      'positionMilliseconds': 4000,
      'durationMilliseconds': 10000,
    });
    await Future<void>.delayed(const Duration(milliseconds: 275));
    expect(bridge.playCalls, 2);
  });

  test('ignores invalid numeric fields and clamps reported speed', () {
    bridge.emit({
      'ready': true,
      'playing': false,
      'positionMilliseconds': 1000,
      'durationMilliseconds': 5000,
      'speed': 1,
      'volume': 0.4,
    });

    bridge.emit({
      'ready': true,
      'playing': false,
      'positionMilliseconds': -20,
      'durationMilliseconds': double.nan,
      'speed': 9,
      'volume': double.nan,
      'error': 'decoder failed',
    });

    expect(controller.position, const Duration(seconds: 1));
    expect(controller.duration, const Duration(seconds: 5));
    expect(controller.speed, 2);
    expect(controller.volume, 0.4);
    expect(controller.playerError, 'decoder failed');
  });

  test('delegates playback commands and requests snapshots', () async {
    bridge.snapshot = {
      'ready': true,
      'playing': false,
      'positionMilliseconds': 250,
      'durationMilliseconds': 4000,
      'speed': 1,
    };

    await controller.requestSnapshot();
    await controller.play();
    await controller.pause();

    expect(bridge.snapshotCalls, 1);
    expect(bridge.playCalls, 1);
    expect(bridge.pauseCalls, 1);
    expect(controller.isReady, isTrue);
    expect(controller.position, const Duration(milliseconds: 250));
  });

  test('clamps seek positions to the media bounds', () async {
    bridge.emit({
      'ready': true,
      'playing': false,
      'positionMilliseconds': 5000,
      'durationMilliseconds': 10000,
      'speed': 1,
    });

    await controller.seek(const Duration(seconds: -2));
    await controller.seek(const Duration(seconds: 40));
    await controller.seekRelative(const Duration(seconds: -3));

    expect(bridge.seekPositions, [
      Duration.zero,
      const Duration(seconds: 10),
      const Duration(seconds: 7),
    ]);
    expect(controller.position, const Duration(seconds: 7));
  });

  test('clamps requested speed before sending it to the bridge', () async {
    await controller.setSpeed(0.1);
    await controller.setSpeed(3.5);
    await controller.setSpeed(1.234);

    expect(bridge.speeds, [0.5, 2.0, 1.23]);
    expect(controller.speed, 1.23);
  });

  test('clamps requested volume before sending it to the bridge', () async {
    await controller.setVolume(-1);
    await controller.setVolume(2);
    await controller.setVolume(0.234);

    expect(bridge.volumes, [0, 1, 0.23]);
    expect(controller.volume, 0.23);

    await controller.setVolume(double.nan);
    expect(bridge.volumes, [0, 1, 0.23]);
    expect(controller.playerError, '媒体音量无效');
  });

  test('configures, activates, and clears an A-B loop range', () async {
    bridge.emit({
      'ready': true,
      'playing': false,
      'positionMilliseconds': 2000,
      'durationMilliseconds': 10000,
      'speed': 1,
    });
    controller.setLoopStart();
    await controller.seek(const Duration(seconds: 6));

    expect(controller.setLoopEnd(), isTrue);
    expect(controller.setLoopEnabled(true), isTrue);
    expect(controller.loopController.range?.start, const Duration(seconds: 2));
    expect(controller.loopController.range?.end, const Duration(seconds: 6));

    await controller.activateLoopRange(
      LoopRange(
        start: const Duration(seconds: 3),
        end: const Duration(seconds: 5),
      ),
    );

    expect(controller.loopController.enabled, isTrue);
    expect(controller.position, const Duration(seconds: 3));
    expect(bridge.seekPositions.last, const Duration(seconds: 3));

    controller.clearLoop();
    expect(controller.loopController.range, isNull);
    expect(controller.loopController.enabled, isFalse);
  });

  test('seeks to A and resumes when playback reaches B', () async {
    await controller.activateLoopRange(
      LoopRange(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ),
    );
    bridge.seekPositions.clear();
    bridge.playCalls = 0;

    bridge.emit({
      'ready': true,
      'playing': true,
      'positionMilliseconds': 4000,
      'durationMilliseconds': 10000,
      'speed': 1,
    });
    await Future<void>.delayed(const Duration(milliseconds: 275));

    expect(bridge.seekPositions, [const Duration(seconds: 2)]);
    expect(bridge.playCalls, 1);
    expect(controller.loopController.completedLoops, 1);
  });

  test('turns bridge failures into a visible player error', () async {
    bridge.playError = StateError('platform view unavailable');

    await controller.play();

    expect(controller.playerError, contains('播放器操作失败'));
    expect(controller.playerError, contains('platform view unavailable'));
  });

  test('detaches the listener and disposes the bridge exactly once', () async {
    final staleListener = bridge.listener;

    controller.dispose();
    controller.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(bridge.listener, isNull);
    expect(bridge.disposeCalls, 1);

    staleListener?.call({
      'ready': true,
      'playing': true,
      'positionMilliseconds': 1000,
      'durationMilliseconds': 2000,
      'speed': 1,
    });
    expect(controller.isReady, isFalse);
  });

  test('does not resume an in-flight loop after disposal', () async {
    await controller.activateLoopRange(
      LoopRange(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 4),
      ),
    );
    bridge.seekPositions.clear();

    bridge.emit({
      'ready': true,
      'playing': true,
      'positionMilliseconds': 4000,
      'durationMilliseconds': 10000,
      'speed': 1,
    });
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 275));

    expect(bridge.playCalls, 0);
  });
}

final class _FakeLocalVideoPlayerBridge implements LocalVideoPlayerBridge {
  LocalVideoStateListener? listener;
  Map<String, Object?> snapshot = const {};
  Object? playError;
  int playCalls = 0;
  int pauseCalls = 0;
  int snapshotCalls = 0;
  int disposeCalls = 0;
  final List<Duration> seekPositions = [];
  final List<double> speeds = [];
  final List<double> volumes = [];

  void emit(Map<String, Object?> state) => listener?.call(state);

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    if (playError case final error?) throw error;
  }

  @override
  Future<void> requestSnapshot() async {
    snapshotCalls += 1;
    listener?.call(snapshot);
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  void setStateListener(LocalVideoStateListener? listener) {
    this.listener = listener;
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/bilibili_web_playback_controller.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

void main() {
  test(
    'accepts validated player snapshots and sends standard media commands',
    () async {
      final executor = _FakeJavaScriptExecutor();
      final controller = BilibiliWebPlaybackController(executor);

      controller.onJavaScriptMessage(
        jsonEncode({
          'event': 'ready',
          'position': 12.5,
          'duration': 90,
          'speed': 1.25,
          'volume': 0.36,
          'playing': true,
          'error': null,
        }),
      );

      expect(controller.bridgeReady, isTrue);
      expect(controller.position, const Duration(milliseconds: 12500));
      expect(controller.duration, const Duration(seconds: 90));
      expect(controller.speed, 1.25);
      expect(controller.volume, 0.36);
      expect(controller.isPlaying, isTrue);

      await controller.seek(const Duration(seconds: 20));
      await controller.setSpeed(1.237);
      await controller.setVolume(0.425);
      await controller.pause();

      expect(executor.scripts.join('\n'), contains('seek(20.0)'));
      expect(executor.scripts.join('\n'), contains('setSpeed(1.24)'));
      expect(controller.speed, 1.24);
      expect(controller.volume, 0.43);
      expect(executor.scripts.join('\n'), contains('pause()'));
      expect(executor.scripts.join('\n'), contains('setVolume(0.43)'));
      controller.dispose();
    },
  );

  test('ignores malformed and not-ready web messages', () {
    final controller = BilibiliWebPlaybackController(_FakeJavaScriptExecutor());

    controller.onJavaScriptMessage('not json');
    controller.onJavaScriptMessage(jsonEncode({'event': 'notReady'}));

    expect(controller.bridgeReady, isFalse);
    controller.dispose();
  });

  test('rejects a non-finite volume without invoking JavaScript', () async {
    final executor = _FakeJavaScriptExecutor();
    final controller = BilibiliWebPlaybackController(executor);

    await controller.setVolume(double.infinity);

    expect(executor.scripts, isEmpty);
    expect(controller.playerError, '媒体音量无效');
    controller.dispose();
  });

  test('activates a saved loop range and seeks to its start', () async {
    final executor = _FakeJavaScriptExecutor();
    final controller = BilibiliWebPlaybackController(executor);
    controller.onJavaScriptMessage(
      jsonEncode({
        'event': 'ready',
        'position': 0,
        'duration': 60,
        'speed': 1,
        'playing': false,
      }),
    );

    await controller.activateLoopRange(
      LoopRange(
        start: const Duration(seconds: 8),
        end: const Duration(seconds: 12),
      ),
    );

    expect(controller.loopController.start, const Duration(seconds: 8));
    expect(controller.loopController.end, const Duration(seconds: 12));
    expect(controller.loopController.enabled, isTrue);
    expect(executor.scripts.last, contains('seek(8.0)'));
    controller.dispose();
  });
}

class _FakeJavaScriptExecutor implements JavaScriptExecutor {
  final List<String> scripts = [];

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }
}

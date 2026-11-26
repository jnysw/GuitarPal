import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/youtube_playback_controller.dart';

void main() {
  test(
    'uses player-reported rates and repeats A–B without duplicate seeks',
    () async {
      final commands = <String>[];
      final player = YouTubePlaybackController(
        (script) async => commands.add(script),
      );
      addTearDown(player.dispose);

      void snapshot(double position, {int state = 1, double speed = 1}) {
        player.onMessage(
          jsonEncode({
            'type': 'snapshot',
            'position': position,
            'duration': 30,
            'state': state,
            'rate': speed,
            'rates': [1, .75, 1.5],
          }),
        );
      }

      snapshot(2);
      player.setA();
      expect(player.rates, [.75, 1, 1.5]);
      await player.setSpeed(.7);
      expect(commands.removeLast(), 'window.melpalYouTube?.speed(0.75)');
      expect(player.speed, 1);
      snapshot(5, speed: .75);
      expect(player.speed, .75);
      expect(player.setB(), isTrue);
      snapshot(4.9);
      expect(commands, isEmpty);
      snapshot(5.1);
      snapshot(5.2);
      expect(commands, ['window.melpalYouTube?.seek(2.0, false)']);
      expect(player.loop.totalCompletedLoops, 1);
      snapshot(2);
      snapshot(5.2, state: 2);
      expect(commands, hasLength(1));
      snapshot(30, state: 0);
      expect(commands.last, 'window.melpalYouTube?.seek(2.0, true)');
      expect(player.loop.totalCompletedLoops, 2);
      player.onMessage('{"type":"error","code":150}');
      expect(player.error, '作者关闭了嵌入播放');
      expect(player.canSeek, isFalse);
      await player.seek(Duration.zero);
      expect(commands, hasLength(2));
    },
  );
}

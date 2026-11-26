import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/video_audio_extractor.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

import 'support/video_analysis_fixture.dart';
import '../test/support/stem_flac_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'video extraction retains range coordinates; in-place stems share seek, speed, loop and original mute',
    (tester) async {
      const storage = AlgorithmStemPlatform();
      final stemRoot = await storage.directory();
      final videoRoot = Directory('${stemRoot.parent.path}/guitarpal_videos');
      await videoRoot.create(recursive: true);
      final video = File('${videoRoot.path}/integration-analysis.mp4');
      await video.writeAsBytes(base64Decode(videoAnalysisFixtureBase64));
      final extracted = await const VideoAudioExtractor().extract(
        video.path,
        1000,
        3000,
      );
      final input = File(extracted.input.path);
      final wave = ByteData.sublistView(
        Uint8List.fromList(await input.readAsBytes()),
      );
      expect(wave.getUint32(24, Endian.little), 16000);
      expect(wave.getUint16(22, Endian.little), 1);
      expect(extracted.input.duration.inMilliseconds, 2000);
      expect(wave.getUint32(40, Endian.little), 64000);
      expect(extracted.waveform.any((v) => v > .01), isTrue);
      expect(extracted.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      final stem = File('${stemRoot.path}/integration-video_guitar.wav');
      await input.copy(stem.path);
      final flac = File('${stemRoot.path}/integration-video_guitar.flac');
      await flac.writeAsBytes(base64Decode(stemFlacFixtureBase64));
      final created = Completer<int>();
      LocalVideoPlaybackController? controller;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 180,
                child: AndroidView(
                  viewType: 'com.guitarpal/local_video_player',
                  creationParams: {'path': video.path},
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: created.complete,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final id = await created.future.timeout(const Duration(seconds: 10));
        final channel = MethodChannel('com.guitarpal/local_video_player/$id');
        controller = LocalVideoPlaybackController(
          MethodChannelLocalVideoPlayerBridge(id),
        );
        await _wait(channel, (s) => s['ready'] == true);
        await controller.requestSnapshot();
        await controller.loadStems({'guitar': flac.path}, 1000, 2000);
        var state = await channel.invokeMapMethod<String, Object?>('snapshot');
        expect(state!['stemsActive'], isTrue);
        expect(state['videoAudioVolume'], 0.0);
        await controller.setSpeed(1.37);
        await controller.play();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['positionMilliseconds'], inInclusiveRange(1100, 2400));
        expect(
          ((state['videoPositionMilliseconds'] as num) -
                  (state['positionMilliseconds'] as num))
              .abs(),
          lessThan(400),
        );
        await controller.setStemGains({'guitar': .3});
        await controller.setStemPans({'guitar': -1});
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['stemPans'], {'guitar': -1.0});
        await expectLater(
          channel.invokeMethod('setStemPans', {
            'pans': {'guitar': 1.1},
          }),
          throwsA(isA<PlatformException>()),
        );
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['stemPans'], {
          'guitar': -1.0,
        }); // Bad control cannot replace valid state.
        await controller.setVolume(.65);
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['videoAudioVolume'], 0.0);
        await controller.pause();
        await controller.seek(const Duration(milliseconds: 3500));
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['stemsActive'], isFalse);
        expect(state['videoAudioVolume'] as num, closeTo(.65, .001));
        await controller.setSpeed(1);
        await controller.setStemPans({'guitar': 1});
        await controller.activateLoopRange(
          LoopRange(
            start: const Duration(milliseconds: 1500),
            end: const Duration(milliseconds: 2500),
          ),
        );
        await controller.play();
        await Future<void>.delayed(const Duration(milliseconds: 1900));
        expect(
          controller.loopController.totalCompletedLoops,
          greaterThanOrEqualTo(1),
        );
        expect(controller.stemsActive, isTrue);
        await controller.clearStems();
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['stemsLoaded'], isFalse);
        expect(state['videoAudioVolume'] as num, closeTo(.65, .001));
        expect(state['hasVideoFrame'], isTrue);
        controller.clearLoop();
        await controller.seek(const Duration(milliseconds: 3500));
        await controller.loadStems(
          {'guitar': stem.path},
          1000,
          2000,
          preservePosition: true,
          onlyIfPaused: true,
          initialGains: {'guitar': .21},
        );
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['positionMilliseconds'], closeTo(3500, 150));
        expect(
          state['stemsActive'],
          isFalse,
        ); // A restored range must not move a plan's position.
        expect(state['playing'], isFalse);
        await controller.clearStems();
        await controller.seek(const Duration(milliseconds: 4000));
        await controller.play();
        await _wait(channel, (s) => s['playing'] == true);
        await expectLater(
          controller.loadStems(
            {'guitar': stem.path},
            1000,
            2000,
            preservePosition: true,
            onlyIfPaused: true,
          ),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'restore_skipped',
            ),
          ),
        );
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['playing'], isTrue);
        expect(state['stemsLoaded'], isFalse);
        await controller.pause();
        await controller.loadStems({'lead_guitar': stem.path}, 1000, 2000);
        await controller.setStemGains({'lead_guitar': .63});
        await controller.setStemPans({'lead_guitar': .8});
        state = await channel.invokeMapMethod('snapshot');
        expect(state!['stemGains'], {'lead_guitar': .63});
        expect(state['stemPans'], {'lead_guitar': .8});
      } finally {
        await controller?.pause();
        controller?.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await const MethodChannelAlgorithmAudioImport().deleteInput(input.path);
        await AlgorithmStemStore(storage.directory)
            .deleteTask('integration-video');
        await video.delete();
      }
    },
  );
}

Future<void> _wait(
  MethodChannel channel,
  bool Function(Map<String, Object?>) ready,
) async {
  for (var i = 0; i < 100; i++) {
    final value = await channel.invokeMapMethod<String, Object?>('snapshot');
    if (value != null && ready(value)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException('Video did not become ready');
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/player/widgets/video_chord_playback_strip.dart';
import 'package:guitar_pal/features/player/widgets/video_stem_mixer.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';

void main() {
  testWidgets(
    'current chord updates without expanding tools or calibrating; seek and loop-back follow video time',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('gp_chord_strip_');
      final file = File('${dir.path}/video.mp4')..writeAsBytesSync([1]);
      final stat = file.statSync();
      final result = jsonDecode(
        File('contracts/legacy_algorithm/fixtures/chords_result.json')
            .readAsStringSync(),
      ) as Map<String, Object?>;
      final now = DateTime.now();
      final task = AlgorithmTaskRecord(
        id: 'task',
        endpoint: 'https://algorithm.example',
        inputPath: '/input',
        inputName: 'input.wav',
        inputSizeBytes: 1,
        inputDurationMs: 8000,
        ownsInput: true,
        state: AlgorithmTaskState.completed,
        createdAt: now,
        updatedAt: now,
        failures: 0,
        operation: AlgorithmOperation.chords,
        linkedSourceId: 's',
        resultJson: jsonEncode(result),
        mediaBindingJson: jsonEncode(
          VideoAnalysisBinding(
            sourceId: 's',
            path: file.path,
            sourceBytes: stat.size,
            modifiedMs: stat.modified.millisecondsSinceEpoch,
            sourceDurationMs: 8000,
            startMs: 0,
            durationMs: 8000,
            inputSha256: 'a' * 64,
            waveform: [],
          ).toJson(),
        ),
      );
      final bridge = _Bridge();
      final controller = LocalVideoPlaybackController(bridge);
      await controller.requestSnapshot();
      var calibrationOpened = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            algorithmTasksProvider.overrideWith((_) => Stream.value([task])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: VideoChordPlaybackStrip(
                    sourceId: 's',
                    path: file.path,
                    controller: controller,
                    onCalibrate: () => calibrationOpened = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前和弦 C'), findsOneWidget);
      expect(find.textContaining('静音偏移待校准'), findsOneWidget);
      await controller.seek(const Duration(milliseconds: 3250));
      await controller.setSpeed(1.37);
      await tester.pumpAndSettle();
      expect(find.text('当前和弦 Am'), findsOneWidget);
      await controller.seek(
        Duration.zero,
      ); // Same source-time path used for A-B wrap.
      await tester.pumpAndSettle();
      expect(find.text('当前和弦 C'), findsOneWidget);
      await tester.tap(find.text('校准'));
      await tester.pumpAndSettle();
      expect(calibrationOpened, isTrue);
      await controller.seek(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('当前和弦 —'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      dir.deleteSync(recursive: true);
    },
  );

  testWidgets(
    'mixer exposes only returned tracks and applies volume mute solo pan and reset',
    (tester) async {
      var controls = {
        'lead_guitar': const StemMixControl(),
        'bass': const StemMixControl(volume: .5),
      };
      var master = .8;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => VideoStemMixer(
                  controls: controls,
                  master: master,
                  enabled: true,
                  onMaster: (v) => update(() => master = v),
                  onChange: (id, c) =>
                      update(() => controls = {...controls, id: c}),
                  onReset: () => update(
                    () => controls = {
                      for (final id in controls.keys)
                        id: const StemMixControl(),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('video_stem_volume_vocals')), findsNothing);
      tester
          .widget<Slider>(
            find.byKey(const Key('video_stem_volume_lead_guitar')),
          )
          .onChanged!(.63);
      await tester.pump();
      expect(controls['lead_guitar']!.volume, .63);
      tester
          .widget<FilterChip>(
            find.byKey(const Key('video_stem_solo_lead_guitar')),
          )
          .onSelected!(true);
      await tester.pump();
      expect(controls['lead_guitar']!.solo, isTrue);
      tester
          .widget<Slider>(find.byKey(const Key('video_stem_pan_bass')))
          .onChanged!(-1);
      await tester.pump();
      expect(controls['bass']!.pan, -1);
      await tester.tap(find.text('重置音轨'));
      await tester.pump();
      expect(
        controls.values.every(
          (c) => c.volume == 1 && !c.solo && !c.muted && c.pan == 0,
        ),
        isTrue,
      );
    },
  );
}

class _Bridge implements LocalVideoPlayerBridge {
  LocalVideoStateListener? listener;
  int position = 0;
  @override
  void setStateListener(LocalVideoStateListener? l) => listener = l;
  @override
  Future<void> requestSnapshot() async => listener?.call({
    'ready': true,
    'playing': false,
    'durationMilliseconds': 8000,
    'positionMilliseconds': position,
    'speed': 1.0,
    'volume': 1.0,
  });
  @override
  Future<void> seek(Duration p) async {
    position = p.inMilliseconds;
    await requestSnapshot();
  }

  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

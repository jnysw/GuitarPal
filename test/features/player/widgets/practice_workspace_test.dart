import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/practice_workspace.dart';
import 'package:guitar_pal/features/player/widgets/precise_playback_speed_control.dart';
import 'package:guitar_pal/features/player/widgets/playback_volume_control.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';

void main() {
  Future<LocalVideoPlaybackController> ready() async {
    final c = LocalVideoPlaybackController(_Bridge());
    await c.requestSnapshot();
    return c;
  }

  Widget app(
    LocalVideoPlaybackController controller, {
    Widget? audio,
    bool recording = false,
    Size? workspaceSize,
    double scale = 1,
    double bottomInset = 0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: workspaceSize?.width ?? 360,
              height: workspaceSize?.height ?? 560,
              child: StatefulBuilder(
                builder: (context, update) {
                  // The owning route controls the active section independently of playback.
                  return _Harness(
                    controller: controller,
                    audio: audio,
                    recording: recording,
                    keyboardVisible: bottomInset > 0,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'switching tools preserves panel state and keeps progress and play reachable after scrolling',
    (tester) async {
      final c = await ready();
      var mounts = 0;
      await tester.pumpWidget(app(c, audio: _Probe(onMount: () => mounts++)));
      await tester.pumpAndSettle();
      expect(mounts, 1);
      await tester.tap(find.byKey(const Key('practice_section_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('layout_draft')),
        'keep this draft',
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('local_video_play_pause')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('local_video_position_slider')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('practice_section_3')));
      await tester.pumpAndSettle();
      expect(find.text('我的练习片段'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice_section_1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('layout_draft')))
            .controller!
            .text,
        'keep this draft',
      );
      expect(mounts, 1);
      expect(c.position, Duration.zero);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'speed and volume sheets use the shared controller and retain exact loop points',
    (tester) async {
      final c = await ready();
      await c.seek(const Duration(milliseconds: 12250));
      c.setLoopStart();
      await c.seek(const Duration(milliseconds: 22500));
      c.setLoopEnd();
      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();
      expect(find.text('0:12.25'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice_speed_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PrecisePlaybackSpeedControlKeys.input),
        '1.37',
      );
      await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
      await tester.pumpAndSettle();
      expect(c.speed, 1.37);
      expect(c.loopController.range!.start.inMilliseconds, 12250);
      await tester.tap(find.byTooltip('关闭播放设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice_volume_settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PlaybackVolumeControlKeys.mute));
      await tester.pumpAndSettle();
      expect(c.volume, 0);
      expect(c.loopController.range!.end.inMilliseconds, 22500);
      expect(c.position.inMilliseconds, 22500);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'keyboard on a short viewport keeps the mounted draft and restores transport',
    (tester) async {
      final c = await ready();
      var mounts = 0;
      final audio = _Probe(onMount: () => mounts++);
      await tester.pumpWidget(
        app(c, audio: audio, workspaceSize: const Size(320, 320)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice_section_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('layout_draft')),
        'draft before keyboard',
      );
      await tester.pumpWidget(
        app(
          c,
          audio: audio,
          workspaceSize: const Size(320, 180),
          bottomInset: 280,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('local_video_position_slider')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('layout_draft')))
            .controller!
            .text,
        'draft before keyboard',
      );
      await tester.pumpWidget(
        app(c, audio: audio, workspaceSize: const Size(320, 320)),
      );
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(
        find.byKey(const Key('local_video_position_slider')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'scrolling audio cannot collide with a newly inserted expansion card',
    (tester) async {
      final c = await ready();
      final expanded = ValueNotifier(false);
      final audio = ValueListenableBuilder<bool>(
        valueListenable: expanded,
        builder: (context, show, _) => Column(
          children: [
            const SizedBox(height: 900),
            if (show)
              const ExpansionTile(
                title: Text('new mixer details'),
                children: [Text('mixer values')],
              ),
          ],
        ),
      );
      await tester.pumpWidget(app(c, audio: audio));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice_section_1')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expanded.value = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('new mixer details'));
      await tester.tap(find.text('new mixer details'));
      await tester.pumpAndSettle();
      expect(find.text('mixer values'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      expanded.dispose();
    },
  );
  testWidgets('recording workflow keeps the active recording pane visible', (
    tester,
  ) async {
    final c = await ready();
    await tester.pumpWidget(app(c, recording: true));
    await tester.pumpAndSettle();
    expect(find.text('recording panel'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_section_0')));
    await tester.pumpAndSettle();
    expect(find.text('recording panel'), findsOneWidget);
    expect(find.text('反复练好这一段'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    '320px large text leaves transport and tools usable without overflow',
    (tester) async {
      final c = await ready();
      await tester.pumpWidget(
        app(c, workspaceSize: const Size(320, 320), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('local_video_play_pause')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('practice_section_3')));
      await tester.pumpAndSettle();
      expect(find.text('我的练习片段'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    this.audio,
    this.recording = false,
    this.keyboardVisible = false,
  });
  final LocalVideoPlaybackController controller;
  final Widget? audio;
  final bool recording, keyboardVisible;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int section = widget.recording ? 2 : 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PracticeWorkspace(
      controller: widget.controller,
      segments: const AsyncData([]),
      selectedSection: section,
      onSelectSection: (v) => setState(() => section = v),
      recordingActive: widget.recording,
      keyboardVisible: widget.keyboardVisible,
      recordingPanel: const Text('recording panel'),
      analysisPanel: widget.audio,
      onSaveSegment: () {},
      onActivateSegment: (_) {},
      onEditSegment: (_) {},
      onDeleteSegment: (_) {},
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final text = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(key: const Key('layout_draft'), controller: text),
      const SizedBox(height: 900),
      const Text('bottom of audio'),
    ],
  );
}

class _Bridge implements LocalVideoPlayerBridge {
  LocalVideoStateListener? listener;
  int position = 0;
  double speed = 1, volume = 1;
  @override
  void setStateListener(LocalVideoStateListener? l) => listener = l;
  @override
  Future<void> requestSnapshot() async => listener?.call({
    'ready': true,
    'playing': false,
    'hasVideoFrame': true,
    'durationMilliseconds': 30000,
    'positionMilliseconds': position,
    'speed': speed,
    'volume': volume,
  });
  @override
  Future<void> seek(Duration p) async {
    position = p.inMilliseconds;
    await requestSnapshot();
  }

  @override
  Future<void> setSpeed(double s) async {
    speed = s;
    await requestSnapshot();
  }

  @override
  Future<void> setVolume(double v) async {
    volume = v;
    await requestSnapshot();
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

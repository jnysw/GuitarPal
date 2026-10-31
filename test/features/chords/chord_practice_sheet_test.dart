import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/chords/chord_providers.dart';
import 'package:guitar_pal/features/chords/data/chord_preferences.dart';
import 'package:guitar_pal/features/chords/domain/chord_library.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_chord_playback.dart';
import 'package:guitar_pal/features/player/widgets/chord_practice_sheet.dart';
import 'package:guitar_pal/features/player/widgets/guitar_chord_diagram.dart';
import 'package:guitar_pal/media/playback/local_video_playback_controller.dart';

void main() {
  final library = GuitarChordLibrary.decode(
    File('assets/chords/standard_guitar_v1.json').readAsStringSync(),
  );
  final playback = VideoChordPlayback(
    LegacyChordResult.fromJson({
      'job_id': 'test',
      'status': 'completed',
      'duration_seconds': 8,
      'key': 'C',
      'progression': 'C–Am',
      'segments': [
        {'chord': 'C:maj', 'roman': 'I', 'start': 0, 'end': 4},
        {'chord': 'A:min', 'roman': 'vi', 'start': 4, 'end': 8},
      ],
    }),
    VideoAnalysisBinding(
      sourceId: 's',
      path: '/video',
      sourceBytes: 1,
      modifiedMs: 1,
      sourceDurationMs: 8000,
      startMs: 0,
      durationMs: 8000,
      inputSha256: 'a' * 64,
      waveform: [],
    ),
  );
  Widget app(Widget child, _Store store, {double scale = 1}) => ProviderScope(
    key: UniqueKey(),
    overrides: [
      chordPreferencesStoreProvider.overrideWithValue(store),
      guitarChordLibraryProvider.overrideWith((_) async => library),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child),
      ),
    ),
  );
  testWidgets(
    'global display, left hand and preferred voicing survive a new provider scope; clock updates chord',
    (tester) async {
      final store = _Store();
      final bridge = _Bridge();
      final controller = LocalVideoPlaybackController(bridge);
      await controller.requestSnapshot();
      await tester.pumpWidget(
        app(
          ChordPracticeSheet(playback: playback, controller: controller),
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('chord_show_diagrams')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('chord_show_diagrams')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chord_left_handed')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('chord_next_voicing')));
      await tester.tap(find.byKey(const Key('chord_next_voicing')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      expect(
        tester
            .widget<GuitarChordDiagram>(find.byType(GuitarChordDiagram))
            .leftHanded,
        isTrue,
      );
      expect(store.value.showDiagrams, isTrue);
      expect(store.value.preferred['0:maj'], library.lookup('C')[1].id);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('推荐指法，标准定弦，左手显示，6弦')),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.pumpWidget(
        app(
          ChordPracticeSheet(playback: playback, controller: controller),
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      await controller.seek(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('推荐指法 · Am'), findsOneWidget);
      expect(find.text('推荐指法 · C'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'missing and unknown chords never show a made up diagram; removed voicing ID falls back',
    (tester) async {
      final store = _Store()
        ..value = ChordPreferences(preferred: {'0:maj': 'removed-library-id'});
      for (final raw in ['C:13', 'C:dim/E', 'X', 'N']) {
        await tester.pumpWidget(
          app(ChordVoicingCard(rawLabel: raw, displayLabel: raw), store),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GuitarChordDiagram), findsNothing);
      }
      await tester.pumpWidget(
        app(const ChordVoicingCard(rawLabel: 'C', displayLabel: 'C'), store),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chord_favorite_voicing')));
      await tester.pumpAndSettle();
      expect(store.value.preferred['0:maj'], library.lookup('C').first.id);
      await tester.tap(find.byKey(const Key('chord_favorite_voicing')));
      await tester.pumpAndSettle();
      expect(store.value.preferred, isEmpty);
    },
  );
  testWidgets(
    'small screen with large text can scroll to every setting and license without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store();
      final controller = LocalVideoPlaybackController(_Bridge());
      await controller.requestSnapshot();
      await tester.pumpWidget(
        app(
          ChordPracticeSheet(playback: playback, controller: controller),
          store,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('数据来源与 MIT 许可'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('数据来源与 MIT 许可'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Copyright (c) 2016 David Rubert'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'thumbnail keeps missing voicing and loading states bounded beside video controls',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 240,
            child: Row(
              children: [
                Expanded(child: Text('当前和弦 C13')),
                ChordVoicingCard(
                  rawLabel: 'C:13',
                  displayLabel: 'C13',
                  thumbnail: true,
                  compact: true,
                ),
                Icon(Icons.play_arrow),
              ],
            ),
          ),
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无指法'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed preference save offers retry and keeps current display usable',
    (tester) async {
      final store = _Store()..fail = true;
      await tester.pumpWidget(
        app(const ChordVoicingCard(rawLabel: 'C', displayLabel: 'C'), store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chord_next_voicing')));
      await tester.pumpAndSettle();
      expect(find.text('指法设置保存失败，本次显示仍有效'), findsOneWidget);
      store.fail = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(store.value.preferred['0:maj'], library.lookup('C')[1].id);
    },
  );
}

class _Store extends ChordPreferencesStore {
  _Store() : super(() async => Directory.systemTemp);
  ChordPreferences value = ChordPreferences();
  bool fail = false;
  @override
  Future<ChordPreferences> load() async => value;
  @override
  Future<void> save(ChordPreferences p) async {
    if (fail) throw const FileSystemException('test write failure');
    value = p;
  }
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
  Future<void> setSpeed(double s) async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

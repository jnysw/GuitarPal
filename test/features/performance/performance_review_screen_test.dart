import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/performance/data/performance_take_store.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';
import 'package:guitar_pal/features/performance/performance_resolver_providers.dart';
import 'package:guitar_pal/features/performance/performance_take_providers.dart';
import 'package:guitar_pal/features/performance/performance_review_screen.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_review_test.dart' show TakeResolver;
import 'performance_stage_controller_test.dart' show StagePlayer, StageStore;

void main() {
  testWidgets(
    'narrow large text can audition and save once without changing raw audio',
    (tester) async {
      final f = (await tester.runAsync(() => _Fixture.create()))!;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(f.app(scale: 2));
        await tester.tap(find.text('打开回听'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_review_play')),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('performance_review_play')));
        await tester.pump();
        expect(f.mic.playing, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_take_save')),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('performance_take_save')));
        await _until(
          tester,
          () => find.text('演奏已保存，可以从同曲演奏录音再次回听').evaluate().isNotEmpty,
        );
        expect(f.repo.rows.length, 1);
        expect(f.mic.files, contains(f.take.filePath));
        expect(f.mic.playing, isFalse);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_take_export')),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_take_export')));
        await tester.pumpAndSettle();
        expect(find.text('导出演奏音频'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_render')),
          140,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('performance_export_render')),
          findsOneWidget,
        );
        expect(f.repo.rows.length, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'dragging the review timeline seeks once on release and keeps playback running',
    (tester) async {
      final f = (await tester.runAsync(() => _Fixture.create(trial: true)))!;
      try {
        await tester.pumpWidget(f.app());
        await tester.tap(find.text('打开回听'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_review_play')));
        await tester.pumpAndSettle();
        final pauses = f.mic.pauses;
        final slider = find.byKey(const Key('performance_review_position'));
        await tester.ensureVisible(slider);
        final rect = tester.getRect(slider);
        final gesture = await tester.startGesture(
          Offset(rect.left + 24, rect.center.dy),
        );
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(40, 0));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(f.mic.pauses, pauses);
        expect(f.mic.position, 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(f.mic.pauses, pauses + 1);
        expect(f.mic.position, greaterThan(0));
        expect(f.mic.playing, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'export can save current edits and continue, but a failed save stays in review',
    (tester) async {
      final f = (await tester.runAsync(() => _Fixture.create()))!;
      Future<void> tapKey(String key) async {
        await tester.scrollUntilVisible(
          find.byKey(Key(key)),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      try {
        await tester.pumpWidget(f.app());
        await tester.tap(find.text('打开回听'));
        await tester.pumpAndSettle();
        await tapKey('performance_take_save');
        await _until(
          tester,
          () => find.text('演奏已保存，可以从同曲演奏录音再次回听').evaluate().isNotEmpty,
        );
        await tester.enterText(find.byType(TextField), '更新后的演奏');
        f.repo.fail = true;
        await tapKey('performance_take_export');
        expect(find.text('保存调整并继续？'), findsOneWidget);
        await tester.tap(find.text('保存并继续'));
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find.text('保存未完成，草稿与原始录音仍保留，请重试').evaluate().isNotEmpty,
        );
        expect(
          find.byKey(const Key('performance_export_render')),
          findsNothing,
        );
        f.repo.fail = false;
        await tapKey('performance_take_export');
        await tester.tap(find.text('保存并继续'));
        await tester.pumpAndSettle();
        await _until(tester, () => find.text('导出演奏音频').evaluate().isNotEmpty);
        expect(f.repo.rows.length, 1);
        expect(f.repo.rows.values.single.title, '更新后的演奏');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.close);
      }
    },
  );
  testWidgets(
    'unsaved exit is explicit and trial can be discarded without becoming a performance',
    (tester) async {
      final f = (await tester.runAsync(() => _Fixture.create(trial: true)))!;
      try {
        await tester.pumpWidget(f.app());
        await tester.tap(find.text('打开回听'));
        await tester.pumpAndSettle();
        await _until(
          tester,
          () => find
              .byKey(const Key('performance_take_discard'))
              .evaluate()
              .isNotEmpty,
        );
        expect(find.byKey(const Key('performance_take_save')), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('录音尚未保存为成果'), findsOneWidget);
        await tester.tap(find.text('继续回听'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('performance_take_discard')),
        );
        await tester.tap(find.byKey(const Key('performance_take_discard')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('丢弃'));
        await _until(tester, () => find.text('打开回听').evaluate().isNotEmpty);
        expect(f.repo.rows, isEmpty);
        expect(f.mic.files, isEmpty);
        expect(await tester.runAsync(() => f.store.load(f.take.id)), isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.close);
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Review not ready');
}

class _Fixture {
  _Fixture(this.root, this.take, this.resolver);
  final Directory root;
  final PerformanceTake take;
  final TakeResolver resolver;
  final mic = _CountingMic();
  final player = StagePlayer();
  final repo = MemoryPerformanceRecordings();
  late final store = PerformanceTakeStore(() async => root);
  static Future<_Fixture> create({bool trial = false}) async {
    final root = await Directory.systemTemp.createTemp('gp_take_ui_');
    final c = fixtureCandidate(root);
    final take = PerformanceTake.begin(
      'ui-take',
      c,
      BackingPreset.forCandidate(c, {'bass'}),
      trial: trial,
    ).update({'durationMs': 2000, 'endSourceMs': 4000, 'leadMs': 0});
    final f = _Fixture(root, take, TakeResolver(c));
    f.mic.files.add(take.filePath);
    await f.store.save(take);
    return f;
  }

  Widget app({double scale = 1}) => ProviderScope(
    overrides: [
      practiceAudioRecorderProvider.overrideWithValue(mic),
      performanceAudioProvider.overrideWithValue(FakePerformanceAudio(mic)),
      performanceTakeStoreProvider.overrideWithValue(store),
      practiceRecordingRepositoryProvider.overrideWithValue(repo),
      algorithmMixPlatformProvider.overrideWithValue(player),
      algorithmStemStoreProvider.overrideWithValue(StageStore(root)),
      performanceSourceResolverProvider.overrideWithValue(resolver),
    ],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute<void>(
                builder: (_) => PerformanceReviewScreen(take: take),
              ),
            ),
            child: const Text('打开回听'),
          ),
        ),
      ),
    ),
  );
  Future<void> close() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await player.meter.close();
    await repo.changes.close();
    await root.delete(recursive: true);
  }
}

class _CountingMic extends FakePerformanceMic {
  int pauses = 0;
  @override
  Future<void> pausePlayback() async {
    pauses++;
    await super.pausePlayback();
  }
}

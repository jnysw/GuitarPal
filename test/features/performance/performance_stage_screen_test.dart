import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart'
    as domain;
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/performance/application/performance_source_resolver.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/performance_resolver_providers.dart';
import 'package:guitar_pal/features/plans/application/practice_session_service.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/performance/performance_stage_screen.dart';

import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_stage_controller_test.dart'
    show StagePlayer, StageStore, StageSessions;

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('stage fits $size at 2x text with reduced motion', (
      tester,
    ) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(f.app(scale: 2, reduced: true));
        await _until(
          tester,
          () => find.text('伴奏就绪，轮到你上台了').evaluate().isNotEmpty,
        );
        expect(f.player.plays, 0);
        await tester.ensureVisible(find.byKey(const Key('stage_play')));
        await tester.tap(find.byKey(const Key('stage_play')));
        await _until(tester, () => f.player.playing);
        f.player.emit(left: .4, right: .3);
        await tester.pump(const Duration(milliseconds: 150));
        final speaker = tester.widget<StageSpeaker>(
          find.byKey(const Key('stage_left_speaker')),
        );
        expect(speaker.enabled, isFalse);
        expect(speaker.level, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('舞台设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('舞台动效'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.runAsync(f.close);
      }
    });
  }
  testWidgets(
    'speaker responds to real meter events and settings disable motion',
    (tester) async {
      final f = (await tester.runAsync(_Fixture.create))!;
      try {
        await tester.pumpWidget(f.app());
        await _until(
          tester,
          () => find.text('伴奏就绪，轮到你上台了').evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(const Key('stage_play')));
        await _until(tester, () => f.player.playing);
        f.player.emit(left: .4, right: .3);
        await tester.pump(const Duration(milliseconds: 100));
        var speaker = tester.widget<StageSpeaker>(
          find.byKey(const Key('stage_left_speaker')),
        );
        expect(speaker.enabled, isTrue);
        expect(speaker.level, greaterThan(0));
        await tester.tap(find.byTooltip('舞台设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.widgetWithText(SwitchListTile, '舞台动效'));
        await tester.pump();
        await tester.tap(find.text('完成'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        speaker = tester.widget<StageSpeaker>(
          find.byKey(const Key('stage_left_speaker')),
        );
        expect(speaker.enabled, isFalse);
        expect(speaker.level, 0);
        expect(f.player.playing, isTrue);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await _until(tester, () => !f.player.playing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(f.player.playing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.runAsync(f.close);
      }
    },
  );
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail(
    'Stage not ready: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
  );
}

class _Fixture {
  _Fixture(this.root, this.backing);
  final Directory root;
  final PerformanceBacking backing;
  final player = StagePlayer();
  static Future<_Fixture> create() async {
    final root = await Directory.systemTemp.createTemp('gp_stage_ui_');
    final c = fixtureCandidate(root);
    final now = DateTime.now();
    final source = domain.PracticeSource(
      id: 'source',
      platform: domain.SourcePlatform.local,
      kind: domain.SourceKind.video,
      title: '我的演奏歌曲',
      canonicalUri: File(c.binding.path).uri,
      createdAt: now,
      updatedAt: now,
    );
    return _Fixture(
      root,
      PerformanceBacking(
        source,
        c,
        BackingPreset.forCandidate(
          c,
          performanceBackingTracks(c.result, omitGuitar: true),
        ),
      ),
    );
  }

  Widget app({double scale = 1, bool reduced = false}) => ProviderScope(
    overrides: [
      performanceSourceResolverProvider.overrideWithValue(_Resolver()),
      algorithmTasksProvider.overrideWith((ref) => Stream.value(const [])),
      practiceSessionServiceProvider.overrideWithValue(
        PracticeSessionService(StageSessions()),
      ),
      algorithmMixPlatformProvider.overrideWithValue(player),
      algorithmStemStoreProvider.overrideWithValue(StageStore(root)),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: PerformanceStageScreen(backing: backing),
      ),
    ),
  );
  Future<void> close() async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await player.meter.close();
    await root.delete(recursive: true);
  }
}

class _Resolver implements PerformanceSourceResolver {
  @override
  Future<void> verify(PerformanceCandidate candidate) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

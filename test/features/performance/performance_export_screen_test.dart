import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/performance/data/performance_export_platform.dart';
import 'package:guitar_pal/features/performance/application/performance_export_service.dart';
import 'package:guitar_pal/features/performance/domain/backing_preset.dart';
import 'package:guitar_pal/features/performance/domain/performance_take.dart';
import 'package:guitar_pal/features/performance/performance_export_screen.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_backing_test.dart' show fixtureCandidate;
import 'performance_review_test.dart' show TakeResolver;
import 'performance_stage_controller_test.dart' show StageStore;

class _Platform extends PerformanceExportPlatform {
  int renders = 0, cancels = 0, saves = 0, shares = 0;
  Completer<PerformanceExportResult>? pending;
  bool cancelCompletes = false, playing = false;
  Completer<Map<String, Object?>>? snapshotGate;
  final savedIds = <String>[];
  @override
  Future<PerformanceExportResult> render(Map<String, Object?> m) async {
    renders++;
    return pending == null
        ? const PerformanceExportResult(
            id: 'output',
            bytes: 176444,
            durationMs: 1000,
            attenuation: .5,
          )
        : pending!.future;
  }

  @override
  Future<Map<String, Object?>> snapshot() async {
    final gate = snapshotGate;
    snapshotGate = null;
    return gate != null
        ? gate.future
        : {'progress': .3, 'stage': '正在合成', 'playing': playing};
  }

  @override
  Future<void> play(String id) async {
    playing = true;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> discard(String id) async {}
  @override
  Future<void> cancel() async {
    cancels++;
    if (cancelCompletes && pending != null && !pending!.isCompleted) {
      pending!.completeError(
        PlatformException(code: 'cancelled', message: '导出已取消'),
      );
    }
  }

  @override
  Future<bool> save(String id, String title) async {
    saves++;
    savedIds.add(id);
    return true;
  }

  @override
  Future<void> share(String id) async {
    shares++;
  }
}

void main() {
  testWidgets(
    'explicit confirmation generates then saves/shares with large text and no auto export',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('gp_export_screen_');
      final c = fixtureCandidate(root);
      final take = PerformanceTake.begin(
        'take',
        c,
        BackingPreset.forCandidate(c, {'bass'}),
        trial: false,
      ).update({'durationMs': 1000, 'endSourceMs': 3000});
      final mic = FakePerformanceMic()..files.add(take.filePath);
      final platform = _Platform();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceExportPlatformProvider.overrideWithValue(platform),
              performanceExportServiceProvider.overrideWithValue(
                PerformanceExportService(
                  mic,
                  StageStore(root),
                  TakeResolver(c),
                  platform,
                ),
              ),
            ],
            child: MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: PerformanceExportScreen(take: take, title: '我的演奏'),
            ),
          ),
        );
        expect(platform.renders, 0);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_render')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_render')));
        await tester.pumpAndSettle();
        expect(platform.renders, 1);
        expect(platform.saves, 0);
        expect(platform.shares, 0);
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_save')),
          180,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_save')));
        await tester.pumpAndSettle();
        expect(platform.saves, 1);
        Future<void> tapKey(String key) async {
          await tester.scrollUntilVisible(find.byKey(Key(key)), 180);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }

        await tapKey('performance_export_render');
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tapKey('performance_export_restore');
        expect(platform.renders, 1);
        expect(find.text('已保存到文件'), findsOneWidget);
        expect(find.text('我的演奏 + 本次伴奏'), findsOneWidget);

        await tapKey('performance_export_render');
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        platform.pending = Completer<PerformanceExportResult>();
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_render')),
          180,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_render')));
        await tester.pump();
        platform.pending!.completeError(
          PlatformException(code: 'export_failed', message: '生成失败'),
        );
        await tester.pumpAndSettle();
        await tapKey('performance_export_restore');
        expect(platform.renders, 2);
        expect(find.text('已保存到文件'), findsOneWidget);
        await tapKey('performance_export_save');
        expect(platform.savedIds, ['output', 'output']);

        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_share')),
          180,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_share')));
        await tester.pumpAndSettle();
        expect(platform.shares, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        root.deleteSync(recursive: true);
      }
    },
  );
  testWidgets(
    'a delayed playback snapshot cannot turn the stop button back on after pausing',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('gp_export_poll_');
      final c = fixtureCandidate(root);
      final take = PerformanceTake.begin(
        'take',
        c,
        BackingPreset.forCandidate(c, {'bass'}),
        trial: false,
      ).update({'durationMs': 1000, 'endSourceMs': 3000});
      final mic = FakePerformanceMic()..files.add(take.filePath);
      final platform = _Platform();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceExportPlatformProvider.overrideWithValue(platform),
              performanceExportServiceProvider.overrideWithValue(
                PerformanceExportService(
                  mic,
                  StageStore(root),
                  TakeResolver(c),
                  platform,
                ),
              ),
            ],
            child: MaterialApp(
              home: PerformanceExportScreen(take: take, title: '回放状态验证'),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('performance_export_render')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('回听导出音频'));
        await tester.pump();
        final gate = Completer<Map<String, Object?>>();
        platform.snapshotGate = gate;
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.text('停止回听'));
        await tester.pump();
        gate.complete({'playing': true});
        await tester.pump();
        expect(find.text('回听导出音频'), findsOneWidget);
        expect(find.text('停止回听'), findsNothing);
        expect(platform.playing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        root.deleteSync(recursive: true);
      }
    },
  );
  testWidgets(
    'back during generation allows continuing or explicitly stopping before leaving',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('gp_export_leave_');
      final c = fixtureCandidate(root);
      final take = PerformanceTake.begin(
        'take',
        c,
        BackingPreset.forCandidate(c, {'bass'}),
        trial: false,
      ).update({'durationMs': 1000, 'endSourceMs': 3000});
      final mic = FakePerformanceMic()..files.add(take.filePath);
      final platform = _Platform()
        ..pending = Completer()
        ..cancelCompletes = true;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceExportPlatformProvider.overrideWithValue(platform),
              performanceExportServiceProvider.overrideWithValue(
                PerformanceExportService(
                  mic,
                  StageStore(root),
                  TakeResolver(c),
                  platform,
                ),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PerformanceExportScreen(take: take, title: '返回验证'),
                      ),
                    ),
                    child: const Text('打开导出'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开导出'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_render')));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('停止生成并返回？'), findsOneWidget);
        await tester.tap(find.text('继续生成'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(platform.cancels, 0);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('停止并返回'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('打开导出'), findsOneWidget);
        expect(platform.cancels, greaterThan(0));
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        root.deleteSync(recursive: true);
      }
    },
  );
  testWidgets(
    'background interrupts render and late completion never exposes a stale save action',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('gp_export_bg_');
      final c = fixtureCandidate(root);
      final take = PerformanceTake.begin(
        'take',
        c,
        BackingPreset.forCandidate(c, {'bass'}),
        trial: false,
      ).update({'durationMs': 1000, 'endSourceMs': 3000});
      final mic = FakePerformanceMic()..files.add(take.filePath);
      final platform = _Platform()..pending = Completer();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceExportPlatformProvider.overrideWithValue(platform),
              performanceExportServiceProvider.overrideWithValue(
                PerformanceExportService(
                  mic,
                  StageStore(root),
                  TakeResolver(c),
                  platform,
                ),
              ),
            ],
            child: MaterialApp(
              home: PerformanceExportScreen(take: take, title: '中断验证'),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_export_render')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_export_render')));
        await tester.pump();
        expect(platform.renders, 1);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        platform.pending!.complete(
          const PerformanceExportResult(
            id: 'late',
            bytes: 176444,
            durationMs: 1000,
            attenuation: 1,
          ),
        );
        await tester.pump();
        expect(platform.cancels, greaterThan(0));
        expect(find.byKey(const Key('performance_export_save')), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        root.deleteSync(recursive: true);
      }
    },
  );
}

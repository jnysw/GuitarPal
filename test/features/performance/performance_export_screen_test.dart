import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
  Future<Map<String, Object?>> snapshot() async => {
    'progress': .3,
    'stage': '正在合成',
    'playing': false,
  };
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<bool> save(String id, String title) async {
    saves++;
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

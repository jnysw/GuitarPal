import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/performance/performance_comparison_screen.dart';
import 'package:guitar_pal/features/performance/performance_take_providers.dart';

import '../../support/performance_audio_fakes.dart';
import 'performance_comparison_test.dart' show comparisonFixture;

void main() {
  testWidgets(
    'narrow large text supports choosing B and lifecycle pause without writes',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('gp_compare_ui_');
      final pair = comparisonFixture(root);
      final mic = FakePerformanceMic()
        ..files.addAll([pair.first.take.filePath, pair.second.take.filePath]);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              practiceAudioRecorderProvider.overrideWithValue(mic),
              performanceAudioProvider.overrideWithValue(
                FakePerformanceAudio(mic),
              ),
            ],
            child: MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: PerformanceComparisonScreen(comparison: pair),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_compare_1')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_compare_1')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('performance_compare_play')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('performance_compare_play')));
        await tester.pump();
        expect(mic.playbackPath, pair.second.take.filePath);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(mic.playing, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(mic.playing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        root.deleteSync(recursive: true);
      }
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/performance/performance_stage_screen.dart';

void main() {
  testWidgets(
    'constant measured energy keeps the cone moving, while silence and disabled motion stop it',
    (tester) async {
      Widget scene(double level, bool enabled) => MaterialApp(
        home: Center(
          child: StageSpeaker(
            level: level,
            peak: .4,
            enabled: enabled,
            label: '左音响',
          ),
        ),
      );
      await tester.pumpWidget(scene(.6, true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      final a = tester
          .widget<Transform>(find.byKey(const ValueKey('左音响_cone')))
          .transform
          .entry(0, 0);
      await tester.pump(const Duration(milliseconds: 35));
      final b = tester
          .widget<Transform>(find.byKey(const ValueKey('左音响_cone')))
          .transform
          .entry(0, 0);
      expect(a, isNot(closeTo(b, .001)));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('左音响_meter')),
            )
            .value,
        .6,
      );
      await tester.pumpWidget(scene(0, true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('左音响_cone')))
            .transform
            .entry(0, 0),
        1,
      );
      await tester.pumpWidget(scene(.6, false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('左音响_cone')))
            .transform
            .entry(0, 0),
        1,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('左音响_meter')),
            )
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

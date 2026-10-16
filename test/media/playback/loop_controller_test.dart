import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/playback/loop_controller.dart';

void main() {
  test('validates loop ranges', () {
    expect(
      () => LoopRange(
        start: const Duration(seconds: 4),
        end: const Duration(seconds: 4),
      ),
      throwsArgumentError,
    );
  });

  test('seeks to A near B and counts completed loops', () {
    final controller = LoopController(
      tolerance: const Duration(milliseconds: 150),
    )..setStart(const Duration(seconds: 2));
    expect(controller.setEnd(const Duration(seconds: 5)), isTrue);
    expect(controller.setEnabled(true), isTrue);

    expect(
      controller.seekTargetFor(const Duration(milliseconds: 4800)),
      isNull,
    );
    expect(
      controller.seekTargetFor(const Duration(milliseconds: 4860)),
      const Duration(seconds: 2),
    );
    expect(controller.completedLoops, 1);
  });

  test('counts an end crossing once until playback returns below B', () {
    final controller =
        LoopController(tolerance: const Duration(milliseconds: 150))..setRange(
          LoopRange(
            start: const Duration(seconds: 2),
            end: const Duration(seconds: 5),
          ),
        );

    expect(
      controller.seekTargetFor(const Duration(milliseconds: 4900)),
      const Duration(seconds: 2),
    );
    expect(
      controller.seekTargetFor(const Duration(milliseconds: 4950)),
      isNull,
    );
    expect(controller.completedLoops, 1);
    expect(controller.totalCompletedLoops, 1);

    expect(controller.seekTargetFor(const Duration(seconds: 2)), isNull);
    expect(
      controller.seekTargetFor(const Duration(seconds: 5)),
      const Duration(seconds: 2),
    );
    expect(controller.completedLoops, 2);
    expect(controller.totalCompletedLoops, 2);
  });

  test('total loop count survives switching ranges', () {
    final controller = LoopController()
      ..setRange(
        LoopRange(
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 2),
        ),
      )
      ..seekTargetFor(const Duration(seconds: 2))
      ..setRange(
        LoopRange(
          start: const Duration(seconds: 3),
          end: const Duration(seconds: 4),
        ),
      )
      ..seekTargetFor(const Duration(seconds: 4));

    expect(controller.completedLoops, 1);
    expect(controller.totalCompletedLoops, 2);
  });

  test('rejects B before A and disables incomplete ranges', () {
    final controller = LoopController()..setStart(const Duration(seconds: 8));

    expect(controller.setEnd(const Duration(seconds: 6)), isFalse);
    expect(controller.setEnabled(true), isFalse);
    expect(controller.enabled, isFalse);
  });
}

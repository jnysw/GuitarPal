import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment_repository.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_session/practice_session_repository.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/player/local_video_player_screen.dart';
import 'package:guitar_pal/features/player/presentation/fullscreen_local_video_controls.dart';
import 'package:guitar_pal/features/segments/practice_segment_providers.dart';
import 'package:integration_test/integration_test.dart';

import 'support/local_video_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TextureView prepares the local video and renders its first frame',
    (tester) async {
      if (!Platform.isAndroid) return;

      final fixtureDirectory = await Directory.systemTemp.createTemp(
        'guitarpal_surface_test_',
      );
      final videoFile = File('${fixtureDirectory.path}/first_frame.m4v');
      await videoFile.writeAsBytes(
        base64Decode(localVideoFixtureBase64),
        flush: true,
      );
      addTearDown(() async {
        if (fixtureDirectory.existsSync()) {
          await fixtureDirectory.delete(recursive: true);
        }
      });

      final channelCompleter = Completer<MethodChannel>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.deepOrange,
            body: Center(
              child: SizedBox(
                width: 320,
                height: 180,
                child: AndroidView(
                  viewType: 'com.guitarpal/local_video_player',
                  creationParams: {'path': videoFile.path},
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (viewId) {
                    if (!channelCompleter.isCompleted) {
                      channelCompleter.complete(
                        MethodChannel(
                          'com.guitarpal/local_video_player/$viewId',
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final channel = await channelCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
          'Android platform view was not created within 10 seconds.',
        ),
      );
      await channel.invokeMethod<void>('setVolume', {'volume': 0.37});
      await channel.invokeMethod<void>('play');

      final snapshot = await _waitForSnapshot(
        tester,
        channel,
        (state) =>
            state['ready'] == true &&
            state['hasVideoFrame'] == true &&
            _positiveNumber(state['videoWidth']) &&
            _positiveNumber(state['videoHeight']),
      );

      expect(snapshot['ready'], isTrue);
      expect(snapshot['hasVideoFrame'], isTrue);
      expect(
        snapshot['videoWidth'],
        isA<num>().having((v) => v, 'width', greaterThan(0)),
      );
      expect(
        snapshot['videoHeight'],
        isA<num>().having((v) => v, 'height', greaterThan(0)),
      );
      expect(
        snapshot['durationMilliseconds'],
        isA<num>().having((v) => v, 'duration', greaterThan(0)),
      );
      expect(snapshot['error'], anyOf(isNull, ''));
      expect((snapshot['volume'] as num).toDouble(), closeTo(0.37, 0.001));

      await channel.invokeMethod<void>('setVolume', {'volume': 0.0});
      final mutedSnapshot = await channel.invokeMapMethod<String, Object?>(
        'snapshot',
      );
      expect((mutedSnapshot!['volume'] as num).toDouble(), 0);
      await channel.invokeMethod<void>('setVolume', {'volume': 1.0});

      final platformViewRect = tester.getRect(find.byType(AndroidView));
      final logicalViewSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      // The native first-frame callback can arrive before Flutter has composited
      // that texture into a frame that PixelCopy can observe.
      await tester.pump(const Duration(milliseconds: 500));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final screenshot = await binding.takeScreenshot(
        'local-video-texture-first-frame',
      );
      expect(screenshot, isNotEmpty);
      final pixelEvidence = await _inspectVideoCenterPixels(
        screenshot,
        platformViewRect: platformViewRect,
        logicalViewSize: logicalViewSize,
      );
      expect(
        pixelEvidence.nonBlackFraction,
        greaterThan(0.01),
        reason:
            'TextureView reported a frame, but its central pixels were black. '
            '$pixelEvidence',
      );
      expect(
        pixelEvidence.lumaRange,
        greaterThan(8),
        reason:
            'TextureView reported a frame, but its central pixels had no '
            'meaningful variation. $pixelEvidence',
      );

      await channel.invokeMethod<void>('pause');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('player can retry after MediaPlayer enters an error state', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;

    final fixtureDirectory = await Directory.systemTemp.createTemp(
      'guitarpal_surface_retry_test_',
    );
    final videoFile = File('${fixtureDirectory.path}/retry.m4v');
    await videoFile.writeAsBytes(const [0, 1, 2, 3], flush: true);
    addTearDown(() async {
      if (fixtureDirectory.existsSync()) {
        await fixtureDirectory.delete(recursive: true);
      }
    });

    final channelCompleter = Completer<MethodChannel>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 180,
          child: AndroidView(
            viewType: 'com.guitarpal/local_video_player',
            creationParams: {'path': videoFile.path},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (viewId) {
              if (!channelCompleter.isCompleted) {
                channelCompleter.complete(
                  MethodChannel('com.guitarpal/local_video_player/$viewId'),
                );
              }
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final channel = await channelCompleter.future.timeout(
      const Duration(seconds: 10),
    );
    final failedSnapshot = await _waitForSnapshot(
      tester,
      channel,
      (state) => state['ready'] == false && state['error'] is String,
    );
    expect(failedSnapshot['hasVideoFrame'], isFalse);

    await videoFile.writeAsBytes(
      base64Decode(localVideoFixtureBase64),
      flush: true,
    );
    await channel.invokeMethod<void>('play');

    final recoveredSnapshot = await _waitForSnapshot(
      tester,
      channel,
      (state) =>
          state['ready'] == true &&
          state['hasVideoFrame'] == true &&
          state['error'] == null,
    );
    expect(recoveredSnapshot['durationMilliseconds'], greaterThan(0));

    await channel.invokeMethod<void>('pause');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('fullscreen player keeps a draggable progress bar', (
    tester,
  ) async {
    if (!Platform.isAndroid) return;

    final fixtureDirectory = await Directory.systemTemp.createTemp(
      'guitarpal_fullscreen_test_',
    );
    final videoFile = File('${fixtureDirectory.path}/fullscreen.m4v');
    await videoFile.writeAsBytes(
      base64Decode(localVideoFixtureBase64),
      flush: true,
    );
    addTearDown(() async {
      if (fixtureDirectory.existsSync()) {
        await fixtureDirectory.delete(recursive: true);
      }
    });

    final now = DateTime.now().toUtc();
    final source = PracticeSource(
      id: 'fullscreen-source',
      platform: SourcePlatform.local,
      kind: SourceKind.video,
      canonicalUri: Uri.file(videoFile.path),
      title: '全屏进度测试',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceSegmentRepositoryProvider.overrideWithValue(
            _EmptyPracticeSegmentRepository(),
          ),
          practiceSessionRepositoryProvider.overrideWithValue(
            _EmptyPracticeSessionRepository(),
          ),
        ],
        child: MaterialApp(home: LocalVideoPlayerScreen(source: source)),
      ),
    );
    await _waitUntil(tester, () {
      final finder = find.byKey(const Key('local_video_position_slider'));
      if (finder.evaluate().isEmpty) return false;
      return tester.widget<Slider>(finder).onChanged != null;
    }, failureMessage: 'Local video did not become controllable.');

    await tester.tap(find.byKey(const Key('local_video_fullscreen')));
    await tester.pump(const Duration(seconds: 2));

    final fullscreenProgress = find.byKey(
      FullscreenLocalVideoControls.progressKey,
    );
    expect(fullscreenProgress, findsOneWidget);
    expect(tester.widget<Slider>(fullscreenProgress).onChanged, isNotNull);
    final sliderRect = tester.getRect(fullscreenProgress);
    await tester.tapAt(
      Offset(sliderRect.left + sliderRect.width * 0.7, sliderRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(fullscreenProgress, findsNothing);
    expect(find.text('全屏进度测试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('local_video_fullscreen')));
    await tester.pump(const Duration(seconds: 1));
    expect(fullscreenProgress, findsOneWidget);

    await tester.tap(find.byKey(const Key('local_video_fullscreen')));
    await tester.pump(const Duration(seconds: 1));
    expect(fullscreenProgress, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String failureMessage,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  fail(failureMessage);
}

Future<Map<String, Object?>> _waitForSnapshot(
  WidgetTester tester,
  MethodChannel channel,
  bool Function(Map<String, Object?> state) matches,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  Map<String, Object?> lastSnapshot = const {};

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    final snapshot = await channel.invokeMapMethod<String, Object?>('snapshot');
    if (snapshot != null) {
      lastSnapshot = snapshot;
      if (matches(snapshot)) return snapshot;
    }
  }

  fail(
    'Native local-video surface did not render a frame within 15 seconds. '
    'Last snapshot: $lastSnapshot',
  );
}

bool _positiveNumber(Object? value) => value is num && value > 0;

Future<_PixelEvidence> _inspectVideoCenterPixels(
  List<int> pngBytes, {
  required ui.Rect platformViewRect,
  required ui.Size logicalViewSize,
}) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        fail('Could not decode screenshot pixels.');
      }

      final pixels = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final scaleX = image.width / logicalViewSize.width;
      final scaleY = image.height / logicalViewSize.height;

      // Inspect the middle 40% of the AndroidView. This deliberately excludes
      // both the view edge and any aspect-ratio letterboxing around the video.
      final centerRect = ui.Rect.fromCenter(
        center: platformViewRect.center,
        width: platformViewRect.width * 0.4,
        height: platformViewRect.height * 0.4,
      );
      final left = (centerRect.left * scaleX).floor().clamp(0, image.width - 1);
      final top = (centerRect.top * scaleY).floor().clamp(0, image.height - 1);
      final right = (centerRect.right * scaleX).ceil().clamp(
        left + 1,
        image.width,
      );
      final bottom = (centerRect.bottom * scaleY).ceil().clamp(
        top + 1,
        image.height,
      );

      var sampledPixels = 0;
      var nonBlackPixels = 0;
      var minimumLuma = 255;
      var maximumLuma = 0;
      for (var y = top; y < bottom; y += 2) {
        for (var x = left; x < right; x += 2) {
          final offset = (y * image.width + x) * 4;
          final red = pixels[offset];
          final green = pixels[offset + 1];
          final blue = pixels[offset + 2];
          final luma = (red * 54 + green * 183 + blue * 19) >> 8;
          sampledPixels++;
          if (red > 8 || green > 8 || blue > 8) nonBlackPixels++;
          if (luma < minimumLuma) minimumLuma = luma;
          if (luma > maximumLuma) maximumLuma = luma;
        }
      }

      return _PixelEvidence(
        sampledPixels: sampledPixels,
        nonBlackPixels: nonBlackPixels,
        minimumLuma: minimumLuma,
        maximumLuma: maximumLuma,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class _PixelEvidence {
  const _PixelEvidence({
    required this.sampledPixels,
    required this.nonBlackPixels,
    required this.minimumLuma,
    required this.maximumLuma,
  });

  final int sampledPixels;
  final int nonBlackPixels;
  final int minimumLuma;
  final int maximumLuma;

  double get nonBlackFraction => nonBlackPixels / sampledPixels;
  int get lumaRange => maximumLuma - minimumLuma;

  @override
  String toString() =>
      'sampled=$sampledPixels, nonBlack=$nonBlackPixels '
      '(${(nonBlackFraction * 100).toStringAsFixed(1)}%), '
      'luma=$minimumLuma..$maximumLuma';
}

final class _EmptyPracticeSegmentRepository
    implements PracticeSegmentRepository {
  @override
  Stream<List<PracticeSegment>> watchAll() => Stream.value(const []);

  @override
  Future<void> delete(String id) async {}

  @override
  Future<PracticeSegment?> getById(String id) async => null;

  @override
  Future<void> save(PracticeSegment segment) async {}

  @override
  Stream<List<PracticeSegment>> watchBySource(String sourceId) {
    return Stream.value(const []);
  }
}

final class _EmptyPracticeSessionRepository
    implements PracticeSessionRepository {
  @override
  Stream<List<PracticeSession>> watchAll() => Stream.value(const []);

  @override
  Future<void> save(PracticeSession session) async {}

  @override
  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    return Stream.value(const []);
  }

  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate date) {
    return Stream.value(const []);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/separation_result_screen.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  testWidgets(
    'exports only selected tracks and reuses them after save cancellation',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('melpal-export-test');
      addTearDown(() => root.deleteSync(recursive: true));
      final staging = Directory('${root.path}/export')..createSync();
      final audio = syntheticAlgorithmWav();
      File('${root.path}/local-task_guitar.wav').writeAsBytesSync(audio);
      final requests = <String>[];
      final store = AlgorithmStemStore(
        () async => root,
        clientFactory: () => MockClient((request) async {
          requests.add(request.url.pathSegments.last);
          return http.Response.bytes(
            audio,
            200,
            headers: {'content-type': 'audio/wav'},
          );
        }),
      );
      final exports = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('com.guitarpal/performance_export');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'stemExportDirectory') return staging.path;
        expect(call.method, 'saveStemExport');
        final extension = call.arguments['extension'] as String;
        final id = call.arguments['id'];
        final output = File('${staging.path}/$id.$extension').readAsBytesSync();
        if (extension == 'zip') {
          final files = ZipDecoder().decodeBytes(output, verify: true).files;
          expect(files.map((file) => file.name), [
            '01-guitar.wav',
            '02-instrumental.wav',
          ]);
          for (final file in files) {
            expect(file.content as List<int>, audio);
          }
        } else {
          expect(extension, 'wav');
          expect(output, audio);
        }
        exports.add(extension);
        return extension == 'wav';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final result = separationFixture();
      (result['stems'] as List).removeWhere(
        (track) =>
            !{'guitar', 'instrumental', 'other'}.contains((track as Map)['id']),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            algorithmStemPlatformProvider.overrideWithValue(_Player()),
            algorithmStemStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(home: SeparationResultScreen(task: _task(result))),
        ),
      );
      final export = find.text('导出音轨');
      await _waitFor(tester, () => export.evaluate().isNotEmpty);
      await tester.tap(export);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final guitar = find.byKey(const Key('video_pick_stem_guitar'));
      final backing = find.byKey(const Key('video_pick_stem_instrumental'));
      final save = find.byKey(const Key('video_export_selected_stems'));
      await _waitFor(tester, () => guitar.hitTestable().evaluate().isNotEmpty);
      await tester.tap(guitar);
      await tester.ensureVisible(backing);
      await tester.tap(backing);
      await _waitFor(
        tester,
        () => tester.widget<FilledButton>(save).onPressed != null,
      );
      await tester.tap(save);
      await _waitFor(
        tester,
        () =>
            exports.length == 1 &&
            tester.widget<FilledButton>(save).onPressed != null,
      );
      expect(requests, ['instrumental']);
      expect(tester.widget<CheckboxListTile>(guitar).value, isTrue);
      expect(tester.widget<CheckboxListTile>(backing).value, isTrue);
      expect(staging.listSync(), isEmpty);
      await tester.ensureVisible(backing);
      await tester.tap(backing);
      await tester.tap(save);
      await _waitFor(tester, () => find.text('所选音轨已保存').evaluate().isNotEmpty);
      expect(requests, ['instrumental']);
      expect(exports, ['zip', 'wav']);
      expect(staging.listSync(), isEmpty);
      expect(File('${root.path}/local-task_guitar.wav').existsSync(), isTrue);
    },
  );

  testWidgets('expired server results retain offline audition and seeking', (
    tester,
  ) async {
    final platform = _Player();
    final task = _task(separationFixture(expires: '2000-01-01T00:00:00Z'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          algorithmStemPlatformProvider.overrideWithValue(platform),
          algorithmStemStoreProvider.overrideWithValue(_OfflineStore()),
        ],
        child: MaterialApp(home: SeparationResultScreen(task: task)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('服务器文件已到期'), findsOneWidget);
    expect(find.text('已下载 · 可离线试听'), findsOneWidget);
    await tester.tap(find.text('试听'));
    await tester.pumpAndSettle();
    expect(platform.played, endsWith('local-task_vocals.wav'));
    expect(find.text('暂停'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pump();
    expect(platform.seeked, greaterThan(Duration.zero));
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(platform.pauses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(platform.stops, greaterThan(0));
  });
}

AlgorithmTaskRecord _task(Map<String, Object?> result) {
  final now = DateTime.now();
  return AlgorithmTaskRecord(
    id: 'local-task',
    endpoint: 'https://algorithm.example',
    inputPath: '/unused',
    inputName: '自有测试.wav',
    inputSizeBytes: 1000,
    inputDurationMs: 8000,
    ownsInput: false,
    state: AlgorithmTaskState.completed,
    createdAt: now,
    updatedAt: now,
    failures: 0,
    operation: AlgorithmOperation.separation,
    resultJson: jsonEncode(result),
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (condition()) return;
  }
  fail('Export flow did not reach the expected state');
}

class _OfflineStore extends AlgorithmStemStore {
  _OfflineStore()
    : super(
        () async => Directory.systemTemp,
        clientFactory: () => throw StateError('network must not be used'),
      );
  @override
  Future<File?> localFile(String taskId, LegacyStemFile stem) async =>
      stem.id == 'vocals'
      ? File('/app/algorithm_stems/local-task_vocals.wav')
      : null;
}

class _Player extends AlgorithmStemPlatform {
  String? played;
  Duration seeked = Duration.zero;
  int pauses = 0, stops = 0;
  @override
  Future<void> play(String path, Duration position) async {
    played = path;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> seek(Duration position) async {
    seeked = position;
  }

  @override
  Future<Map<String, Object?>> snapshot() async => {
    'isPlaying': true,
    'positionMs': 0,
    'durationMs': 8000,
  };
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';
import 'package:guitar_pal/features/audio_tools/separation_result_screen.dart';

import '../../support/algorithm_fixtures.dart';

void main() {
  testWidgets('expired server results retain offline audition and seeking', (
    tester,
  ) async {
    final platform = _Player();
    final now = DateTime.now();
    final task = AlgorithmTaskRecord(
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
      resultJson: jsonEncode(
        separationFixture(expires: '2000-01-01T00:00:00Z'),
      ),
    );
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

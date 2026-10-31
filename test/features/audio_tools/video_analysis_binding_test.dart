import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/domain/algorithm_task.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_analysis_binding.dart';

void main() {
  test('source revision and explicit calibration stay separate from extracted input coordinates', () {
    final directory = Directory.systemTemp.createTempSync('gp_binding_');
    final source = File('${directory.path}/source.mp4')
      ..writeAsBytesSync([1, 2, 3]);
    try {
      final stat = source.statSync();
      final binding = VideoAnalysisBinding(
        sourceId: 'source',
        path: source.path,
        sourceBytes: stat.size,
        modifiedMs: stat.modified.millisecondsSinceEpoch,
        sourceDurationMs: 12000,
        startMs: 3000,
        durationMs: 8000,
        inputSha256: 'a' * 64,
        waveform: [0, .5, 1],
      );
      final restored = VideoAnalysisBinding.fromJson(
        jsonDecode(jsonEncode(binding.toJson())) as Map<String, Object?>,
      );
      expect(restored.matches('source', source.path, stat), isTrue);
      expect(restored.manualChordZeroMs, isNull);
      final calibrated = restored.withChordZero(3250);
      expect(calibrated.startMs, 3000);
      expect(calibrated.durationMs, 8000);
      expect(calibrated.manualChordZeroMs, 3250);
      expect(calibrated.inputSha256, restored.inputSha256);
      expect(() => restored.withChordZero(2999), throwsFormatException);
      source.writeAsBytesSync([1, 2, 3, 4]);
      expect(
        restored.matches('source', source.path, source.statSync()),
        isFalse,
      );
      expect(restored.matches('another-source', source.path, stat), isFalse);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
  test('v12 upgrade retains automatic statistical links and old results without inventing media mapping', () async {
    final directory = await Directory.systemTemp.createTemp('gp_v12_');
    final file = File('${directory.path}/db.sqlite');
    final original = AppDatabase(NativeDatabase(file));
    final date = DateTime.utc(2026, 10, 28);
    await original
        .into(original.practiceSources)
        .insert(
          PracticeSourcesCompanion.insert(
            id: 'source',
            platform: 'local',
            kind: 'video',
            title: '保留视频',
            createdAt: date,
            updatedAt: date,
          ),
        );
    await AlgorithmTaskRepository(original).insert(
      AlgorithmTaskRecord(
        id: 'old',
        endpoint: 'https://algorithm.example',
        inputPath: '/input.wav',
        inputName: 'input.wav',
        inputSizeBytes: 100,
        inputDurationMs: 8000,
        ownsInput: true,
        linkedSourceId: 'source',
        state: AlgorithmTaskState.completed,
        createdAt: date,
        updatedAt: date,
        failures: 0,
      ),
    );
    await AlgorithmTaskRepository(original).update(
      'old',
      AlgorithmTaskState.completed,
      resultJson: '{"preserved":true}',
    );
    await original.close();
    final migrated = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'ALTER TABLE algorithm_tasks DROP COLUMN media_binding_json',
          );
          raw.execute('PRAGMA user_version = 12');
        },
      ),
    );
    try {
      final task = (await AlgorithmTaskRepository(migrated).get('old'))!;
      expect(task.linkedSourceId, 'source');
      expect(task.resultJson, '{"preserved":true}');
      expect(task.mediaBindingJson, isNull);
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });
}

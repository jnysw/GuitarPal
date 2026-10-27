import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_providers.dart';
import 'package:guitar_pal/features/audio_tools/algorithm_tools_screen.dart';
import 'package:guitar_pal/features/audio_tools/application/algorithm_task_service.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_audio_import.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_task_repository.dart';
import 'package:guitar_pal/features/audio_tools/data/legacy_algorithm_api.dart';
import 'package:guitar_pal/features/audio_tools/domain/legacy_algorithm_models.dart';

void main() {
  testWidgets(
    'explicit upload consent leads to cached, unsynchronized chord results',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = AlgorithmTaskRepository(database);
      final importer = _Importer();
      final api = _Api();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            algorithmAudioImportProvider.overrideWithValue(importer),
            algorithmTaskServiceProvider.overrideWithValue(
              AlgorithmTaskService(
                repository,
                allowLocalHttp: true,
                apiFactory: (_) => api,
              ),
            ),
          ],
          child: const MaterialApp(home: AlgorithmToolsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('algorithm_endpoint')),
        'http://192.168.1.50:8000',
      );
      await tester.tap(find.byKey(const Key('algorithm_pick_audio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('algorithm_submit')));
      await tester.pumpAndSettle();
      expect(api.uploads, 0);
      expect(
        find.textContaining('接收服务器：http://192.168.1.50:8000'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('algorithm_confirm_upload')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(api.uploads, 1);
      await tester.scrollUntilVisible(
        find.text('查看离线结果'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看离线结果'));
      await tester.pumpAndSettle();
      expect(find.text('和弦分析结果'), findsOneWidget);
      expect(find.text('Am'), findsOneWidget);
      expect(find.textContaining('暂不用于原曲定位或 A-B'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(importer.deleted, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await database.close();
    },
  );
}

class _Importer implements AlgorithmAudioImport {
  final List<String> deleted = [];
  @override
  Future<AlgorithmAudioInput?> pickAudio() async => const AlgorithmAudioInput(
    path: '/app/algorithm_inputs/test.wav',
    name: '练习.wav',
    sizeBytes: 8000,
    duration: Duration(seconds: 8),
  );
  @override
  Future<void> deleteInput(String path) async {
    deleted.add(path);
  }
}

class _Api implements AlgorithmApi {
  int uploads = 0;
  @override
  Future<void> ping() async {}
  @override
  Future<LegacyUploadReceipt> upload(
    String path,
    String filename, {
    AlgorithmOperation operation = AlgorithmOperation.chords,
    void Function(int, int)? onProgress,
  }) async {
    uploads++;
    onProgress?.call(8000, 8000);
    return LegacyUploadReceipt.fromJson(
      {
        'job_id': 'contract_job_1',
        'status': 'queued',
        'poll_url': '/api/v1/jobs/contract_job_1/status',
        'result_url': '/api/v1/jobs/contract_job_1/result',
      },
      AlgorithmEndpoint('http://192.168.1.50:8000', allowLocalHttp: true),
      operation,
    );
  }

  @override
  Future<LegacyAlgorithmStatus> status(
    String jobId,
    AlgorithmOperation operation,
  ) async => LegacyAlgorithmStatus.fromJson({
    'job_id': jobId,
    'status': 'completed',
    'progress': 100,
    'message': 'completed',
    'error': null,
  }, operation);
  @override
  Future<Map<String, Object?>> result(
    String jobId,
    AlgorithmOperation operation,
  ) async => jsonDecode(
    File('contracts/legacy_algorithm/fixtures/chords_result.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  @override
  void close() {}
}

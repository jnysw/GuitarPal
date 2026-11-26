import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:guitar_pal/core/platform/practice_audio_recorder.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_stem_store.dart';
import 'package:guitar_pal/features/performance/data/performance_audio_platform.dart';
import 'package:guitar_pal/features/performance/data/performance_export_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native AAC + cached WAV exports aligned stereo, protects inputs, cancels and retries',
    (tester) async {
      const mic = MethodChannelPracticeAudioRecorder();
      const extra = PerformanceAudioPlatform();
      const export = PerformanceExportPlatform();
      final id = 'export_integration_${DateTime.now().microsecondsSinceEpoch}';
      final outputs = <File>[];
      File? backing;
      String? path;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('数字混音导出验证'))),
      );
      try {
        expect(
          await mic.permissionStatus(),
          MicrophonePermissionStatus.granted,
        );
        await extra.start(id);
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        final recording = await mic.stop();
        path = recording.relativePath;
        final micFile = File(recording.absolutePath);
        final beforeMic = sha256.convert(await micFile.readAsBytes());
        final dir = await const AlgorithmStemPlatform().directory();
        backing = File('${dir.path}/${id}_bass.wav');
        await backing.writeAsBytes(_wave());
        final beforeBacking = sha256.convert(await backing.readAsBytes());
        final args = <String, Object?>{
          'takeId': id,
          'durationMs': recording.duration.inMilliseconds,
          'speed': 1.0,
          'leadMs': 150,
          'alignmentMs': 50,
          'backingEndMs': 1000,
          'backingDurationMs': 2000,
          'micGain': 0.0,
          'backingGain': .5,
          'tracks': [
            {'path': backing.path, 'gain': .5, 'pan': 1.0},
          ],
        };
        final result = await export.render(args);
        final file = File(
          '${micFile.parent.parent.path}/performance_exports/${result.id}.wav',
        );
        outputs.add(file);
        final bytes = await file.readAsBytes();
        final b = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(b.getUint32(24, Endian.little), 44100);
        expect(
          bytes.length,
          44 + recording.duration.inMilliseconds * 44100 ~/ 1000 * 4,
        );
        double at(int ms, int side) =>
            b.getInt16(44 + ms * 44100 ~/ 1000 * 4 + side * 2, Endian.little) /
            32768;
        expect(at(99, 1), 0);
        expect(at(100, 1), closeTo(.0625, .00005));
        expect(at(300, 0), 0);
        expect(at(1099, 1), closeTo(.0625, .00005));
        expect(at(1100, 1), 0);
        await PerformanceExportPlatform.channel.invokeMethod('play', {
          'id': result.id,
          'volume': 0.0,
        });
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect((await export.snapshot())['playing'], isTrue);
        await export.stop();
        final pending = export.render(args);
        await export.cancel();
        await expectLater(
          pending,
          throwsA(
            isA<PlatformException>().having((e) => e.code, 'code', 'cancelled'),
          ),
        );
        final retry = await export.render(args);
        outputs.add(
          File(
            '${micFile.parent.parent.path}/performance_exports/${retry.id}.wav',
          ),
        );
        expect(retry.bytes, result.bytes);
        expect(sha256.convert(await micFile.readAsBytes()), beforeMic);
        expect(sha256.convert(await backing.readAsBytes()), beforeBacking);
        final work = Directory(
          '${micFile.parent.parent.path.replaceFirst('/files', '/cache')}/performance_export_work',
        );
        if (await work.exists()) expect(await work.list().toList(), isEmpty);
        if (const bool.fromEnvironment('CHECK_EXPORT_DOCUMENT_UI')) {
          debugPrint('PERFORMANCE_EXPORT_SAVE_READY');
          expect(await export.save(result.id, 'GuitarPal导出验收'), isTrue);
          debugPrint('PERFORMANCE_EXPORT_SHARE_READY');
          await export.share(result.id);
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      } finally {
        await export.cancel();
        await export.stop();
        if (await mic.isRecording()) await mic.cancel();
        if (path != null) await mic.deleteRecording(path);
        if (backing != null && await backing.exists()) await backing.delete();
        for (final file in outputs) {
          if (await file.exists()) await file.delete();
        }
      }
    },
  );
}

Uint8List _wave() {
  const frames = 44100 * 2;
  final b = ByteData(44 + frames * 2);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  b.setUint32(4, 36 + frames * 2, Endian.little);
  text(8, 'WAVEfmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 44100, Endian.little);
  b.setUint32(28, 88200, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  text(36, 'data');
  b.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    b.setInt16(44 + i * 2, 8192, Endian.little);
  }
  return b.buffer.asUint8List();
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/video_mix_preferences.dart';
import 'package:guitar_pal/features/audio_tools/domain/stem_mix_settings.dart';
import 'package:guitar_pal/features/audio_tools/domain/video_mix_selection.dart';

void main() {
  VideoMixSelection selection({bool stems = true, double guitar = .4}) =>
      VideoMixSelection(
        taskId: 'task',
        inputSha256: 'a' * 64,
        useStems: stems,
        controls: {
          'guitar': StemMixControl(volume: guitar, solo: true),
          'drums': const StemMixControl(muted: true),
        },
      );

  test('persisted controls preserve solo/mute semantics without transport settings', () {
    final value = VideoMixSelection.fromJson(
      jsonDecode(jsonEncode(selection().toJson())) as Map<String, Object?>,
    );
    expect(value.gains['guitar'], .4);
    expect(value.gains['drums'], 0);
    expect(value.gains['vocals'], 0);
    expect(value.withMode(false).controls['guitar']!.solo, isTrue);
    expect(value.toJson().keys, isNot(contains('speed')));
    expect(value.toJson().keys, isNot(contains('loop')));
    expect(value.toJson().keys, isNot(contains('positionMs')));
    expect(
      () => VideoMixSelection(
        taskId: 'task',
        inputSha256: 'wrong',
        useStems: true,
      ),
      throwsFormatException,
    );
    final json = selection().toJson();
    (json['controls'] as Map<String, Object?>)['instrumental'] =
        const StemMixControl().toJson();
    expect(() => VideoMixSelection.fromJson(json), throwsFormatException);
    expect(() => selection(guitar: double.nan), throwsFormatException);
  });

  test('concurrent saves are atomic and latest original-mode choice wins after reopen', () async {
    final root = await Directory.systemTemp.createTemp('gp_video_mix_');
    final preferences = VideoMixPreferences(() async => root);
    try {
      await Future.wait([
        preferences.save('source', selection()),
        preferences.save('source', selection(guitar: .63)),
        preferences.save('source', selection(stems: false, guitar: .78)),
      ]);
      final restored = (await VideoMixPreferences(() async => root)
          .load('source'))!;
      expect(restored.useStems, isFalse);
      expect(restored.controls['guitar']!.volume, .78);
      expect(
        (await root.list(recursive: true).toList()).whereType<File>().any(
          (f) => f.path.endsWith('.part'),
        ),
        isFalse,
      );
      expect(await preferences.load('different-source'), isNull);
      expect(() => preferences.load('../escape'), throwsFormatException);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('invalid file is recoverable by a later save and does not poison the write queue', () async {
    final root = await Directory.systemTemp.createTemp('gp_video_mix_bad_');
    final preferences = VideoMixPreferences(() async => root);
    try {
      await preferences.save('source', selection());
      final file = File('${root.path}/video_workspace/source.json');
      await file.writeAsString('{broken');
      await expectLater(preferences.load('source'), throwsFormatException);
      await preferences.save('source', selection(guitar: .27));
      expect(
        (await preferences.load('source'))!.controls['guitar']!.volume,
        .27,
      );
      await file.writeAsString(' ' * 32769);
      await expectLater(preferences.load('source'), throwsFormatException);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'deletion follows queued saves and blocks late settings resurrection',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'gp_video_mix_delete_',
      );
      final preferences = VideoMixPreferences(() async => root);
      try {
        await preferences.save('source', selection());
        await preferences.delete('source');
        await expectLater(
          preferences.save('source', selection()),
          throwsStateError,
        );
        expect(await preferences.load('source'), isNull);
        expect(
          await File('${root.path}/video_workspace/source.json').exists(),
          isFalse,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}

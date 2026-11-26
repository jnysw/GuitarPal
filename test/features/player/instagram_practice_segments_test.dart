import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/database/app_database.dart' as db;
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/player/instagram_preview_screen.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_card.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_editor_sheet.dart';

void main() {
  testWidgets(
    'saves manual practice markers even when Instagram preview is unavailable',
    (tester) async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.now();
      final post = Uri.parse('https://www.instagram.com/reel/DFNpHGuRjS_/');
      final source = PracticeSource(
        id: 'reel',
        platform: SourcePlatform.instagram,
        kind: SourceKind.webReference,
        title: 'Instagram 练习',
        canonicalUri: post,
        createdAt: now,
        updatedAt: now,
      );
      await DriftPracticeSourceRepository(database).save(source);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              home: InstagramPreviewScreen(source: source, post: post),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('instagram_practice_segments')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('online_create_segment')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(PracticeSegmentEditorKeys.title),
          '慢练副歌',
        );
        await tester.enterText(
          find.byKey(PracticeSegmentEditorKeys.start),
          '0:04.250',
        );
        await tester.enterText(
          find.byKey(PracticeSegmentEditorKeys.end),
          '0:09.600',
        );
        final save = find.byKey(PracticeSegmentEditorKeys.save);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final card = tester.widget<PracticeSegmentCard>(
          find.byType(PracticeSegmentCard),
        );
        expect(card.segment.title, '慢练副歌');
        expect(card.segment.start.inMilliseconds, 4250);
        expect(card.segment.end.inMilliseconds, 9600);
        expect(card.onOpen, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
      }
    },
  );
}

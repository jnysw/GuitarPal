import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/create/create_practice_screen.dart';

void main() {
  testWidgets(
    'local import is the first choice and changing methods keeps the typed link at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const CreatePracticeScreen(),
          ),
        ),
      );
      expect(find.byKey(const Key('pick_gallery_video')), findsOneWidget);
      expect(find.byKey(const Key('create_share_text_field')), findsNothing);
      await tester.tap(find.text('分享链接'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('create_share_text_field')),
        '练习草稿',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('create_continue_button')),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create_continue_button')));
      await tester.pumpAndSettle();
      expect(find.text('没有识别到有效的 http/https 链接'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('本地视频'),
        -140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('本地视频'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create_share_text_field')), findsNothing);
      await tester.tap(find.text('分享链接'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('create_share_text_field')),
      );
      expect(field.controller!.text, '练习草稿');
      expect(field.decoration!.errorText, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

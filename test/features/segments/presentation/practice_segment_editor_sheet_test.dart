import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/player/widgets/precise_playback_speed_control.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_editor_sheet.dart';

void main() {
  testWidgets('create mode validates fields and returns a normalized result', (
    tester,
  ) async {
    PracticeSegmentEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _EditorLauncher(
          mode: PracticeSegmentEditorMode.create,
          onComplete: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.byKey(_EditorLauncher.openKey));
    await tester.pumpAndSettle();

    expect(find.byKey(PracticeSegmentEditorKeys.sheet), findsOneWidget);
    expect(find.text('新建练习片段'), findsOneWidget);
    expect(_fieldText(tester, PracticeSegmentEditorKeys.start), '0:00');
    expect(_fieldText(tester, PracticeSegmentEditorKeys.end), '0:30');

    await tester.enterText(
      find.byKey(PracticeSegmentEditorKeys.title),
      '  主歌扫弦  ',
    );
    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.start), '1:05');
    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.end), '1:20');
    await tester.enterText(
      find.byKey(PracticeSegmentEditorKeys.note),
      '  保持右手放松  ',
    );

    await tester.ensureVisible(
      find.byKey(PrecisePlaybackSpeedControlKeys.exactValue),
    );
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.exactValue));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(PrecisePlaybackSpeedControlKeys.input),
      '1.27',
    );
    await tester.tap(find.byKey(PrecisePlaybackSpeedControlKeys.confirm));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(PracticeSegmentEditorKeys.save));
    await tester.tap(find.byKey(PracticeSegmentEditorKeys.save));
    await tester.pumpAndSettle();

    expect(
      result,
      const PracticeSegmentEditorResult(
        title: '主歌扫弦',
        start: Duration(minutes: 1, seconds: 5),
        end: Duration(minutes: 1, seconds: 20),
        preferredSpeed: 1.27,
        note: '保持右手放松',
      ),
    );
    expect(find.byKey(PracticeSegmentEditorKeys.sheet), findsNothing);
  });

  testWidgets('shows inline format and A-B range validation', (tester) async {
    PracticeSegmentEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _EditorLauncher(
          mode: PracticeSegmentEditorMode.create,
          onComplete: (value) => result = value,
        ),
      ),
    );

    await tester.tap(find.byKey(_EditorLauncher.openKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.start), '1:70');
    await tester.pump();
    expect(find.text('请输入 m:ss.SSS 或 h:mm:ss.SSS'), findsOneWidget);

    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.title), '   ');
    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.start), '0:30');
    await tester.enterText(find.byKey(PracticeSegmentEditorKeys.end), '0:30');
    await tester.ensureVisible(find.byKey(PracticeSegmentEditorKeys.save));
    await tester.tap(find.byKey(PracticeSegmentEditorKeys.save));
    await tester.pump();

    expect(find.text('请输入片段名称'), findsOneWidget);
    expect(find.text('B 点必须晚于 A 点'), findsOneWidget);
    expect(result, isNull);
    expect(find.byKey(PracticeSegmentEditorKeys.sheet), findsOneWidget);
  });

  testWidgets('edit mode pre-fills every field and cancel returns null', (
    tester,
  ) async {
    Object? completion = _notCompleted;
    await tester.pumpWidget(
      MaterialApp(
        home: _EditorLauncher(
          mode: PracticeSegmentEditorMode.edit,
          initialValue: const PracticeSegmentEditorResult(
            title: '原片段',
            start: Duration(hours: 1, minutes: 2, seconds: 3),
            end: Duration(hours: 1, minutes: 3, seconds: 4),
            preferredSpeed: 1.1,
            note: '原笔记',
          ),
          onComplete: (value) => completion = value,
        ),
      ),
    );

    await tester.tap(find.byKey(_EditorLauncher.openKey));
    await tester.pumpAndSettle();

    expect(find.text('编辑练习片段'), findsOneWidget);
    expect(_fieldText(tester, PracticeSegmentEditorKeys.title), '原片段');
    expect(_fieldText(tester, PracticeSegmentEditorKeys.start), '1:02:03');
    expect(_fieldText(tester, PracticeSegmentEditorKeys.end), '1:03:04');
    expect(_fieldText(tester, PracticeSegmentEditorKeys.note), '原笔记');
    expect(find.text('1.10x'), findsOneWidget);

    await tester.ensureVisible(find.byKey(PracticeSegmentEditorKeys.cancel));
    await tester.tap(find.byKey(PracticeSegmentEditorKeys.cancel));
    await tester.pumpAndSettle();

    expect(completion, isNull);
  });
}

const _notCompleted = Object();

String _fieldText(WidgetTester tester, Key fieldKey) {
  final editable = find.descendant(
    of: find.byKey(fieldKey),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editable).controller.text;
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher({
    required this.mode,
    required this.onComplete,
    this.initialValue,
  });

  static const openKey = Key('open_segment_editor');

  final PracticeSegmentEditorMode mode;
  final PracticeSegmentEditorResult? initialValue;
  final ValueChanged<PracticeSegmentEditorResult?> onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: openKey,
          onPressed: () async {
            final result = await showPracticeSegmentEditorSheet(
              context: context,
              mode: mode,
              initialValue: initialValue,
            );
            onComplete(result);
          },
          child: const Text('打开编辑器'),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../media/playback/playback_speed.dart';
import '../../player/widgets/precise_playback_speed_control.dart';
import 'practice_segment_timecode.dart';

enum PracticeSegmentEditorMode { create, edit }

/// The validated, presentation-layer value returned by the segment editor.
///
/// This deliberately does not contain persistence identifiers or timestamps,
/// so both the player and the detail page can decide whether to create or
/// update a domain object after the sheet closes.
final class PracticeSegmentEditorResult {
  const PracticeSegmentEditorResult({
    required this.title,
    required this.start,
    required this.end,
    this.preferredSpeed = 1.0,
    this.note,
  });

  final String title;
  final Duration start;
  final Duration end;
  final double preferredSpeed;
  final String? note;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PracticeSegmentEditorResult &&
            other.title == title &&
            other.start == start &&
            other.end == end &&
            other.preferredSpeed == preferredSpeed &&
            other.note == note;
  }

  @override
  int get hashCode => Object.hash(title, start, end, preferredSpeed, note);

  @override
  String toString() {
    return 'PracticeSegmentEditorResult('
        'title: $title, start: $start, end: $end, '
        'preferredSpeed: $preferredSpeed, note: $note)';
  }
}

/// Stable keys shared by integration and widget tests.
abstract final class PracticeSegmentEditorKeys {
  static const sheet = Key('practice_segment_editor_sheet');
  static const title = Key('practice_segment_editor_title');
  static const start = Key('practice_segment_editor_start');
  static const end = Key('practice_segment_editor_end');
  static const preferredSpeed = Key('practice_segment_editor_speed');
  static const note = Key('practice_segment_editor_note');
  static const cancel = Key('practice_segment_editor_cancel');
  static const save = Key('practice_segment_editor_save');
}

Future<PracticeSegmentEditorResult?> showPracticeSegmentEditorSheet({
  required BuildContext context,
  required PracticeSegmentEditorMode mode,
  PracticeSegmentEditorResult? initialValue,
}) {
  if (mode == PracticeSegmentEditorMode.edit && initialValue == null) {
    throw ArgumentError.notNull('initialValue');
  }

  return showModalBottomSheet<PracticeSegmentEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        PracticeSegmentEditorSheet(mode: mode, initialValue: initialValue),
  );
}

class PracticeSegmentEditorSheet extends StatefulWidget {
  PracticeSegmentEditorSheet({
    required this.mode,
    this.initialValue,
    super.key,
  }) {
    if (mode == PracticeSegmentEditorMode.edit && initialValue == null) {
      throw ArgumentError.notNull('initialValue');
    }
  }

  final PracticeSegmentEditorMode mode;
  final PracticeSegmentEditorResult? initialValue;

  @override
  State<PracticeSegmentEditorSheet> createState() =>
      _PracticeSegmentEditorSheetState();
}

class _PracticeSegmentEditorSheetState
    extends State<PracticeSegmentEditorSheet> {
  static const _defaultValue = PracticeSegmentEditorResult(
    title: '',
    start: Duration.zero,
    end: Duration(seconds: 30),
  );
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _noteController;
  late double _preferredSpeed;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? _defaultValue;
    _titleController = TextEditingController(text: initial.title);
    _startController = TextEditingController(
      text: formatPracticeTimecode(initial.start),
    );
    _endController = TextEditingController(
      text: formatPracticeTimecode(initial.end),
    );
    _noteController = TextEditingController(text: initial.note ?? '');
    _preferredSpeed = initial.preferredSpeed.isFinite
        ? normalizePlaybackSpeed(initial.preferredSpeed)
        : 1.0;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startController.dispose();
    _endController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return '请输入片段名称';
    if (title.length > 120) return '片段名称不能超过 120 个字符';
    return null;
  }

  String? _validateStart(String? value) {
    if (tryParsePracticeTimecode(value ?? '') == null) {
      return '请输入 m:ss.SSS 或 h:mm:ss.SSS';
    }
    return null;
  }

  String? _validateEnd(String? value) {
    final end = tryParsePracticeTimecode(value ?? '');
    if (end == null) return '请输入 m:ss.SSS 或 h:mm:ss.SSS';
    final start = tryParsePracticeTimecode(_startController.text);
    if (start != null && end <= start) return 'B 点必须晚于 A 点';
    return null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      PracticeSegmentEditorResult(
        title: _titleController.text.trim(),
        start: tryParsePracticeTimecode(_startController.text)!,
        end: tryParsePracticeTimecode(_endController.text)!,
        preferredSpeed: _preferredSpeed,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.mode == PracticeSegmentEditorMode.edit;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      key: PracticeSegmentEditorKeys.sheet,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditing ? '编辑练习片段' : '新建练习片段',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: PracticeSegmentEditorKeys.title,
                    controller: _titleController,
                    autofocus: !isEditing,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    validator: _validateTitle,
                    decoration: const InputDecoration(
                      labelText: '片段名称',
                      hintText: '例如：主歌扫弦',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: PracticeSegmentEditorKeys.start,
                          controller: _startController,
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          validator: _validateStart,
                          decoration: const InputDecoration(
                            labelText: 'A 点',
                            hintText: '0:00',
                            helperText: '支持毫秒，如 1:23.500',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: PracticeSegmentEditorKeys.end,
                          controller: _endController,
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.next,
                          validator: _validateEnd,
                          decoration: const InputDecoration(
                            labelText: 'B 点',
                            hintText: '0:30',
                            helperText: '必须晚于 A 点',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrecisePlaybackSpeedControl(
                    key: PracticeSegmentEditorKeys.preferredSpeed,
                    value: _preferredSpeed,
                    enabled: true,
                    label: '推荐练习倍速',
                    onChanged: (value) =>
                        setState(() => _preferredSpeed = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: PracticeSegmentEditorKeys.note,
                    controller: _noteController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: '练习笔记（可选）',
                      hintText: '记录指法、节奏或需要注意的地方',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: PracticeSegmentEditorKeys.cancel,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: PracticeSegmentEditorKeys.save,
                          onPressed: _submit,
                          child: Text(isEditing ? '保存修改' : '创建片段'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

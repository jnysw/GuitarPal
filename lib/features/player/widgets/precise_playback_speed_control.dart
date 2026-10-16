import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../media/playback/playback_speed.dart';

/// Stable keys exposed for widget tests and accessibility automation.
abstract final class PrecisePlaybackSpeedControlKeys {
  static const control = Key('precise_playback_speed_control');
  static const exactValue = Key('precise_playback_speed_exact_value');
  static const decrement = Key('precise_playback_speed_decrement');
  static const slider = Key('precise_playback_speed_slider');
  static const increment = Key('precise_playback_speed_increment');
  static const dialog = Key('precise_playback_speed_dialog');
  static const input = Key('precise_playback_speed_input');
  static const cancel = Key('precise_playback_speed_cancel');
  static const confirm = Key('precise_playback_speed_confirm');

  static Key preset(double value) {
    final hundredths = (normalizePlaybackSpeed(value) * 100).round();
    return ValueKey('precise_playback_speed_preset_$hundredths');
  }
}

/// A precise 0.50x–2.00x playback-speed control.
///
/// [onChanged] reports lightweight preview updates while the slider moves.
/// [onChangeEnd], when supplied, reports committed values after a slider drag,
/// step-button press, preset selection, or exact-value confirmation. A player
/// can therefore update its UI in [onChanged] and defer an expensive platform
/// call until [onChangeEnd].
class PrecisePlaybackSpeedControl extends StatefulWidget {
  const PrecisePlaybackSpeedControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onChangeEnd,
    this.presets = const [0.50, 0.75, 1.00, 1.25, 1.50, 2.00],
    this.sliderKey,
    this.label = '练习倍速',
    super.key,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String label;

  /// Optional quick choices. Passing an empty list hides the preset row.
  ///
  /// Values are normalized to the same 0.01 step as the slider.
  final List<double> presets;

  /// Overrides the default stable slider key when multiple controls coexist.
  final Key? sliderKey;

  @override
  State<PrecisePlaybackSpeedControl> createState() =>
      _PrecisePlaybackSpeedControlState();
}

class _PrecisePlaybackSpeedControlState
    extends State<PrecisePlaybackSpeedControl> {
  late double _draftValue = normalizePlaybackSpeed(widget.value);
  bool _isDragging = false;

  @override
  void didUpdateWidget(covariant PrecisePlaybackSpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldValue = normalizePlaybackSpeed(oldWidget.value);
    final newValue = normalizePlaybackSpeed(widget.value);
    if (!_isDragging && oldValue != newValue) {
      _draftValue = newValue;
    }
  }

  void _preview(double value) {
    final normalized = normalizePlaybackSpeed(value);
    if (_draftValue != normalized) {
      setState(() => _draftValue = normalized);
    }
    widget.onChanged(normalized);
  }

  void _commit(double value) {
    final normalized = normalizePlaybackSpeed(value);
    if (_draftValue != normalized) {
      setState(() => _draftValue = normalized);
    }
    widget.onChanged(normalized);
    widget.onChangeEnd?.call(normalized);
  }

  void _finishDrag(double value) {
    final normalized = normalizePlaybackSpeed(value);
    setState(() {
      _isDragging = false;
      _draftValue = normalized;
    });
    widget.onChangeEnd?.call(normalized);
  }

  Future<void> _showExactValueDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => _ExactPlaybackSpeedDialog(value: _draftValue),
    );
    if (!mounted || result == null) return;
    _commit(result);
  }

  List<double> get _normalizedPresets {
    final values =
        widget.presets
            .where((value) => value.isFinite)
            .map(normalizePlaybackSpeed)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final canDecrease = widget.enabled && _draftValue > minPlaybackSpeed;
    final canIncrease = widget.enabled && _draftValue < maxPlaybackSpeed;
    final presets = _normalizedPresets;

    return Semantics(
      key: PrecisePlaybackSpeedControlKeys.control,
      container: true,
      explicitChildNodes: true,
      label: '${widget.label}控制',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.label)),
              Semantics(
                button: true,
                enabled: widget.enabled,
                label: '当前倍速 ${formatPlaybackSpeed(_draftValue)}，输入精确值',
                excludeSemantics: true,
                child: TextButton(
                  key: PrecisePlaybackSpeedControlKeys.exactValue,
                  onPressed: widget.enabled ? _showExactValueDialog : null,
                  child: Text(formatPlaybackSpeed(_draftValue)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                key: PrecisePlaybackSpeedControlKeys.decrement,
                tooltip: '降低倍速 0.01',
                onPressed: canDecrease
                    ? () => _commit(_draftValue - playbackSpeedStep)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Slider(
                  key:
                      widget.sliderKey ??
                      PrecisePlaybackSpeedControlKeys.slider,
                  value: _draftValue,
                  min: minPlaybackSpeed,
                  max: maxPlaybackSpeed,
                  divisions: playbackSpeedDivisions,
                  label: formatPlaybackSpeed(_draftValue),
                  semanticFormatterCallback: (value) =>
                      '${normalizePlaybackSpeed(value).toStringAsFixed(2)} 倍速',
                  onChangeStart: widget.enabled
                      ? (_) => setState(() => _isDragging = true)
                      : null,
                  onChanged: widget.enabled ? _preview : null,
                  onChangeEnd: widget.enabled ? _finishDrag : null,
                ),
              ),
              IconButton(
                key: PrecisePlaybackSpeedControlKeys.increment,
                tooltip: '提高倍速 0.01',
                onPressed: canIncrease
                    ? () => _commit(_draftValue + playbackSpeedStep)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final preset in presets)
                  ChoiceChip(
                    key: PrecisePlaybackSpeedControlKeys.preset(preset),
                    label: Text(formatPlaybackSpeed(preset)),
                    selected: preset == _draftValue,
                    onSelected: widget.enabled ? (_) => _commit(preset) : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExactPlaybackSpeedDialog extends StatefulWidget {
  const _ExactPlaybackSpeedDialog({required this.value});

  final double value;

  @override
  State<_ExactPlaybackSpeedDialog> createState() =>
      _ExactPlaybackSpeedDialogState();
}

class _ExactPlaybackSpeedDialogState extends State<_ExactPlaybackSpeedDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: normalizePlaybackSpeed(widget.value).toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return '请输入倍速';
    if (!RegExp(r'^(?:\d+(?:\.\d{0,2})?|\.\d{1,2})$').hasMatch(value)) {
      return '倍速最多保留两位小数';
    }

    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) return '请输入有效数字';
    if (parsed < minPlaybackSpeed || parsed > maxPlaybackSpeed) {
      return '请输入 0.50 到 2.00 之间的数字';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = double.parse(_controller.text.trim());
    Navigator.of(context).pop(normalizePlaybackSpeed(value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: PrecisePlaybackSpeedControlKeys.dialog,
      title: const Text('输入精确倍速'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: PrecisePlaybackSpeedControlKeys.input,
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(
            labelText: '倍速',
            hintText: '例如 1.37',
            suffixText: 'x',
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: _validate,
        ),
      ),
      actions: [
        TextButton(
          key: PrecisePlaybackSpeedControlKeys.cancel,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: PrecisePlaybackSpeedControlKeys.confirm,
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

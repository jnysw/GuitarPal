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
    final hundredths = (value * 100).round();
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
    this.availableRates,
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

  /// Sorted discrete settings returned by an online player.
  final List<double>? availableRates;

  /// Overrides the default stable slider key when multiple controls coexist.
  final Key? sliderKey;

  @override
  State<PrecisePlaybackSpeedControl> createState() =>
      _PrecisePlaybackSpeedControlState();
}

class _PrecisePlaybackSpeedControlState
    extends State<PrecisePlaybackSpeedControl> {
  late double _draftValue = _normalize(widget.value);
  bool _isDragging = false;

  List<double>? get _rates =>
      widget.availableRates?.isNotEmpty == true ? widget.availableRates : null;

  double _normalize(double value) {
    final rates = _rates;
    return rates == null
        ? normalizePlaybackSpeed(value)
        : nearestPlaybackRate(value, rates);
  }

  String _format(double value) => '${value.toStringAsFixed(2)}x';

  @override
  void didUpdateWidget(covariant PrecisePlaybackSpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = _normalize(widget.value);
    if (!_isDragging && (oldWidget.value != widget.value || _rates != null)) {
      _draftValue = newValue;
    }
  }

  void _preview(double value) {
    final normalized = _normalize(value);
    if (_draftValue != normalized) {
      setState(() => _draftValue = normalized);
    }
    widget.onChanged(normalized);
  }

  void _commit(double value) {
    final normalized = _normalize(value);
    final displayed = _rates == null ? normalized : _normalize(widget.value);
    if (_draftValue != displayed) {
      setState(() => _draftValue = displayed);
    }
    widget.onChanged(normalized);
    widget.onChangeEnd?.call(normalized);
  }

  void _finishDrag(double value) {
    final normalized = _normalize(value);
    setState(() {
      _isDragging = false;
      _draftValue = _rates == null ? normalized : _normalize(widget.value);
    });
    widget.onChangeEnd?.call(normalized);
  }

  Future<void> _showExactValueDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) =>
          _ExactPlaybackSpeedDialog(value: _draftValue, rates: _rates),
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
    final rates = _rates;
    final enabled = widget.enabled && (rates == null || rates.length > 1);
    final rateIndex = rates?.indexOf(_normalize(_draftValue)) ?? 0;
    final canDecrease =
        enabled &&
        (rates == null ? _draftValue > minPlaybackSpeed : rateIndex > 0);
    final canIncrease =
        enabled &&
        (rates == null
            ? _draftValue < maxPlaybackSpeed
            : rateIndex < rates.length - 1);
    final presets = rates ?? _normalizedPresets;
    final sliderMax = rates == null
        ? maxPlaybackSpeed
        : (rates.length - 1).clamp(1, rates.length).toDouble();
    double fromSlider(double value) =>
        rates == null ? value : rates[value.round().clamp(0, rates.length - 1)];

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
                enabled: enabled,
                label:
                    '当前倍速 ${_format(_draftValue)}，${rates == null ? '输入精确值' : '输入目标倍速'}',
                excludeSemantics: true,
                child: TextButton(
                  key: PrecisePlaybackSpeedControlKeys.exactValue,
                  onPressed: enabled ? _showExactValueDialog : null,
                  child: Text(_format(_draftValue)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                key: PrecisePlaybackSpeedControlKeys.decrement,
                tooltip: rates == null ? '降低倍速 0.01' : '上一档倍速',
                onPressed: canDecrease
                    ? () => _commit(
                        rates == null
                            ? _draftValue - playbackSpeedStep
                            : rates[rateIndex - 1],
                      )
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Slider(
                  key:
                      widget.sliderKey ??
                      PrecisePlaybackSpeedControlKeys.slider,
                  value: rates == null ? _draftValue : rateIndex.toDouble(),
                  min: rates == null ? minPlaybackSpeed : 0,
                  max: sliderMax,
                  divisions: rates == null
                      ? playbackSpeedDivisions
                      : sliderMax.toInt(),
                  label: _format(_draftValue),
                  semanticFormatterCallback: (value) =>
                      '${_normalize(fromSlider(value)).toStringAsFixed(2)} 倍速',
                  onChangeStart: enabled
                      ? (_) => setState(() => _isDragging = true)
                      : null,
                  onChanged: enabled
                      ? (value) => _preview(fromSlider(value))
                      : null,
                  onChangeEnd: enabled
                      ? (value) => _finishDrag(fromSlider(value))
                      : null,
                ),
              ),
              IconButton(
                key: PrecisePlaybackSpeedControlKeys.increment,
                tooltip: rates == null ? '提高倍速 0.01' : '下一档倍速',
                onPressed: canIncrease
                    ? () => _commit(
                        rates == null
                            ? _draftValue + playbackSpeedStep
                            : rates[rateIndex + 1],
                      )
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
                    label: Text(_format(preset)),
                    selected: preset == _draftValue,
                    onSelected: enabled ? (_) => _commit(preset) : null,
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
  const _ExactPlaybackSpeedDialog({required this.value, this.rates});

  final double value;
  final List<double>? rates;

  @override
  State<_ExactPlaybackSpeedDialog> createState() =>
      _ExactPlaybackSpeedDialogState();
}

class _ExactPlaybackSpeedDialogState extends State<_ExactPlaybackSpeedDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.toStringAsFixed(2),
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
    final minimum = widget.rates?.first ?? minPlaybackSpeed;
    final maximum = widget.rates?.last ?? maxPlaybackSpeed;
    if (parsed < minimum || parsed > maximum) {
      return '请输入 ${minimum.toStringAsFixed(2)} 到 ${maximum.toStringAsFixed(2)} 之间的数字';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = double.parse(_controller.text.trim());
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: PrecisePlaybackSpeedControlKeys.dialog,
      title: Text(widget.rates == null ? '输入精确倍速' : '输入目标倍速'),
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
          decoration: InputDecoration(
            labelText: '倍速',
            hintText: '例如 1.37',
            suffixText: 'x',
            helperText: widget.rates == null ? null : '会选择最接近的可用档位',
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

import 'package:flutter/material.dart';

/// Wait for the overlay to be removed before changing Slider enabled state.
/// Flutter issue: https://github.com/flutter/flutter/issues/193706
/// Keep semantics enabled; do not patch framework assertions or hide controls from readers.
Future<T?> showPerformanceDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: builder,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

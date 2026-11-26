import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/practice_source/practice_source.dart';
import '../../library/practice_source_providers.dart';

class OpenOriginalSourceButton extends ConsumerWidget {
  const OpenOriginalSourceButton({
    required this.source,
    this.label = '打开原内容',
    super.key,
  });

  final PracticeSource source;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () async {
      try {
        if (await ref.read(sourceLauncherProvider).open(source)) return;
      } on Object {
        // The platform may not have a handler for this link.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暂时无法打开原内容')));
      }
    },
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(label),
  );
}

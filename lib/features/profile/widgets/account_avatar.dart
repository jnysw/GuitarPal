import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account_providers.dart';

class AccountAvatar extends ConsumerWidget {
  const AccountAvatar({super.key, this.path, this.preview, this.radius = 30});

  final String? path;
  final Uint8List? preview;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    final bytes =
        preview ??
        (path == null
            ? null
            : ref.watch(accountAvatarProvider(path)).asData?.value);
    final colors = Theme.of(context).colorScheme;
    final placeholder = Icon(Icons.person_rounded, size: radius);
    return Semantics(
      label: '用户头像',
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        child: bytes == null
            ? placeholder
            : ClipOval(
                child: Image.memory(
                  bytes,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
              ),
      ),
    );
  }
}

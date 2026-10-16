import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/platform/share_intent_gateway.dart';
import 'inbox_providers.dart';

class ShareIntentCoordinator extends ConsumerStatefulWidget {
  const ShareIntentCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShareIntentCoordinator> createState() =>
      _ShareIntentCoordinatorState();
}

class _ShareIntentCoordinatorState
    extends ConsumerState<ShareIntentCoordinator> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    final gateway = ref.read(shareIntentGatewayProvider);
    _subscription = gateway.sharedTextStream.listen(_handleSharedText);

    try {
      final initialText = await gateway.takeInitialSharedText();
      if (initialText != null && initialText.trim().isNotEmpty) {
        _handleSharedText(initialText);
      }
    } on Object {
      // Non-Android platforms and widget tests may not provide this channel.
    }
  }

  void _handleSharedText(String rawText) {
    if (!mounted) return;
    final item = ref.read(sharedItemParserProvider).parse(rawText);
    if (item.detectedUri == null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('分享内容中没有识别到网页链接')));
      return;
    }
    final inboxLocation = Uri(
      path: '/inbox',
      queryParameters: {'url': item.detectedUri.toString()},
    ).toString();
    unawaited(appRouter.push(inboxLocation, extra: item));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ShareIntentGateway {
  Stream<String> get sharedTextStream;

  Future<String?> takeInitialSharedText();

  void dispose();
}

class MethodChannelShareIntentGateway implements ShareIntentGateway {
  MethodChannelShareIntentGateway([
    this._channel = const MethodChannel('com.guitarpal/share'),
  ]) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<String> _sharedTextController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get sharedTextStream => _sharedTextController.stream;

  @override
  Future<String?> takeInitialSharedText() async {
    return _channel.invokeMethod<String>('getInitialSharedText');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'sharedText') return;

    final text = call.arguments;
    if (text is String && text.trim().isNotEmpty) {
      _sharedTextController.add(text);
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_sharedTextController.close());
  }
}

final shareIntentGatewayProvider = Provider<ShareIntentGateway>((ref) {
  final gateway = MethodChannelShareIntentGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

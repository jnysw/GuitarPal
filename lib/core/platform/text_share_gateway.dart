import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TextShareResult { opened, unavailable }

abstract interface class TextShareGateway {
  Future<TextShareResult> share({
    required String subject,
    required String text,
  });
}

class MethodChannelTextShareGateway implements TextShareGateway {
  const MethodChannelTextShareGateway([
    this._channel = const MethodChannel('com.guitarpal/share'),
  ]);

  final MethodChannel _channel;

  @override
  Future<TextShareResult> share({
    required String subject,
    required String text,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>('shareText', {
        'subject': subject,
        'text': text,
      });
      return opened == true
          ? TextShareResult.opened
          : TextShareResult.unavailable;
    } on MissingPluginException {
      return TextShareResult.unavailable;
    } on PlatformException {
      return TextShareResult.unavailable;
    }
  }
}

final textShareGatewayProvider = Provider<TextShareGateway>((ref) {
  return const MethodChannelTextShareGateway();
});

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/features/audio_tools/data/algorithm_service_configuration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('deployment configuration is read from the Android build, without a user input flow', () async {
    const channel = MethodChannel('com.guitarpal/algorithm_audio_import');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'serviceConfiguration');
          return {'baseUrl': ' https://algorithm.example '};
        });
    try {
      expect(
        await const AlgorithmServiceConfiguration().load(),
        'https://algorithm.example',
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}

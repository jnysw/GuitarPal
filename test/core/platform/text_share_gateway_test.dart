import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/text_share_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guitarpal/text_share_test');
  const gateway = MethodChannelTextShareGateway(channel);
  late List<MethodCall> calls;
  Object? response;

  setUp(() {
    calls = [];
    response = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (response case final PlatformException error) throw error;
          return response;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the subject and Markdown body to the platform', () async {
    final result = await gateway.share(subject: '练习笔记', text: '# 标题\n\n正文');

    expect(result, TextShareResult.opened);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'shareText');
    expect(calls.single.arguments, {'subject': '练习笔记', 'text': '# 标题\n\n正文'});
  });

  test('reports unavailable when native sharing cannot be opened', () async {
    response = false;
    expect(
      await gateway.share(subject: '练习笔记', text: '正文'),
      TextShareResult.unavailable,
    );

    response = PlatformException(code: 'unavailable');
    expect(
      await gateway.share(subject: '练习笔记', text: '正文'),
      TextShareResult.unavailable,
    );
  });
}

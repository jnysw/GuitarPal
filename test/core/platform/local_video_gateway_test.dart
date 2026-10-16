import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/platform/local_video_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guitarpal/local_video_import');
  const gateway = MethodChannelLocalVideoGateway(channel);
  late List<MethodCall> calls;
  Object? response;

  setUp(() {
    calls = [];
    response = null;
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

  test('pickVideo sends the source and decodes native metadata', () async {
    response = <String, Object?>{
      'path': '/cache/video.mp4',
      'displayName': 'video.mp4',
      'sizeBytes': 4096.0,
      'durationMilliseconds': 12500,
      'width': 1920,
      'height': 1080.0,
    };

    final file = await gateway.pickVideo(LocalVideoPickOrigin.gallery);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'pickVideo');
    expect(calls.single.arguments, {'source': 'gallery'});
    expect(file?.path, '/cache/video.mp4');
    expect(file?.displayName, 'video.mp4');
    expect(file?.sizeBytes, 4096);
    expect(file?.duration, const Duration(milliseconds: 12500));
    expect(file?.width, 1920);
    expect(file?.height, 1080);
  });

  test('pickVideo preserves native cancellation as a null result', () async {
    final file = await gateway.pickVideo(LocalVideoPickOrigin.files);

    expect(file, isNull);
    expect(calls.single.arguments, {'source': 'files'});
  });

  test('commitDraft sends both identifiers and requires a result', () async {
    response = <String, Object?>{
      'path': '/files/video.mp4',
      'displayName': 'video.mp4',
      'sizeBytes': 100,
      'durationMilliseconds': 2000,
    };

    final file = await gateway.commitDraft(
      draftPath: '/cache/draft.mp4',
      sourceId: 'source-1',
    );

    expect(file.path, '/files/video.mp4');
    expect(calls.single.method, 'commitDraft');
    expect(calls.single.arguments, {
      'draftPath': '/cache/draft.mp4',
      'sourceId': 'source-1',
    });

    response = null;
    await expectLater(
      gateway.commitDraft(draftPath: '/cache/draft.mp4', sourceId: 'source-1'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'commit_failed',
        ),
      ),
    );
  });

  test('rejects incomplete metadata returned by the platform', () async {
    response = <String, Object?>{'path': '/cache/video.mp4'};

    await expectLater(
      gateway.pickVideo(LocalVideoPickOrigin.gallery),
      throwsA(isA<FormatException>()),
    );
  });

  test('forwards draft and managed-file cleanup calls', () async {
    await gateway.discardDraft('/cache/draft.mp4');
    await gateway.deleteManagedVideo('/files/video.mp4');

    expect(calls[0].method, 'discardDraft');
    expect(calls[0].arguments, {'path': '/cache/draft.mp4'});
    expect(calls[1].method, 'deleteManagedVideo');
    expect(calls[1].arguments, {'path': '/files/video.mp4'});
  });
}

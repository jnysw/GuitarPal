import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/media/adapters/bilibili_player_uri_builder.dart';

void main() {
  const builder = BilibiliPlayerUriBuilder();

  test('builds the official external player URL with an initial position', () {
    final now = DateTime.utc(2026, 10, 12);
    final source = PracticeSource(
      id: 'source-1',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.webReference,
      externalId: 'BV1B7411m7LV',
      title: 'B站练习',
      createdAt: now,
      updatedAt: now,
    );

    final uri = builder.build(source, startAt: const Duration(seconds: 42));

    expect(uri?.host, 'player.bilibili.com');
    expect(uri?.path, '/player.html');
    expect(uri?.queryParameters['bvid'], 'BV1B7411m7LV');
    expect(uri?.queryParameters['t'], '42');
    expect(uri?.queryParameters['danmaku'], '0');
  });

  test('returns null for short links without a resolved BV id', () {
    final now = DateTime.utc(2026, 10, 12);
    final source = PracticeSource(
      id: 'source-2',
      platform: SourcePlatform.bilibili,
      kind: SourceKind.webReference,
      title: 'B站短链接',
      originalUri: Uri.parse('https://b23.tv/example'),
      createdAt: now,
      updatedAt: now,
    );

    expect(builder.build(source), isNull);
  });
}

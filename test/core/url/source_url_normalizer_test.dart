import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/url/source_url_normalizer.dart';

void main() {
  final normalizer = SourceUrlNormalizer();

  test('detects a URL inside platform share copy', () {
    final uri = normalizer.detectUri('分享一个吉他教程 https://b23.tv/AbCd123 复制链接打开');

    expect(uri, Uri.parse('https://b23.tv/AbCd123'));
  });

  test('removes known tracking parameters but preserves content keys', () {
    final result = normalizer.normalize(
      Uri.parse(
        'HTTPS://WWW.YOUTUBE.COM/watch?v=abc123&utm_source=share&list=lesson#comments',
      ),
    );

    expect(
      result.canonicalUri.toString(),
      'https://www.youtube.com/watch?v=abc123&list=lesson',
    );
  });

  test('returns null when share text has no web URL', () {
    expect(normalizer.detectUri('今晚练习十分钟'), isNull);
  });
}

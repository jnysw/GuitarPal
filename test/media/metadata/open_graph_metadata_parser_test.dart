import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/metadata/open_graph_metadata_parser.dart';

void main() {
  const parser = OpenGraphMetadataParser();

  test('reads Open Graph fields regardless of attribute order', () {
    final metadata = parser.parse('''
      <html><head>
        <meta content="节奏 &amp; 击弦 &#x1F3B8;" property="og:title">
        <meta content="/covers/lesson.jpg?size=large&amp;v=2" property="og:image">
      </head></html>
      ''', baseUri: Uri.parse('https://example.com/lessons/one'));

    expect(metadata?.title, '节奏 & 击弦 🎸');
    expect(
      metadata?.thumbnailUri,
      Uri.parse('https://example.com/covers/lesson.jpg?size=large&v=2'),
    );
  });

  test('falls back to document title and normalizes whitespace', () {
    final metadata = parser.parse(
      '<html><head><title>  Alternate\n  Picking  </title></head></html>',
      baseUri: Uri.parse('https://example.com'),
    );

    expect(metadata?.title, 'Alternate Picking');
    expect(metadata?.thumbnailUri, isNull);
  });

  test('rejects insecure or executable image URLs', () {
    for (final image in [
      'http://example.com/cover.jpg',
      'javascript:alert(1)',
      'data:image/png;base64,AAAA',
    ]) {
      final metadata = parser.parse(
        '<meta property="og:image" content="$image">',
        baseUri: Uri.parse('https://example.com'),
      );
      expect(metadata, isNull);
    }
  });
}

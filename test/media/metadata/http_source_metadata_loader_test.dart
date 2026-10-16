import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/media/metadata/http_source_metadata_loader.dart';

void main() {
  const loader = HttpSourceMetadataLoader();

  test(
    'ignores non-web and local addresses without making a request',
    () async {
      expect(await loader.load(Uri.file('/tmp/video.mp4')), isNull);
      expect(await loader.load(Uri.parse('http://localhost/page')), isNull);
      expect(await loader.load(Uri.parse('http://127.0.0.1/page')), isNull);
      expect(await loader.load(Uri.parse('http://192.168.1.2/page')), isNull);
    },
  );
}

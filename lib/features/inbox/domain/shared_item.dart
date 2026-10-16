import 'package:uuid/uuid.dart';

import '../../../core/url/source_url_normalizer.dart';

class SharedItem {
  const SharedItem({
    required this.id,
    required this.rawText,
    required this.receivedAt,
    this.detectedUri,
  });

  final String id;
  final String rawText;
  final Uri? detectedUri;
  final DateTime receivedAt;
}

class SharedItemParser {
  SharedItemParser(this._normalizer, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final SourceUrlNormalizer _normalizer;
  final Uuid _uuid;
  final DateTime Function() _clock;

  SharedItem parse(String rawText) {
    return SharedItem(
      id: _uuid.v4(),
      rawText: rawText,
      detectedUri: _normalizer.detectUri(rawText),
      receivedAt: _clock().toUtc(),
    );
  }
}

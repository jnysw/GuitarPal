class SourceMetadata {
  const SourceMetadata({this.title, this.thumbnailUri});

  final String? title;
  final Uri? thumbnailUri;

  bool get isEmpty => title == null && thumbnailUri == null;
}

abstract interface class SourceMetadataLoader {
  Future<SourceMetadata?> load(Uri uri);
}

final class NoopSourceMetadataLoader implements SourceMetadataLoader {
  const NoopSourceMetadataLoader();

  @override
  Future<SourceMetadata?> load(Uri uri) async => null;
}

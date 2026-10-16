import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_source/source_capabilities.dart';

class ResolvedSource {
  const ResolvedSource({
    required this.platform,
    required this.kind,
    required this.originalUri,
    required this.canonicalUri,
    required this.title,
    required this.capabilities,
    this.externalId,
    this.thumbnailUri,
  });

  final SourcePlatform platform;
  final SourceKind kind;
  final Uri originalUri;
  final Uri canonicalUri;
  final String? externalId;
  final String title;
  final Uri? thumbnailUri;
  final SourceCapabilities capabilities;

  ResolvedSource copyWith({
    Uri? originalUri,
    Uri? canonicalUri,
    String? title,
    Uri? thumbnailUri,
  }) {
    return ResolvedSource(
      platform: platform,
      kind: kind,
      originalUri: originalUri ?? this.originalUri,
      canonicalUri: canonicalUri ?? this.canonicalUri,
      externalId: externalId,
      title: title ?? this.title,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      capabilities: capabilities,
    );
  }
}

abstract interface class PracticeSourceAdapter {
  bool canHandle(Uri uri);

  Future<ResolvedSource> resolve(Uri uri);

  Future<SourceCapabilities> getCapabilities(PracticeSource source);
}

import '../../../core/platform/local_video_gateway.dart';

class LocalVideoDraft {
  const LocalVideoDraft({
    required this.id,
    required this.origin,
    required this.file,
    required this.createdAt,
  });

  final String id;
  final LocalVideoPickOrigin origin;
  final LocalVideoFileInfo file;
  final DateTime createdAt;

  String get suggestedTitle {
    final name = file.displayName.trim();
    final lastDot = name.lastIndexOf('.');
    if (lastDot <= 0) return name.isEmpty ? '本地视频练习' : name;
    final withoutExtension = name.substring(0, lastDot).trim();
    return withoutExtension.isEmpty ? '本地视频练习' : withoutExtension;
  }
}

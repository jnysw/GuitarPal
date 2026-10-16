import 'package:flutter/material.dart';

import '../../../domain/practice_source/practice_source.dart';

class SourceArtwork extends StatelessWidget {
  const SourceArtwork({
    required this.platform,
    this.thumbnailUri,
    this.borderRadius = 14,
    this.fit = BoxFit.cover,
    super.key,
  });

  final SourcePlatform platform;
  final Uri? thumbnailUri;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = _ArtworkFallback(platform: platform);
    final thumbnail = thumbnailUri;
    final canLoad =
        thumbnail != null &&
        thumbnail.scheme == 'https' &&
        thumbnail.host.isNotEmpty &&
        thumbnail.userInfo.isEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: canLoad
          ? Image.network(
              thumbnail.toString(),
              key: ValueKey('source_artwork_$thumbnail'),
              fit: fit,
              headers: platform == SourcePlatform.bilibili
                  ? const {'Referer': 'https://www.bilibili.com/'}
                  : null,
              semanticLabel: '来源封面',
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null || wasSynchronouslyLoaded) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    fallback,
                    const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                );
              },
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.platform});

  final SourcePlatform platform;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Icon(
          _platformIcon(platform),
          color: colors.onPrimaryContainer,
          size: 30,
        ),
      ),
    );
  }
}

IconData _platformIcon(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => Icons.video_file_rounded,
    SourcePlatform.youtube => Icons.play_circle_fill_rounded,
    SourcePlatform.bilibili => Icons.smart_display_rounded,
    SourcePlatform.douyin => Icons.music_note_rounded,
    SourcePlatform.xiaohongshu => Icons.menu_book_rounded,
    SourcePlatform.genericWeb => Icons.public_rounded,
  };
}

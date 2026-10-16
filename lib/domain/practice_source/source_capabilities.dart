class SourceCapabilities {
  const SourceCapabilities({
    required this.canOpen,
    required this.canPlayInline,
    required this.canPlay,
    required this.canPause,
    required this.canSeek,
    required this.canChangeSpeed,
    required this.canLoop,
    required this.canReadPosition,
    required this.canReadDuration,
    required this.canImportLocalCopy,
  });

  final bool canOpen;
  final bool canPlayInline;
  final bool canPlay;
  final bool canPause;
  final bool canSeek;
  final bool canChangeSpeed;
  final bool canLoop;
  final bool canReadPosition;
  final bool canReadDuration;
  final bool canImportLocalCopy;

  static const reference = SourceCapabilities(
    canOpen: true,
    canPlayInline: false,
    canPlay: false,
    canPause: false,
    canSeek: false,
    canChangeSpeed: false,
    canLoop: false,
    canReadPosition: false,
    canReadDuration: false,
    canImportLocalCopy: false,
  );

  static const localVideo = SourceCapabilities(
    canOpen: true,
    canPlayInline: true,
    canPlay: true,
    canPause: true,
    canSeek: true,
    canChangeSpeed: true,
    canLoop: true,
    canReadPosition: true,
    canReadDuration: true,
    canImportLocalCopy: true,
  );

  static const bilibiliWeb = SourceCapabilities(
    canOpen: true,
    canPlayInline: true,
    canPlay: true,
    canPause: true,
    canSeek: true,
    canChangeSpeed: true,
    canLoop: true,
    canReadPosition: true,
    canReadDuration: true,
    canImportLocalCopy: false,
  );
}

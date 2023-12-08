/// Video file metadata
class VideoMetadata {
  /// Class initializer
  const VideoMetadata({
    required this.width,
    required this.height,
    required this.duration,
    required this.hasAudio,
    required this.filesize,
    required this.frameRate,
    required this.bitrate,
    required this.hasAlpha,
    required this.isHDR,
  });

  /// Video width
  final double width;

  /// Video height
  final double height;

  /// Video duration, in seconds
  final double duration;

  /// Video audio track presence
  final bool hasAudio;

  /// Video file size, in bytes
  final int filesize;

  /// Video framerate
  final double frameRate;

  /// Video bitrate, in KB
  final int bitrate;

  /// Alpha channel presence
  final bool hasAlpha;

  /// HDR data presence
  final bool isHDR;
}

/// Metadata fields
enum MetadataField {
  /// Video/audio duration, in seconds
  duration,
  
  /// Alpha channel presence
  hasAudio,
  
  /// Video FPS
  frameRate,
  
  /// Video/image width
  width,

  /// Video/image height
  height,
  
  /// File size
  filesize,

  /// Alpha channel presence
  hasAlpha,

  /// Animated image sequence presence
  isAnimated,

  /// HDR data presence
  isHDR,

  /// Video/audio file bitrate
  bitrate;
}

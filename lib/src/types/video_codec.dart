import 'dart:io';

/// Video Codecs
enum VideoCodec {
  /// Apple ProRes
  prores,

  /// H.264
  h264,

  /// H.265/HEVC
  h265,

  /// VP9
  vp9,

  /// AV1
  av1;

  /// Codec identifier
  String get value {
    switch (this) {
      case VideoCodec.prores:
        return Platform.isIOS || Platform.isMacOS
            ? 'prores_videotoolbox'
            : 'prores';
      case VideoCodec.h264:
        return Platform.isIOS || Platform.isMacOS
            ? 'h264_videotoolbox'
            : 'libx264';
      case VideoCodec.h265:
        return Platform.isIOS || Platform.isMacOS
            ? 'hevc_videotoolbox'
            : 'libx265';
      case VideoCodec.vp9:
        return 'libvpx-vp9';
      case VideoCodec.av1:
        return 'libaom-av1';
    }
  }

  /// Initialize `VideoCodec` value from the corresponding `String`
  static VideoCodec? fromString(String value) {
    switch (value) {
      case 'h264':
        return VideoCodec.h264;
      case 'h265':
        return VideoCodec.h265;
      case 'prores':
        return VideoCodec.prores;
      case 'vp9':
        return VideoCodec.vp9;
      case 'av1':
        return VideoCodec.av1;
      default:
        return null;
    }
  }
}

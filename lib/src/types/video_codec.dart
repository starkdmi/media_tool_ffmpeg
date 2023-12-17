/// Video Codecs
enum VideoCodec {
  // MediaCodec supported formats:
  // https://developer.android.com/guide/topics/media/platform/supported-formats

  /// Apple ProRes
  prores,

  /// H.264/AVC
  h264,

  /// H.265/HEVC
  h265;

  /// Codec identifier
  String get value {
    switch (this) {
      case VideoCodec.prores:
        return 'prores';
      case VideoCodec.h264:
        return 'h264'; // h264_mediacodec
      case VideoCodec.h265:
        return 'hevc'; // hevc_mediacodec
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
      default:
        return null;
    }
  }
}

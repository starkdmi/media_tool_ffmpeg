/// Audio Codecs
enum AudioCodec {
  // MediaCodec supported formats:
  // https://developer.android.com/guide/topics/media/platform/supported-formats

  /// Advanced Audio Coding
  aac,

  /// Opus Interactive Audio Codec
  opus,

  /// Free Lossless Audio Codec
  flac;

  /// Codec identifier
  String get value {
    switch (this) {
      case AudioCodec.aac:
        return 'aac';
      case AudioCodec.opus:
        return 'opus';
      case AudioCodec.flac:
        return 'flac';
    }
  }

  /// Initialize `AudioCodec` value from the corresponding `String`
  static AudioCodec? fromString(String value) {
    switch (value) {
      case 'aac':
        return AudioCodec.aac;
      case 'opus':
        return AudioCodec.opus;
      case 'flac':
        return AudioCodec.flac;
      default:
        return null;
    }
  }
}

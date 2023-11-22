import 'dart:io';

/// Audio Codecs
enum AudioCodec {
  /// Advanced Audio Coding
  aac,

  /// Opus Interactive Audio Codec
  opus,

  /// Free Lossless Audio Codec
  flac,

  /// Linear PCM
  lpcm,

  /// Apple Lossless Audio Codec
  alac,

  /// MPEG audio layer 3
  mp3;

  /// Codec identifier
  String get value {
    switch (this) {
      case AudioCodec.aac:
        return 'aac';
      case AudioCodec.opus:
        return 'libopus'; // or `opus` for ffmpeg built-in implementation
      case AudioCodec.flac:
        return 'flac';
      case AudioCodec.lpcm:
        return 'pcm_s16le';
      case AudioCodec.alac:
        if (Platform.isIOS || Platform.isMacOS) {
          // Use AudioToolBox instead of ffmpeg built-in implementation on Apple devides
          return 'alac_at';
        }
        return 'alac';
      case AudioCodec.mp3:
        return 'libmp3lame';
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
      case 'lpcm':
        return AudioCodec.lpcm;
      case 'alac':
        return AudioCodec.alac;
      case 'mp3':
        return AudioCodec.mp3;
      default:
        return null;
    }
  }
}

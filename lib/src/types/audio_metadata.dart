/// Audio file metadata 
class AudioMetadata {
  /// Class initializer
  const AudioMetadata({
    required this.duration,
    required this.bitrate,
    required this.filesize,
  });

  /// Audio duration, in seconds
  final double duration;

  /// Audio bitrate, in KB
  final int bitrate;

  // List<int> waveform = [];

  /// Audio file size, in bytes
  final int filesize;
}

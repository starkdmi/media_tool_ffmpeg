import 'dart:ui';
import 'package:media_tool_ffmpeg/media_tool_ffmpeg.dart';
import 'package:media_tool_platform_interface/media_tool_platform_interface.dart';

void main() {
  final mediaTool = MediaToolFFmpeg();

  // Compress video file
  final events = mediaTool.startVideoCompression(
    id: '10001', // unique id
    path: 'input.mp4',
    destination: 'output.mov',
    // Video
    videoSettings: const VideoSettings(
      codec: VideoCodec.h265,
      bitrate: 2000000, // 2 Mbps
      size: Size(1280.0, 1280.0), // size to fit in
      // quality, frame rate, atd.
    ),
    // Audio
    skipAudio: false,
    audioSettings: const AudioSettings(
      codec: AudioCodec.opus, 
      bitrate: 96000, // 96 Kbps
      // sample rate, quality, atd.
    ),
    // Metadata and file options
    skipMetadata: false,
    overwrite: true,
    deleteOrigin: false,
  );
}

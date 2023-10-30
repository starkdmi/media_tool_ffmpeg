// import 'dart:io';
import 'dart:ui';
import 'package:media_tool_platform_interface/media_tool_platform_interface.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_session.dart';
// import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

/// The FFmpeg implementation of [MediaToolPlatform].
class MediaToolFFmpeg extends MediaToolPlatform {
  /// Registers this class as the default instance of [MediaToolPlatform]
  static void registerWith() {
    MediaToolPlatform.instance = MediaToolFFmpeg();
  }

  /// Compress video file
  /// [id] - Unique process ID
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [videoSettings] - Video settings: codec, bitrate, quality, resolution
  /// [skipAudio] - If `true` then audio is skipped
  /// [audioSettings] - Audio settings: codec, bitrate, sampleRate
  /// [overwrite] - Should overwrite exisiting file at destination
  /// [deleteOrigin] - Should input video file be deleted on succeed compression
  @override
  Stream<CompressionEvent> startVideoCompression({
    required String id,
    required String path,
    required String destination,
    VideoSettings videoSettings = const VideoSettings(),
    bool skipAudio = false,
    AudioSettings audioSettings = const AudioSettings(),
    bool overwrite = false,
    bool deleteOrigin = false,
  }) {
    // TODO: implement startVideoCompression
    throw UnimplementedError();
  }

  /// Compress audio file
  /// [id] - Unique process ID
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [settings] - Audio settings: codec, bitrate, sampleRate
  /// [overwrite] - Should overwrite exisiting file at destination
  /// [deleteOrigin] - Should input audio file be deleted on succeed compression
  @override
  Stream<CompressionEvent> startAudioCompression({
    required String id,
    required String path,
    required String destination,
    AudioSettings settings = const AudioSettings(),
    bool overwrite = false,
    bool deleteOrigin = false,
  }) {
    // TODO: implement startAudioCompression
    throw UnimplementedError();
  }

  /// Cancel current compression process
  @override
  Future<bool> cancelCompression(String id) {
    // TODO: implement cancelCompression
    throw UnimplementedError();
  }

  /// Convert image file
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [settings] - Image settings: format, quality, size
  /// [overwrite] - Should overwrite exisiting file at destination
  /// [deleteOrigin] - Should input image file be deleted on succeed compression
  @override
  Future<ImageInfo?> imageCompression({
    required String path,
    required String destination,
    ImageSettings settings = const ImageSettings(),
    bool overwrite = false,
    bool deleteOrigin = false,
  }) async {
    // TODO: implement imageCompression
    throw UnimplementedError();
  }

  /// Extract thumbnails from video file
  /// [path] - Path location of input video file
  /// [requests] - Time points of thumbnails including destination path for each
  /// [settings] - Image settings: format, quality, size
  /// [transfrom] - A flag to apply preferred source video tranformations to thumbnail
  /// [timeToleranceBefore] - Time tolerance before specified time, in seconds
  /// [timeToleranceAfter] - Time tolerance after specified time, in seconds
  @override
  Future<List<VideoThumbnail>> videoThumbnails({
    required String path,
    required List<VideoThumbnailItem> requests,
    ImageSettings settings = const ImageSettings(),
    bool transfrom = true,
    double? timeToleranceBefore,
    double? timeToleranceAfter,
  }) {
    // TODO: implement videoThumbnails
    throw UnimplementedError();
  }
}

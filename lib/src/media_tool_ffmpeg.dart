import 'package:media_tool_platform_interface/media_tool_platform_interface.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';

/// The FFmpeg implementation of [MediaToolPlatform].
class MediaToolFFmpeg extends MediaToolPlatform {
  /// Registers this class as the default instance of [MediaToolPlatform]
  static void registerWith() {
    MediaToolPlatform.instance = MediaToolFFmpeg();
  }

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

  @override
  Future<bool> cancelCompression(String id) {
    // TODO: implement cancelCompression
    throw UnimplementedError();
  }

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

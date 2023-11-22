import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:media_tool_ffmpeg/src/ffmpeg_tool.dart' as ffmpeg;
import 'package:media_tool_platform_interface/media_tool_platform_interface.dart';

/// The FFmpeg implementation of [MediaToolPlatform].
class MediaToolFFmpeg extends MediaToolPlatform {
  /// Registers this class as the default instance of [MediaToolPlatform]
  static void registerWith() {
    MediaToolPlatform.instance = MediaToolFFmpeg();
  }

  /// Collection of active compression sessions
  final Map<String, FFmpegSession> _sessions = {};

  /// Map event to store/remove ffmpeg session object
  CompressionEvent _mapCompressionEvent({
    required String id,
    required CompressionEvent event,
  }) {
    switch (event.runtimeType) {
      case CompressionStartedEvent:
        // save session object for cancellation
        if (_sessions.containsKey(id)) {
          throw Exception('Compression session with id - $id already exists');
        }
        _sessions[id] = event.custom as FFmpegSession;

        // remove custom field (ffmpeg session object) from first event
        return const CompressionStartedEvent();
      case CompressionCompletedEvent:
      case CompressionCancelledEvent:
      case CompressionFailedEvent:
        // remove from sessions
        _sessions.remove(id);
        break;
    }
    return event;
  }

  /// Compress video file
  /// [id] - Unique process ID
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [videoSettings] - Video settings: codec, bitrate, quality, resolution
  /// [skipAudio] - If `true` then audio is skipped
  /// [audioSettings] - Audio settings: codec, bitrate, sampleRate
  /// [skipMetadata] - Flag to skip source video metadata
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
    bool skipMetadata = false,
    bool overwrite = false,
    bool deleteOrigin = false,
  }) async* {
    final size = videoSettings.size;
    final quality = videoSettings.quality?.toInt() ?? 28;
    // Convert bitrates to KB
    final videoBitrate =
        videoSettings.bitrate == null ? null : videoSettings.bitrate! ~/ 1000;
    final audioBitrate =
        audioSettings.bitrate == null ? null : audioSettings.bitrate! ~/ 1000;

    // Convert video codecs: h264, h265, prores -> prores, h264, h265, vp9, av1
    final videoCodec =
        ffmpeg.VideoCodec.fromString(videoSettings.codec.toString());
    // Convert audio codecs: aac, opus, flac -> aac, opus, flac, lpcm, alac, mp3
    final audioCodec =
        ffmpeg.AudioCodec.fromString(audioSettings.codec.toString());

    yield* ffmpeg.FFmpegTool.convertVideoFile(
      path: path,
      destination: destination,
      overwrite: overwrite,
      deleteOrigin: deleteOrigin,
      videoCodec: videoCodec,
      size: size != null ? max(size.width, size.height) : null,
      quality: quality,
      videoBitrate: videoBitrate,
      fps: videoSettings.frameRate,
      keepAlphaChannel: videoSettings.preserveAlphaChannel,
      skipMetadata: skipMetadata,
      skipAudio: skipAudio,
      audioCodec: audioCodec,
      audioBitrate: audioBitrate,
      sampleRate: audioSettings.sampleRate,
      disableHardwareAcceleration: videoSettings.disableHardwareAcceleration,
    ).map((event) => _mapCompressionEvent(id: id, event: event));
  }

  /// Compress audio file
  /// [id] - Unique process ID
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [settings] - Audio settings: codec, bitrate, sampleRate. Audio quality parameter is skipped and bitrate is used instead.
  /// [skipMetadata] - Flag to skip source file metadata
  /// [overwrite] - Should overwrite exisiting file at destination
  /// [deleteOrigin] - Should input audio file be deleted on succeed compression
  @override
  Stream<CompressionEvent> startAudioCompression({
    required String id,
    required String path,
    required String destination,
    AudioSettings settings = const AudioSettings(),
    bool skipMetadata = false,
    bool overwrite = false,
    bool deleteOrigin = false,
  }) async* {
    // Convert audio codecs: aac, opus, flac -> aac, opus, flac, lpcm, alac, mp3
    final codec = ffmpeg.AudioCodec.fromString(settings.codec.toString());

    // Audio quality
    // final quality = settings.quality?.toInt();

    // Convert bitrates to KB
    final bitrate = settings.bitrate == null ? null : settings.bitrate! ~/ 1000;

    yield* ffmpeg.FFmpegTool.convertAudioFile(
      path: path,
      destination: destination,
      codec: codec,
      bitrate: bitrate,
      sampleRate: settings.sampleRate,
      overwrite: overwrite,
      deleteOrigin: deleteOrigin,
      skipMetadata: skipMetadata,
    ).map((event) => _mapCompressionEvent(id: id, event: event));
  }

  /// Cancel current compression process
  @override
  Future<bool> cancelCompression(String id) async {
    // id not found
    if (!_sessions.containsKey(id)) return false;

    // cancel ffmpeg session
    await _sessions[id]?.cancel();

    // remove from sessions
    _sessions.remove(id);

    return true;
  }

  /// Convert image file
  /// [path] - Path location of input video file
  /// [destination] - Path location of output video file
  /// [settings] - Image settings: format, quality, size
  /// [skipMetadata] - Flag to skip source file metadata
  /// [overwrite] - Should overwrite exisiting file at destination
  /// [deleteOrigin] - Should input image file be deleted on succeed compression
  @override
  Future<ImageInfo?> imageCompression({
    required String path,
    required String destination,
    ImageSettings settings = const ImageSettings(),
    bool skipMetadata = false,
    bool overwrite = false,
    bool deleteOrigin = false,
  }) async {
    final size = settings.size;

    // Convert an image
    final result = await ffmpeg.FFmpegTool.convertImageFile(
      path: path,
      destination: destination,
      format: settings.format,
      size: size != null ? max(size.width, size.height) : null,
      cropSquare: settings.crop,
      quality: settings.quality?.toInt() ?? 75,
      // lossless: settings.lossless ?? false,
      skipAnimation: settings.skipAnimation,
      fps: settings.frameRate,
      overwrite: overwrite,
      deleteOrigin: deleteOrigin,
      skipMetadata: skipMetadata,
    );

    if (!result) {
      return null;
    }

    var format = settings.format;
    if (format == null) {
      // Get file extension
      final ext = destination.split('.').last;
      // Convert extension to image format
      format = ImageFormat.fromId(ext);

      // Include some extension variations
      if (format == null) {
        switch (ext) {
          case 'jpg':
            format = ImageFormat.jpeg;
            break;
          case 'heic':
            format = ImageFormat.heif;
            break;
        }
      }
    }

    // Return image info
    final metadata =
        await ffmpeg.FFmpegTool.getImageMetadata(path: destination);
    return ImageInfo(
      format: format ?? ImageFormat.jpeg,
      size: Size(metadata.width, metadata.height),
      isAnimated: metadata.isAnimated,
    );
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
  }) async {
    // Collect multiple futures
    final List<Future<void>> futures = [];
    for (final request in requests) {
      // TODO: Check if file exists, skip when overwrite is false

      final future = ffmpeg.FFmpegTool.videoThumbnail(
        path: path,
        destination: request.path,
        size: settings.size != null
            ? max(settings.size!.width, settings.size!.height).toInt()
            : null,
        position: request.time.toInt(),
        // overwrite: true,
      );
      futures.add(future);
    }

    // Wait for all the futures to complete
    await Future.wait(futures);

    // Process results
    final List<VideoThumbnail> thumbnails = [];
    for (final request in requests) {
      // Check if file exists and then add to thumbnails list
      if (File(request.path).existsSync()) {
        final thumbnail = VideoThumbnail(
            path: request.path,
            time: request.time,
            format: settings.format,
            size: settings.size);
        thumbnails.add(thumbnail);
      }
    }

    return thumbnails;
  }
}

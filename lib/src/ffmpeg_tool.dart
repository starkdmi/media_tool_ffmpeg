import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:media_tool_ffmpeg/src/types/types.dart' as types;
import 'package:media_tool_platform_interface/media_tool_platform_interface.dart';

/// Audio codec type reference
typedef AudioCodec = types.AudioCodec;

/// Video codec type reference
typedef VideoCodec = types.VideoCodec;

/// Metadata fields type reference
typedef MetadataField = types.MetadataField;

/// Video metadata type reference
typedef VideoMetadata = types.VideoMetadata;

/// Image metadata type reference
typedef ImageMetadata = types.ImageMetadata;

/// Audio metadata type reference
typedef AudioMetadata = types.AudioMetadata;

/// Temporary info object
class TempInfo implements MediaInfo {
  /// Public initializer
  const TempInfo({required this.url});

  /// File path
  @override
  final String url;
}

/// Process photo, video and audio media, includes type converting, compressing, thumbnails and more
class FFmpegTool {
  /// Execute ffmpeg command, on failure throw exception with description, on success return session
  static Future<FFmpegSession?> _execSync(String command) async {
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return session;
    } else if (ReturnCode.isCancel(returnCode)) {
      return null;
    } else {
      throw Exception('ffmpeg error: ${await session.getOutput()}');
    }
  }

  /// Execute ffmpeg command with [CompressionEvent] stream
  /// * [command] - ffmpeg command
  /// * [path] - source file path
  /// * [destination] - destination file path
  /// * [prefix] - prefix insreted before `-i` flag
  /// * [overwrite] - flag to overwrite destination file if exists
  /// * [duration] - duration in milliseconds, used for progress, no progress events when set to `null`
  static Stream<CompressionEvent> _exec({
    required String command,
    required String path,
    required String destination,
    String prefix = '',
    bool overwrite = false,
    double? duration,
  }) async* {
    final controller = StreamController<CompressionEvent>();
    final skipProgress = duration == null;
    var progress = 0.0;

    // check source file existence
    if (!File(path).existsSync()) {
      yield const CompressionFailedEvent(error: 'Source file not found.');
      return;
    }

    // check destination file existence when overwrite flag is set to `false`
    if (File(destination).existsSync() && !overwrite) {
      yield const CompressionFailedEvent(
        error: 'Destination file already exists, use overwrite flag to force.',
      );
      return;
    }

    // build command
    command =
        '${_base(overwrite: overwrite)} $prefix -i "$path" $command "$destination"';

    // run command with callbacks specified
    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          // on success
          // insure 100% progress event pushed
          if (!skipProgress && progress < 1.0) {
            controller.add(const CompressionProgressEvent(progress: 1));
          }

          // push completed event
          // this one contains temp info, which will be replaced with real info in caller
          controller
              .add(CompressionCompletedEvent(info: TempInfo(url: destination)));
          await controller.close();
        } else if (ReturnCode.isCancel(returnCode)) {
          // on cancelled
          // push cancellation event
          controller.add(const CompressionCancelledEvent());
          await controller.close();
        } else {
          // on failure
          // get error description
          final description = await session.getOutput();
          // push error event
          controller
              .add(CompressionFailedEvent(error: description ?? 'unknown'));
          await controller.close();
        }
      },
      null,
      skipProgress
          ? null
          : (stats) {
              // on progress
              // get current seek time
              final time = stats.getTime(); // in milliseconds
              // calculate the progress
              final current = time / duration;

              // push only unique progress events
              if (current != progress) {
                // update the progress
                progress = current;
                // push progress event
                controller.add(CompressionProgressEvent(progress: progress));
              }
            },
    );

    // push started event with session object for cancellation requests
    controller.add(CompressionStartedEvent(custom: session));

    yield* controller.stream;
  }

  /// Execute ffprobe command, on failure throw exception with description, on success return output
  /*static Future<String?> _execProbeSync(String command) async {
    final session = await FFprobeKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isCancel(returnCode)) {
      return null;
    }

    final output = await session.getOutput();
    if (ReturnCode.isSuccess(returnCode)) {
      return output;
    } else {
      throw Exception('ffprobe error: $output');
    }
  }*/

  /// flags used by every ffmpeg command
  static String _base({bool overwrite = false}) =>
      "-hide_banner -loglevel error ${overwrite ? "-y" : ""}";

  /// ffmpeg shortcut for settings optional lossless compression
  static String _lossless(bool lossless) => "-lossless ${lossless ? "1" : "0"}";

  /// ffmpeg shortcut for scaling down input image/video
  /// * if [size] is `null` no scalling applied
  /// * if [size] is positive the widest side of image will be [size] with preserving an aspect ratio
  static String _scaleFilter(double? size) {
    if (size == null) return '';
    return "scale='min($size,iw)':min'($size,ih)':force_original_aspect_ratio=decrease";
  }

  /// ffmpeg shortcut for cropping filter
  /// * if [size] is `null` no scalling applied
  /// * if [size] is positive the widest side of image will be [size] with preserving an aspect ratio
  static String _cropFilter(double? size) {
    if (size == null) return '';
    return "crop='min(iw,ih)':'min(iw,ih)'";
  }

  /// ffmpeg shortcut for setting max framerate
  static String _fpsFilter(int? fps) {
    if (fps == null) return '';
    return "fps=fps='min(source_fps,$fps/1)'";
  }

  /// shortcut for combining ffmpeg filters
  static String _filter(List<String> filters) {
    final filter = filters.where((f) => f.isNotEmpty).join(',');
    return filter.isEmpty ? '' : '-vf "$filter"';
  }

  /// Convert, resize and crop images
  /// * [path] original image
  /// * [destination] proceed image, destination specify an output image format via extension
  /// * [format] output image format
  /// * [size] widest side in pixels, if null original size returned
  /// * when [cropSquare] is `true` and [size] is not `null` image will be cropped to [size]x[size]
  /// * [quality] in range `[0, 100]`, `75` by default
  /// * set [lossless] to `true` for lossless compression
  /// * [skipAnimation] flag to skip animation data (to use primary frame only)
  /// * [fps] resulting animation frame rate, values smallers than 13 will cause an error for static images
  // * [preserveAlphaChannel] flag to preserve alpha channel in animated image sequence
  // * [backgroundColor] used when [preserveAlphaChannel] is set to `false` or alpha channel is not supported by output image format
  /// * [overwrite] flag to overwrite existing file at destination
  /// * [deleteOrigin] flag to delete original file after successful compression
  /// * [skipMetadata] skip image file metadata, default to `false`
  ///
  /// **Warning**: iOS HEIC is not supported
  static Future<bool> convertImageFile({
    required String path,
    required String destination,
    ImageFormat? format,
    double? size,
    bool cropSquare = false,
    int quality = 75,
    bool lossless = false,
    bool skipAnimation = false,
    int? fps,
    // TODO: Replacing alpha channel requires -filter_complex, but -vf is already used and they are incompatible
    // -filter_complex "color=0xF0F8FF,format=rgb24[c];[c][0]scale2ref[c][i];[c][i]overlay=format=auto:shortest=1,setsar=1"
    // bool preserveAlphaChannel = true,
    // Color? backgroundColor,
    bool overwrite = false,
    bool deleteOrigin = false,
    bool skipMetadata = false,
  }) async {
    // Get image metadata
    final info = await _getMetadata(
      path: path,
      fields: {MetadataField.isAnimated},
    );

    var isAnimated = info[MetadataField.isAnimated] as bool;
    if (skipAnimation) {
      isAnimated = false;
    }

    String? codec;
    switch (format) {
      case ImageFormat.heif:
        throw Exception('HEIC is not supported');
      case ImageFormat.png:
        if (isAnimated) codec = 'apng';
        break;
      case ImageFormat.gif:
        if (isAnimated) codec = 'gif';
        break;
      case ImageFormat.webp:
        if (isAnimated) codec = 'libwebp_anim';
        break;
      case ImageFormat.jpeg:
      case ImageFormat.tiff:
      case ImageFormat.bmp:
      case null:
        // static image format defined by file extension
        break;
    }
    final c = codec == null ? '' : '-c:v $codec';

    final String sizeFilter;
    if (size != null) {
      if (cropSquare) {
        sizeFilter = '${_cropFilter(size)},${_scaleFilter(size)}';
      } else {
        sizeFilter = _scaleFilter(size);
      }
    } else {
      sizeFilter = '';
    }

    // Optional frame rate adjustment
    final framerate = _fpsFilter(fps);

    // Filters - size and fps combined
    final filters = _filter([sizeFilter, framerate]);

    // Lossless compression
    final l = _lossless(lossless);

    // Metadata, -1 to skip all
    final m = '-map_metadata ${skipMetadata ? '-1' : '0'}';

    final session = await _execSync(
      '${_base(overwrite: overwrite)} -i "$path" $m $c $l -quality $quality $filters "$destination"',
    ); // -pix_fmt rgb24
    final result = session != null;

    // Delete origin
    if (result && deleteOrigin) {
      // Confirm the file at destination exists
      if (File(destination).existsSync()) {
        await File(path).delete();
      }
    }

    return result;
  }

  /// Convert GIF or Video file to Animated WebP
  /// * [path] original file
  /// * [destination] proceed animated image, should have the `.webp` extension
  /// * [size] widest side in pixels, if null original size returned
  /// * [quality] in range `[0, 100]`, `75` by default
  /// * set [lossless] to `true` for lossless compression
  /// * [fps] resulting animation frame rate
  /// * [overwrite] flag to overwrite existing file at destination
  static Future<bool> convertGIFVideoFile({
    required String path,
    required String destination,
    double? size,
    int quality = 75,
    bool lossless = false,
    int? fps,
    bool overwrite = false,
  }) async {
    final l = _lossless(lossless);
    final scale = _scaleFilter(size);
    final framerate = _fpsFilter(fps);
    final filters = _filter([scale, framerate]);
    // yuva420p color format used for animation alpha channel - -pix_fmt yuva420p
    final command =
        '${_base(overwrite: overwrite)} -i "$path" -map_metadata -1 $l -quality $quality $filters -loop 0 "$destination"';

    final session = await _execSync(command);
    return session != null;
  }

  /// Video thumbnail
  /// * [path] input video
  /// * [destination] proceed image, destination specify an output image format via extension
  /// * [size] widest side in pixels, if `null` original size returned
  /// * [position] time position in seconds, default to `1`
  /// * [overwrite] flag to overwrite existing file at destination
  static Future<void> videoThumbnail({
    required String path,
    required String destination,
    int? size,
    int position = 1,
    bool overwrite = false,
  }) async {
    // smallest side is size
    // final scale = size == null ? "" : "-vf \"scale=w='if(lte(iw,ih),min($size,iw),-1)':h='if(lte(iw,ih),-1,min($size,ih))'\"";
    // widest side is size
    final scale = _scaleFilter(size?.toDouble());
    final filter = _filter([scale]);

    final command =
        '${_base(overwrite: overwrite)} -i "$path" -ss $position -frames:v 1 $filter "$destination"'; // -lossless 1 -pix_fmt rgb24
    await _execSync(command);
  }

  /// Extract multiple video thumbnails as single animated WebP
  /// * [path] input video
  /// * [destination] resulting animated image, should be a valid `.webp` path
  /// * [frames] is amount of thumbnails to produce - resulting animation can contain less, for small or static file
  /// * [size] smallest side in pixels, if `null` original size returned
  /// * [framerate] is frame rate of ouput animated WebP image, default to `25`
  /// * [groupBy] set the frames batch size to analyze, default to `100`
  /// * [overwrite] flag to overwrite existing file at destination
  static Future<bool> videoThumbnails({
    required String path,
    required String destination,
    required int frames,
    double? size,
    int framerate = 25,
    int groupBy = 100,
    bool overwrite = false,
    // TODO: pass image quality with default to 75-85
    // TODO: pass ImageFormat to support `apng`, `gif` and `webp` formats
  }) async {
    final scale = _scaleFilter(size);

    // Animations between frames - https://superuser.com/a/834035
    /*ffmpeg -y -i video.mp4 -filter_complex "\
      select='lt(mod(n\,30)\,7)',thumbnail=100,\
      fade=t=out:st=4:d=1,setpts=PTS-STARTPTS[v0];\
      [0:v]fade=t=in:st=0:d=1,setpts=PTS-STARTPTS[v1];\
      [v0][v1]concat=n=2:v=1:a=0,format=yuv420p[v]" \
      -frames:v 7 -loop 0 -q 75 -framerate 0.6667 -map "[v]" preview.webp*/

    // A. a single animated WebP without any transition effects
    // file size containig 5 unique frames is 34KB for 1280x720 and 30KB for 640x480
    // `-vsync vfr` is required for skipping the same thumbnails
    // ffmpeg -y -i video.mp4 -vf "thumbnail=60" -vframes 5 -vsync vfr -c:v libwebp_anim -r 25 thumbnail.webp
    final filter = _filter([scale, 'thumbnail=$groupBy']);
    final command =
        '${_base(overwrite: overwrite)} -i "$path" $filter -vframes $frames -vsync vfr -c:v libwebp_anim -r $framerate "$destination"';
    final session = await _execSync(command);

    // $_base -i \"$path\" $filter -frames:v $frames -loop 0 -q 75-100 -framerate 0.6667 -c:v libwebp_anim \"$destination\"

    // B. Use 5 separate WebP images
    // all files combined are 90KB for 1280x720 and 74KB for 640x480
    // codec should be specified, instead single file will be generated
    // ffmpeg -y -i video.mp4 -vf "thumbnail=60" -frames:v 5 -vsync vfr -c:v libwebp thumb_%02d.webp
    // `-vsync vfr` is required for skipping the same thumbnails
    //
    // same using another calling `select` filter instead of `thumbnail`
    // select=gt(scene\,0.5) selects frames that have more than 50% scene change compared to the previous frames
    // ffmpeg -i video.mp4 -vf "select=gt(scene\,0.5)" -frames:v 5 -vsync vfr -c:v libwebp thumb_%02d.webp

    return session != null;
  }

  /// Convert & resize video
  /// * [path] input video
  /// * [destination] proceed video, extension should be `.mp4`
  /// * [overwrite] flag to overwrite existing destination file
  /// * [deleteOrigin] flag to delete original file after successful compression
  /// * [videoCodec] allows manually specify the output video codec
  /// * [size] widest side in pixels, if `null` original size returned, minimal size is 480
  /// * [quality] video quality (crf - constant rate factor)
  /// * [videoBitrate] video bitrate in kilobits per second
  /// * [fps] video frame rate
  /// * [keepAlphaChannel] preserve alpha channel in video, default to `true`
  /// * [skipMetadata] skip metadata, default to `false`
  /// * [skipAudio] skip audio track, default to `false`
  /// * [audioCodec] allows manually specify the output audio codec
  /// * [audioBitrate] audio bitrate in kilobits per second
  /// * [sampleRate] audio sample rate in Hz
  /// * [disableHardwareAcceleration] disable hardware acceleration, default to `false`
  /// * [includeAllTracks] include all tracks in output file, by default FFmpeg select only one stream per type (video, audio, subtitle)
  static Stream<CompressionEvent> convertVideoFile({
    required String path,
    required String destination,
    bool overwrite = false,
    bool deleteOrigin = false,
    VideoCodec? videoCodec,
    double? size,
    int quality = 28,
    int? videoBitrate,
    int? fps,
    bool keepAlphaChannel = true,
    bool skipMetadata = false,
    bool skipAudio = false,
    AudioCodec? audioCodec,
    int? audioBitrate,
    int? sampleRate,
    bool disableHardwareAcceleration = false,
    bool includeAllTracks = false,
  }) async* {
    // Hardware Acceleration
    final String hardwareAcceleration;
    if (disableHardwareAcceleration) {
      hardwareAcceleration = '-hwaccel none';
    } else {
      if (Platform.isIOS || Platform.isMacOS) {
        hardwareAcceleration = '-hwaccel videotoolbox';
      } else {
        hardwareAcceleration = '-hwaccel auto';
      }
    }

    // Get video metadata
    final info = await _getMetadata(
      path: path,
      fields: {
        MetadataField.duration,
        MetadataField.hasAlpha,
        MetadataField.isHDR,
        MetadataField.bitrate,
        MetadataField.frameRate,
        if (!skipAudio) MetadataField.hasAudio,
        if (size == null) MetadataField.width,
        if (size == null) MetadataField.height,
      },
    );

    final duration = info[MetadataField.duration] as double;
    final hasAlpha = info[MetadataField.hasAlpha] as bool;
    final isHDR = info[MetadataField.isHDR] as bool;
    final frameRate = info[MetadataField.frameRate] as int;
    final nominalBitrate = info[MetadataField.bitrate] as int;
    final bool hasAudio;
    if (!skipAudio) {
      hasAudio = info[MetadataField.hasAudio] as bool;
    } else {
      hasAudio = false;
    }
    Size? videoSize;
    if (size == null) {
      final width = info[MetadataField.width] as double;
      final height = info[MetadataField.height] as double;
      videoSize = Size(width, height);
    }

    // Pixel format based on HDR and Alpha channel presence
    String? pixelFormat;
    var videoCodecName = videoCodec?.value;
    if (videoCodec != null) {
      if (isHDR) {
        // prores - supports HDR, yuv422p10le yuv444p10le yuva444p10le
        // prores_videotoolbox - supports HDR, p010le p210le p216le p410le p416le
        // h264 - no support on Apple and yuv420p10le yuv422p10le yuv444p10le support on others
        // h265 - supports HDR, use p010le on apple, and yuv420p10le, yuv422p10le, yuv444p10le, gbrp10le, rgbp10le on others
        // vp9 - supports HDR - https://developers.google.com/media/vp9/hdr-encoding, yuv420p10le yuv422p10le yuv444p10le, yuv440p10le, yuv420p12le, yuv422p12le, yuv440p12le, yuv444p12le, gbrp10le gbrp12le
        // av1 - supports HDR, yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le gbrp10le gbrp12le

        // TODO: color_primaries and color_transfer are still not set (!)

        if (Platform.isIOS || Platform.isMacOS) {
          if (videoCodec == VideoCodec.h264) {
            // fallback to libx264 for HDR support
            videoCodecName = 'libx264';

            pixelFormat = 'yuv422p10le -profile:v high';
          } else if (videoCodec == VideoCodec.h265) {
            pixelFormat = 'p010le -profile:v main10';
          } else if (videoCodec == VideoCodec.prores) {
            pixelFormat = 'p010le';
          }
        } else {
          pixelFormat = 'yuv422p10le';
        }
      } else if (hasAlpha && keepAlphaChannel) {
        // prores - supports alpha - yuva444p10le
        // prores_videotoolbox - supports alpha - bgra
        // h264 - no alpha support
        // h265 - only apple hevc supports alpha - bgra
        // vp9 - supports alpha - yuva420p
        // av1 - no alpha supports using ffmpeg (libaom), maybe only via experimental `-strict experimental -vf "format=yuva420p"`

        // TODO: If source codec is VP9 -> add video decoder -c:v libvpx-vp9 to preserve alpha

        if (videoCodec == VideoCodec.prores) {
          if (Platform.isIOS || Platform.isMacOS) {
            pixelFormat = 'bgra';
          } else {
            pixelFormat = 'yuva444p10le';
          }
        } else if (videoCodec == VideoCodec.h265) {
          if (Platform.isIOS || Platform.isMacOS) {
            pixelFormat =
                'bgra'; // TODO: FFmpeg will probably convert to `yuv420p`
          } else {
            // Use default format in next block
          }
        } else if (videoCodec == VideoCodec.vp9) {
          pixelFormat = 'yuva420p';
        } else {
          // Use default format in next block
        }
      }

      // Default format
      if (pixelFormat == null) {
        // prores - yuv422p10le
        // prores_videotoolbox - yuv420p bgra
        // h264 - yuv420p yuv422p yuv444p
        // h264_videotoolbox - yuv420p
        // h265 - yuv420p yuv422p yuv444p
        // hevc_videotoolbox - yuv420p
        // vp9 - yuv420p yuv422p yuv440p yuv444p
        // libaom-av1 - yuv420p yuv422p yuv444p

        if (!(Platform.isIOS || Platform.isMacOS) &&
            videoCodec == VideoCodec.prores) {
          pixelFormat = 'yuv422p10le';
        } else {
          pixelFormat = 'yuv420p';
        }
      }
    }
    final pixel = videoCodec == null ? '' : '-pix_fmt ${pixelFormat!}';

    // Size and frame rate filter
    final scale = _scaleFilter(size);
    final framerate = _fpsFilter(fps);
    final filter = _filter([scale, framerate]);

    // Bit rate
    final bitrate = videoBitrate == null ? '' : '-b:v ${videoBitrate}k';
    // Make video file compatible with Apple H.265
    final hevcTag = videoCodec == VideoCodec.h265 ? '-tag:v hvc1' : '';
    // Allow the video to begin playback while it is still being downloaded
    const movflag = '-movflags +faststart';
    // Preset
    const preset = '-preset fast'; // medium is default, slow, atd.
    // Quality, values in range 23-30 provide good quality, lower the better. values 0-51 allowed, 28 default
    // Lossless compression for H.265 may be achieved using `-x265-params lossless=1`
    final crf = '-crf $quality';
    // Video codec (optional)
    final vcodec = videoCodec == null ? '' : '-c:v $videoCodecName';
    // Video command combined
    final video =
        '$filter $vcodec $crf $bitrate $pixel $preset $movflag $hevcTag';

    // Audio
    final String audio;
    if (skipAudio) {
      audio = '-an';
    } else {
      final bitrate = audioBitrate == null ? '' : '-b:a ${audioBitrate}k';
      final srate = sampleRate == null ? '' : '-ar $sampleRate';
      final acodec = audioCodec == null ? '' : '-c:a ${audioCodec.value}';
      audio = '$acodec $bitrate $srate';
    }

    // Metadata, -1 to skip all
    final metadata = '-map_metadata ${skipMetadata ? '-1' : '0'}';
    // Select media tracks
    final tracks = includeAllTracks ? '-map 0' : '';

    final stream = _exec(
      command: '$metadata $tracks $video $audio',
      path: path,
      destination: destination,
      prefix: hardwareAcceleration,
      overwrite: overwrite,
      duration: duration * 1000, // convert to milliseconds,
    );

    await for (final event in stream) {
      if (event is CompressionCompletedEvent) {
        final info = VideoInfo(
          url: destination,
          codec: null, // types.VideoCodec.fromString(videoCodec.value)
          size: videoSize ??
              Size.zero, // target size is uknown when `size` is not null
          frameRate: fps ?? frameRate,
          duration: duration,
          bitrate: (videoBitrate ?? nominalBitrate) * 1000, // convert to bytes
          hasAlpha: hasAlpha,
          isHDR: isHDR,
          hasAudio: hasAudio,
        );

        // Replace info object with real info
        yield CompressionCompletedEvent(info: info);

        // Delete source file on success
        if (deleteOrigin) {
          await File(path).delete();
        }
      } else {
        yield event;
      }
    }
  }

  /// Convert audio
  /// * [path] original audio
  /// * [destination] proceed aduio, destination specify an output audio format via extension
  /// * [codec] allows manually specify the output audio codec
  /// * [bitrate] audio bitrate in kilobits per second, if `null` original value is used
  /// * [sampleRate] audio sample rate in Hz
  /// * [overwrite] flag to overwrite existing file at destination
  /// * [deleteOrigin] flag to delete original file after successful compression
  /// * [skipMetadata] skip audio file metadata, default to `false`
  static Stream<CompressionEvent> convertAudioFile({
    required String path,
    required String destination,
    AudioCodec? codec,
    int? bitrate,
    int? sampleRate,
    bool overwrite = false,
    bool deleteOrigin = false,
    bool skipMetadata = false,
  }) async* {
    // Codec
    final c = codec == null ? '' : '-c:a ${codec.value}';
    // Bitrate
    final b = bitrate == null ? '' : '-b:a ${bitrate}k';
    // Audio sample rate (24000 may be used for lower quality/size, 48000 is standard for OPUS)
    final ar = sampleRate == null ? '' : '-ar $sampleRate';
    // Metadata, -1 to skip all
    final m = '-map_metadata ${skipMetadata ? '-1' : '0'}';

    // TODO: MP3-specific
    // -ac 2 - stereo
    // -f s16le - signed 16-bit little-endian PCM, standard format to streaming
    // -profile:a aac_low - AAC-LC for streaming optimization (MP3 only)
    // for streaming it's better to specify CBR using -b:a 128k instead of leaving possible VBR when bitrate is `null`

    // TODO: quality parameter via `-aq ...` (codec-specific)

    // -vn - disable video
    final command = '$m -vn $ar $b $c';

    // Get audio duration for progress
    final info = await _getMetadata(
      path: path,
      fields: {MetadataField.duration},
    );
    final duration = info[MetadataField.duration] as double;

    final stream = _exec(
      command: command,
      path: path,
      destination: destination,
      overwrite: overwrite,
      duration: duration * 1000, // convert to milliseconds,
    );

    await for (final event in stream) {
      yield event;

      // Delete source file on success
      if (deleteOrigin && event is CompressionCompletedEvent) {
        await File(path).delete();
      }
    }
  }

  /// Extract audio metadata
  /// * [path] original audio
  static Future<AudioMetadata> getAudioMetadata({required String path}) async {
    // load audio related metadata fields
    final metadata = await _getMetadata(
      path: path,
      fields: {
        MetadataField.duration,
        MetadataField.filesize,
        MetadataField.bitrate,
      },
    );

    return AudioMetadata(
      duration: metadata[MetadataField.duration] as double,
      filesize: metadata[MetadataField.filesize] as int,
      bitrate: metadata[MetadataField.bitrate] as int,
    );
  }

  /// Extract image metadata
  /// * [path] original image
  static Future<ImageMetadata> getImageMetadata({required String path}) async {
    // load image related metadata fields
    final metadata = await _getMetadata(
      path: path,
      fields: {
        MetadataField.width,
        MetadataField.height,
        MetadataField.isAnimated,
        MetadataField.filesize,
      },
    );

    return ImageMetadata(
      width: metadata[MetadataField.width] as double,
      height: metadata[MetadataField.height] as double,
      isAnimated: metadata[MetadataField.isAnimated] as bool,
      filesize: metadata[MetadataField.filesize] as int,
    );
  }

  /// Extract video metadata
  /// * [path] original video
  static Future<VideoMetadata> getVideoMetadata({required String path}) async {
    // load video related metadata fields
    final metadata = await _getMetadata(
      path: path,
      fields: {
        MetadataField.duration,
        MetadataField.hasAudio,
        MetadataField.frameRate,
        MetadataField.width,
        MetadataField.height,
        MetadataField.filesize,
        MetadataField.hasAlpha,
        MetadataField.isHDR,
        MetadataField.bitrate,
      },
    );

    return VideoMetadata(
      width: metadata[MetadataField.width] as double,
      height: metadata[MetadataField.height] as double,
      duration: metadata[MetadataField.duration] as double,
      hasAudio: metadata[MetadataField.hasAudio] as bool,
      filesize: metadata[MetadataField.filesize] as int,
      frameRate: metadata[MetadataField.duration] as double,
      bitrate: metadata[MetadataField.bitrate] as int,
      hasAlpha: metadata[MetadataField.hasAlpha] as bool,
      isHDR: metadata[MetadataField.isHDR] as bool,
    );
  }

  /// Extract media metadata
  /// * [path] original video/audio/image path
  /// * [fields] set of fields to extract, by default all fields extracted
  static Future<Map<MetadataField, dynamic>> _getMetadata({
    required String path,
    Set<MetadataField> fields = const {
      MetadataField.duration,
      MetadataField.hasAudio,
      MetadataField.frameRate,
      MetadataField.width,
      MetadataField.height,
      MetadataField.filesize,
      MetadataField.hasAlpha,
      MetadataField.isAnimated,
      MetadataField.isHDR,
      MetadataField.bitrate,
    },
  }) async {
    final Map<MetadataField, dynamic> metadata = {};
    // retvieve media info
    final session = await FFprobeKit.getMediaInformation(path);
    final information = session.getMediaInformation();

    // TODO: Additional metadata like date, location, camera model
    // ffprobe -hide_banner -loglevel -8 -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json oludeniz.MOV
    // final allProperties = information?.getAllProperties();
    // final json = jsonEncode(allProperties);
    // await File('/Users/starkdmi/Downloads/all_properties.json').writeAsString(json);
    // print(allProperties?['format']['tags']);
    // { com.apple.quicktime.location.accuracy.horizontal: 4.766546, creation_time: 2021-10-30T10:04:10.000000Z, com.apple.quicktime.model: iPhone 14, com.apple.quicktime.creationdate: 2021-10-30T13:04:10+0300, major_brand: qt, com.apple.quicktime.make: Apple, minor_version: 0, com.apple.quicktime.location.ISO6709: +48.1282+029.1116+000.555/, com.apple.quicktime.software: 16.0, compatible_brands: qt }

    // TODO: Additional image metadata like date, location, camera model - https://pub.dev/packages/exif

    // video/audio duration
    if (fields.contains(MetadataField.duration)) {
      double duration = -1;
      final String? stringDuration = information?.getDuration();
      if (stringDuration != null) {
        final doubleDuration = double.tryParse(stringDuration);
        if (doubleDuration != null) duration = doubleDuration;
      }
      metadata[MetadataField.duration] = duration;
    }

    // audio channel presence, video frame rate, resolution, alpha and hdr presence
    if (fields.contains(MetadataField.hasAudio) ||
        fields.contains(MetadataField.frameRate) ||
        fields.contains(MetadataField.width) ||
        fields.contains(MetadataField.height) ||
        fields.contains(MetadataField.hasAlpha) ||
        fields.contains(MetadataField.isAnimated) ||
        fields.contains(MetadataField.isHDR)) {
      // alternativelly: ffprobe -loglevel error -i $path -show_streams -select_streams a
      bool hasAudio = false;
      bool? hasAlpha;
      bool? isHDR;
      bool? isAnimated;
      int? fps;
      double? width;
      double? height;
      // loop over all the streams
      final streams = information?.getStreams();
      if (streams != null) {
        for (final stream in streams) {
          final type = stream.getType();
          if (type == 'audio') {
            hasAudio = true;
          } else if (type == 'video') {
            // Video Codec
            // ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 video.mov
            // final codec = stream.getStringProperty('codec_name')

            // Alpha channel
            if (hasAlpha == null) {
              final pixelFormat = stream.getStringProperty('pix_fmt');
              if (hasAlpha == null && pixelFormat != null) {
                hasAlpha =
                    pixelFormat.contains('a'); // yuva, rgba, bgra, gbra, ...
              }
            }

            // HDR
            if (isHDR == null) {
              // ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of default=noprint_wrappers=1:nokey=1 video.mov
              final colorTransferFunction =
                  stream.getStringProperty('color_transfer');
              if (colorTransferFunction != null) {
                isHDR = colorTransferFunction == 'arib-std-b67' ||
                    colorTransferFunction == 'smpte2084'; // HLG or PQ
              }
            }

            // frame rate
            if (fps == null) {
              final String? framerateString =
                  stream.getStringProperty('r_frame_rate');
              final parts = framerateString?.split('/');
              if (parts != null) {
                if (parts.length == 1) {
                  fps = int.tryParse(parts.first) ?? -1;
                } else if (parts.length == 2) {
                  final part1 = int.tryParse(parts.first);
                  final part2 = int.tryParse(parts.last);
                  if (part1 != null && part2 != null && part2 != 0) {
                    fps = (part1 / part2).round();
                  }
                }
              }
            }

            // image animated sequence presence
            if (fields.contains(MetadataField.isAnimated)) {
              final framesString = stream.getStringProperty('nb_frames');
              if (framesString != null) {
                final framesNum = double.tryParse(framesString);
                if (framesNum != null && framesNum > 1) {
                  isAnimated = true;
                }
              }
            }

            // resolution
            if (width == null || height == null) {
              width = stream.getNumberProperty('width')?.toDouble() ?? -1.0;
              height = stream.getNumberProperty('height')?.toDouble() ?? -1.0;
            }
          }
        }
      }

      metadata[MetadataField.hasAudio] = hasAudio;
      metadata[MetadataField.frameRate] = fps ?? -1;
      metadata[MetadataField.width] = width ?? -1;
      metadata[MetadataField.height] = height ?? -1;
      metadata[MetadataField.hasAlpha] = hasAlpha ?? false;
      metadata[MetadataField.isHDR] = isHDR ?? false;
      metadata[MetadataField.isAnimated] = isAnimated ?? false;
    }

    // bitrate
    if (fields.contains(MetadataField.bitrate)) {
      int bitrate = -1;
      final String? stringBitrate = information?.getBitrate();
      if (stringBitrate != null) {
        final intBitrate = int.tryParse(stringBitrate);
        if (intBitrate != null) {
          bitrate = intBitrate ~/
              1000; // from bytes to KB - bandwidth divided by 1000 (instead of 1024)
        }
      }
      metadata[MetadataField.bitrate] = bitrate;
    }

    // file size in bytes
    if (fields.contains(MetadataField.filesize)) {
      int filesize = -1;
      final sizeString = information?.getSize();
      if (sizeString != null) {
        final intSize = int.tryParse(sizeString);
        if (intSize != null) filesize = intSize;
      }
      if (filesize == -1) {
        // get file size using file io
        filesize = await File(path).length();
      }
      metadata[MetadataField.filesize] = filesize;
    }

    // get duration, bitrate and file using ffprobe command
    // ffprobe -i audio.mp3 -show_entries format=duration,size,bit_rate -v quiet -of csv="p=0"
    // sec,bytes,bytes - 6.804000,109485,128730

    return metadata;
  }
}

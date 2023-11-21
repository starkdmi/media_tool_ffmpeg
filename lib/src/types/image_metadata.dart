/// Image file metadata 
class ImageMetadata {
  /// Class initializer
  const ImageMetadata({
    required this.width,
    required this.height,
    required this.isAnimated,
    required this.filesize,
  });

  /// Image width
  final double width; 

  /// Image height
  final double height; 

  /// Animated sequence presence
  final bool isAnimated;

  /// Image file size, in bytes
  final int filesize;
}

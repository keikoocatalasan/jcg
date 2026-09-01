import 'package:flutter/material.dart';

/// Wraps an image with a grayscale + high-contrast ColorFilter
/// to approximate a halftone/newsprint duotone look.
///
/// v1: ColorFilter approximation (grayscale + contrast boost).
/// v2 upgrade: true ordered-dither shader via FragmentProgram for
/// authentic newspaper halftone dots.
class DitherImage extends StatelessWidget {
  final ImageProvider image;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;

  const DitherImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Grayscale + high contrast filter stack to approximate duotone.
    // The matrix converts to grayscale, then contrast is boosted
    // by the saturation-like channel separation.
    const grayscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];

    Widget img = ColorFiltered(
      colorFilter: const ColorFilter.matrix(grayscaleMatrix),
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit ?? BoxFit.cover,
      ),
    );

    // Apply contrast boost via a second ColorFiltered layer.
    // This matrix increases contrast around the midpoint.
    const contrastMatrix = <double>[
      1.4, 0, 0, 0, -0.2 * 255,
      0, 1.4, 0, 0, -0.2 * 255,
      0, 0, 1.4, 0, -0.2 * 255,
      0, 0, 0, 1, 0,
    ];

    img = ColorFiltered(
      colorFilter: const ColorFilter.matrix(contrastMatrix),
      child: img,
    );

    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }

    return img;
  }
}

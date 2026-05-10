import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Starburst-shaped "AI" badge — a 16-point spiky medal with the word "AI"
/// centred inside. Inspired by the CSS clip-path "starburst" pattern, it
/// reads as an explicit "this is special" sticker (think New / Featured)
/// instead of a generic chip.
///
/// Use as a corner overlay on any icon tile to flag AI-powered surfaces.
/// Sized in absolute pixels so it scales predictably regardless of where
/// it's mounted (we don't want it sucking up flex space inside a Stack).
class StarburstAiBadge extends StatelessWidget {
  /// Diameter of the badge's bounding box in logical pixels.
  /// Default 24 fits cleanly over a 40px icon container.
  final double size;
  final Color color;
  final String label;

  const StarburstAiBadge({
    super.key,
    this.size = 24,
    this.color = AppColors.primary,
    this.label = 'AI',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft outer glow so the badge "lifts" off the tile surface.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          // The starburst shape itself — clipped from a solid colour fill.
          ClipPath(
            clipper: const _StarburstClipper(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    Color.lerp(color, Colors.black, 0.18)!,
                  ],
                ),
              ),
            ),
          ),
          // Label centred over the burst. Font auto-scales with size so a
          // bigger badge still feels balanced rather than a shouty "AI".
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 16-point starburst clipper. Coordinates are the same percentages used
/// in the reference CSS (`clip-path: polygon(...)`), translated to a 0..1
/// space and scaled to the widget's size at paint time.
class _StarburstClipper extends CustomClipper<Path> {
  const _StarburstClipper();

  // (x, y) pairs in a 0..1 unit square — alternating outer + inner radius
  // points around the perimeter to produce the medal-spike silhouette.
  static const List<List<double>> _points = [
    [1.0000, 0.5000],
    [0.8923, 0.5780],
    [0.9619, 0.6913],
    [0.8326, 0.7222],
    [0.8536, 0.8536],
    [0.7222, 0.8326],
    [0.6913, 0.9619],
    [0.5780, 0.8923],
    [0.5000, 1.0000],
    [0.4220, 0.8923],
    [0.3087, 0.9619],
    [0.2778, 0.8326],
    [0.1464, 0.8536],
    [0.1674, 0.7222],
    [0.0381, 0.6913],
    [0.1077, 0.5780],
    [0.0000, 0.5000],
    [0.1077, 0.4220],
    [0.0381, 0.3087],
    [0.1674, 0.2778],
    [0.1464, 0.1464],
    [0.2778, 0.1674],
    [0.3087, 0.0381],
    [0.4220, 0.1077],
    [0.5000, 0.0000],
    [0.5780, 0.1077],
    [0.6913, 0.0381],
    [0.7222, 0.1674],
    [0.8536, 0.1464],
    [0.8326, 0.2778],
    [0.9619, 0.3087],
    [0.8923, 0.4220],
  ];

  @override
  Path getClip(Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final p = _points[i];
      final x = p[0] * size.width;
      final y = p[1] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

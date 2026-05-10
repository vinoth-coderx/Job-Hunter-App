import 'package:flutter/material.dart';

/// Wraps a list item so it eases in (fade + slide-up + subtle scale) the
/// first time it is built. Cards animate independently as they enter the
/// viewport — no manual controllers, no staggering math.
///
/// Drop-in replacement for any existing `itemBuilder` child:
///
///   itemBuilder: (_, i) => AnimatedListItem(child: JobCard(...)),
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutCubic,
    this.slideFrom = 24,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  /// Vertical pixels the item starts below its final resting position.
  final double slideFrom;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, t, inner) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * slideFrom),
            child: Transform.scale(
              scale: 0.96 + (0.04 * t),
              child: inner,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

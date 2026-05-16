import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Animated, premium-feel backdrop for the auth screens.
///
/// Combines the existing soft vertical gradient with three slow-drifting
/// blurred orbs and a subtle noise-like grid so the screen never reads as
/// flat. Cheap to render (a `Stack` + three blurred circles), and the
/// drift uses a single `AnimationController` so there's no cost beyond a
/// repaint per orb per tick.
class AnimatedAuthBackground extends StatefulWidget {
  final Widget child;
  const AnimatedAuthBackground({super.key, required this.child});

  @override
  State<AnimatedAuthBackground> createState() => _AnimatedAuthBackgroundState();
}

class _AnimatedAuthBackgroundState extends State<AnimatedAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [context.gradientTop, context.gradientBottom],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _OrbsPainter(progress: _ctrl.value, isDark: context.isDark),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _OrbsPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(
        seed: 0.0,
        baseAlpha: isDark ? 0.22 : 0.32,
        color: AppColors.primary,
        radius: size.width * 0.55,
        centerX: size.width * 0.18,
        centerY: size.height * 0.16,
        driftX: size.width * 0.08,
        driftY: size.height * 0.05,
      ),
      _Orb(
        seed: 0.33,
        baseAlpha: isDark ? 0.18 : 0.22,
        color: const Color(0xFF6FA8FF),
        radius: size.width * 0.5,
        centerX: size.width * 0.92,
        centerY: size.height * 0.28,
        driftX: size.width * 0.07,
        driftY: size.height * 0.06,
      ),
      _Orb(
        seed: 0.66,
        baseAlpha: isDark ? 0.14 : 0.18,
        color: const Color(0xFF8FC2FF),
        radius: size.width * 0.6,
        centerX: size.width * 0.5,
        centerY: size.height * 0.92,
        driftX: size.width * 0.1,
        driftY: size.height * 0.04,
      ),
    ];

    for (final orb in orbs) {
      final t = (progress + orb.seed) * 2 * math.pi;
      final dx = orb.centerX + math.sin(t) * orb.driftX;
      final dy = orb.centerY + math.cos(t * 0.7) * orb.driftY;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            orb.color.withValues(alpha: orb.baseAlpha),
            orb.color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(dx, dy), radius: orb.radius),
        );
      canvas.drawCircle(Offset(dx, dy), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

class _Orb {
  final double seed;
  final double baseAlpha;
  final Color color;
  final double radius;
  final double centerX;
  final double centerY;
  final double driftX;
  final double driftY;
  const _Orb({
    required this.seed,
    required this.baseAlpha,
    required this.color,
    required this.radius,
    required this.centerX,
    required this.centerY,
    required this.driftX,
    required this.driftY,
  });
}

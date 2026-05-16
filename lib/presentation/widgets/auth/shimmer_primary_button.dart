import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../app_text.dart';
import 'staggered_reveal.dart';

/// Premium primary CTA — brand-gradient pill with a slow sheen that
/// sweeps across the surface every ~3 seconds, plus press-scale and
/// loading state. Used on the auth flows so the "Sign in" / "Create
/// account" button feels active even before it's tapped.
class ShimmerPrimaryButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  const ShimmerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 56,
  });

  @override
  State<ShimmerPrimaryButton> createState() => _ShimmerPrimaryButtonState();
}

class _ShimmerPrimaryButtonState extends State<ShimmerPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;
    // `width: double.infinity` is load-bearing: when the button shows
    // only the spinner (loading state), the inner Row collapses to the
    // 22px indicator and — without an explicit width — the Container,
    // Stack, and the surrounding ClipRRect all shrink with it, leaving
    // a tiny pill on screen. Forcing full-width keeps the surface
    // consistent across loading / idle / disabled states.
    return PressScale(
      onTap: disabled ? null : widget.onPressed,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF2F6BFF)],
                  ),
            color: disabled ? AppColors.primary.withValues(alpha: 0.4) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.36),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!disabled)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => CustomPaint(
                      painter: _SheenPainter(progress: _ctrl.value),
                    ),
                  ),
                ),
              if (widget.loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    AppText.button(widget.label, color: Colors.white),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  final double progress;
  _SheenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Move a soft diagonal highlight from -0.4 → 1.4 across the button
    // width. The padding lets the sheen fully enter and exit instead of
    // popping in mid-button.
    final t = -0.4 + progress * 1.8;
    final shader = LinearGradient(
      begin: const Alignment(-1.5, -1),
      end: const Alignment(1.5, 1),
      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
      colors: const [
        Color(0x00FFFFFF),
        Color(0x00FFFFFF),
        Color(0x55FFFFFF),
        Color(0x00FFFFFF),
        Color(0x00FFFFFF),
      ],
      transform: GradientTranslation(t * size.width, 0),
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _SheenPainter old) => old.progress != progress;
}

class GradientTranslation extends GradientTransform {
  final double dx;
  final double dy;
  const GradientTranslation(this.dx, this.dy);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()..translateByDouble(dx, dy, 0, 1);
  }
}

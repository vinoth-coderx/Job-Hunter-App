import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// App-wide brand logo. Renders the bundled PNG at
/// [AppConstants.appLogoAsset]; falls back to a tinted briefcase icon if the
/// asset is missing (so the app keeps working before the file is dropped in).
class AppLogo extends StatelessWidget {
  final double size;

  /// Corner radius for the rounded square. Pass `null` for a perfect circle.
  final double? borderRadius;

  /// Optional shadow (lifts the logo on light backgrounds).
  final bool elevated;

  const AppLogo({
    super.key,
    this.size = 100,
    this.borderRadius,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: size * 0.24,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AppConstants.appLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Fallback(size: size, radius: radius),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  final double radius;
  const _Fallback({required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.work_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Color palette extracted from the design screenshots
class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF2D7BFF);
  static const Color primaryDark = Color(0xFF1A5FE0);
  static const Color primaryLight = Color(0xFFEAF2FF);

  // Background - matches the soft blue gradient from screens
  static const Color background = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF7F9FC);
  static const Color gradientTop = Color(0xFFE8F0FE);
  static const Color gradientBottom = Color(0xFFFFFFFF);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color cardBorder = Color(0xFFEFEFEF);

  // Text
  static const Color textPrimary = Color(0xFF0A0A0A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textHint = Color(0xFFB0B0B0);

  // Bottom navigation black pill
  static const Color navBackground = Color(0xFF111111);
  static const Color navInactive = Color(0xFFFFFFFF);

  // Status colors
  static const Color urgent = Color(0xFFFF5A5A);
  static const Color urgentBg = Color(0xFFFFE5E5);
  static const Color success = Color(0xFF22C55E);
  static const Color successBg = Color(0xFFE6F9EE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEAF2FF);

  // Chips
  static const Color chipBackground = Color(0xFFF3F4F6);
  static const Color chipSelected = Color(0xFF111111);

  // Divider
  static const Color divider = Color(0xFFE5E7EB);

  // Shadow
  static Color shadowLight = Colors.black.withValues(alpha: 0.04);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.08);

  // Dark mode tokens. Used by AppTheme.dark and any widget that needs
  // to swap a hard-coded surface based on Theme.of(context).brightness.
  static const Color darkScaffoldBackground = Color(0xFF0B0B0F);
  static const Color darkSurface = Color(0xFF16171C);
  static const Color darkSurfaceVariant = Color(0xFF1E1F26);
  static const Color darkCardBorder = Color(0xFF2A2B33);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFB6B9C2);
  static const Color darkTextTertiary = Color(0xFF8A8D97);
  static const Color darkNavBackground = Color(0xFF0E0F13);
  static const Color darkGradientTop = Color(0xFF111319);
  static const Color darkGradientBottom = Color(0xFF0B0B0F);
}

/// Context-aware token getters. Lets widgets do `context.surface` instead
/// of `AppColors.surface` so that surfaces, text, and borders flip with
/// the active ThemeMode (light/dark/system).
///
/// Brand-tinted accents (`AppColors.primary`, `success`, `urgent`, `warning`)
/// stay the same in both modes — they're brand colors, not surfaces — so
/// they keep using the static `AppColors.*` constants.
extension AppPalette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get surface => isDark ? AppColors.darkSurface : AppColors.surface;
  Color get surfaceVariant =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
  Color get scaffoldBg =>
      isDark ? AppColors.darkScaffoldBackground : AppColors.scaffoldBackground;
  Color get gradientTop =>
      isDark ? AppColors.darkGradientTop : AppColors.gradientTop;
  Color get gradientBottom =>
      isDark ? AppColors.darkGradientBottom : AppColors.gradientBottom;
  Color get cardBorder =>
      isDark ? AppColors.darkCardBorder : AppColors.cardBorder;
  Color get divider => isDark ? AppColors.darkCardBorder : AppColors.divider;
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textPrimaryReverse =>
      isDark ? AppColors.textPrimary : AppColors.darkTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textTertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;

  /// Background color for soft "tag chips" (Full-Time, Remote, …) shown
  /// inside cards. Light mode uses the original pale-blue tint; dark mode
  /// uses a deeper translucent primary so the chip reads as accent rather
  /// than a bright slab.
  Color get primaryTintBg => isDark
      ? AppColors.primary.withValues(alpha: 0.18)
      : AppColors.primaryLight.withValues(alpha: 0.6);

  /// Foreground (text) color for soft tag chips. Slightly brighter in
  /// dark mode to maintain readable contrast against `primaryTintBg`.
  Color get primaryTintFg =>
      isDark ? const Color(0xFF93B7FF) : AppColors.primary;

  /// Neutral chip background used for category & filter chips.
  Color get chipBg =>
      isDark ? AppColors.darkSurfaceVariant : AppColors.chipBackground;

  /// Background of the *selected* state for primary chips. Light mode
  /// uses the original near-black pill; dark mode swaps to the brand
  /// primary so it stays visible against dark surfaces.
  Color get chipSelectedBg =>
      isDark ? AppColors.primary : AppColors.chipSelected;

  /// Status-pill backgrounds. The light variants are pastel washes
  /// (designed against white cards). On dark surfaces those wash-outs
  /// glow uncomfortably, so dark mode swaps to translucent tints of
  /// the same hue that sit naturally on `context.surface`.
  Color get successBg =>
      isDark ? AppColors.success.withValues(alpha: 0.18) : AppColors.successBg;
  Color get warningBg =>
      isDark ? AppColors.warning.withValues(alpha: 0.18) : AppColors.warningBg;
  Color get urgentBg =>
      isDark ? AppColors.urgent.withValues(alpha: 0.18) : AppColors.urgentBg;
  Color get infoBg =>
      isDark ? AppColors.info.withValues(alpha: 0.18) : AppColors.infoBg;
}

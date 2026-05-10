import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Single text widget the rest of the app should reach for. Replaces the
/// scattered `Text(..., style: AppTextStyles.bodyMedium.copyWith(color:
/// context.textPrimary))` boilerplate so light/dark colors flip correctly
/// without each caller having to remember the right token.
///
/// Pick a constructor based on semantics, not pixels:
///   - [AppText.h1] / [h2] / [h3] / [h4]  → page or section titles
///   - [AppText.body]  / [bodyLarge]      → default reading text
///   - [AppText.caption]                  → de-emphasised secondary text
///   - [AppText.label] / [labelSmall]     → form labels, chip labels
///   - [AppText.button]                   → button-style text on dark/brand fills
///
/// Override `color` only when the surface is non-themed (e.g. a brand
/// gradient, a colored chip background). For normal surfaces, leave it
/// unset and the theme picks the right contrast color.
enum _AppTextVariant {
  h1,
  h2,
  h3,
  h4,
  bodyLarge,
  body,
  caption,
  label,
  labelSmall,
  button,
  chip,
}

class AppText extends StatelessWidget {
  final String data;
  final _AppTextVariant _variant;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? height;
  final double? letterSpacing;

  const AppText.h1(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.h1;

  const AppText.h2(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.h2;

  const AppText.h3(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.h3;

  const AppText.h4(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.h4;

  const AppText.bodyLarge(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.bodyLarge;

  const AppText.body(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.body;

  const AppText.caption(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.caption;

  const AppText.label(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.label;

  const AppText.labelSmall(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.labelSmall;

  const AppText.button(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.button;

  const AppText.chip(
    this.data, {
    super.key,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
    this.letterSpacing,
  }) : _variant = _AppTextVariant.chip;

  TextStyle _baseStyle(BuildContext context) {
    switch (_variant) {
      case _AppTextVariant.h1:
        return AppTextStyles.h1.copyWith(color: context.textPrimary);
      case _AppTextVariant.h2:
        return AppTextStyles.h2.copyWith(color: context.textPrimary);
      case _AppTextVariant.h3:
        return AppTextStyles.h3.copyWith(color: context.textPrimary);
      case _AppTextVariant.h4:
        return AppTextStyles.h4.copyWith(color: context.textPrimary);
      case _AppTextVariant.bodyLarge:
        return AppTextStyles.bodyLarge.copyWith(color: context.textPrimary);
      case _AppTextVariant.body:
        return AppTextStyles.bodyMedium.copyWith(color: context.textPrimary);
      case _AppTextVariant.caption:
        return AppTextStyles.bodySmall.copyWith(color: context.textSecondary);
      case _AppTextVariant.label:
        return AppTextStyles.label.copyWith(color: context.textSecondary);
      case _AppTextVariant.labelSmall:
        return AppTextStyles.labelSmall.copyWith(color: context.textSecondary);
      case _AppTextVariant.button:
        return AppTextStyles.button;
      case _AppTextVariant.chip:
        return AppTextStyles.chip.copyWith(color: context.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _baseStyle(context).copyWith(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
    );
    return Text(
      data,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

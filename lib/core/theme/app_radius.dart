import 'package:flutter/material.dart';

/// Centralised border-radius scale. The app standardises on `r10` for
/// inputs, sheets, and small surfaces so every TextField, modal handle,
/// and chip lines up visually instead of drifting between 8/12/14/16.
///
/// Reach for the largest token that still feels right for the surface;
/// don't invent intermediate values inline. If a new size is genuinely
/// needed, add it here so the rest of the app can adopt it consistently.
class AppRadius {
  AppRadius._();

  /// Pills (chips, status badges) — fully rounded.
  static const double pill = 50;

  /// Cards, large sheets, hero containers.
  static const double xl = 20;

  /// Section blocks, secondary containers.
  static const double lg = 16;

  /// Buttons, dialogs.
  static const double md = 14;

  /// Default for inputs, modals, small sheets.
  static const double input = 10;

  /// Tight chips, dense badges.
  static const double sm = 8;

  /// Tiny accents (e.g. inline tags inside text).
  static const double xs = 6;

  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/api_client.dart';
import '../../data/services/storage_service.dart';

/// Renders a user's avatar consistently across the app.
///
/// Handles three cases:
///   1. Absolute http(s) URL (e.g. Google profile photo) → load as-is.
///   2. Backend-relative path like `/api/v1/users/avatar/<id>` →
///      prepended with the API origin and Authorization header attached
///      (the avatar endpoint is auth-gated).
///   3. Missing / failed → fall back to a colored circle with initials.
///
/// Cache-busting note: after a successful avatar upload the path stays the
/// same, so we look for a `?v=…` suffix on the URL (set by AuthProvider on
/// upload) which forces CachedNetworkImage to fetch the fresh image.
class AppAvatar extends StatelessWidget {
  final String? url;
  final String? name;
  final double size;
  final Color? background;
  final Color? foreground;
  final BorderSide? border;

  const AppAvatar({
    super.key,
    required this.url,
    this.name,
    this.size = 48,
    this.background,
    this.foreground,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveUrl(url);
    final bgColor = background ?? AppColors.primaryLight;
    final fallback = _Initials(
      name: name,
      size: size,
      background: bgColor,
      foreground: foreground ?? AppColors.primary,
    );

    final image = (resolved == null)
        ? fallback
        : CachedNetworkImage(
            imageUrl: resolved,
            httpHeaders: _authHeaders(resolved),
            // BoxFit.cover scales the image so the smaller edge fills the
            // circle and the longer edge gets cropped — no transparent
            // corners, no letterboxing. width/height match the avatar size
            // so the image renders edge-to-edge inside the circular clip.
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, __) => Container(
              color: context.surfaceVariant,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => fallback,
          );

    // Solid fill behind the image guarantees that any transparent corners
    // (logos uploaded as PNGs with alpha) blend with the avatar's intended
    // background instead of showing whatever sits behind the widget.
    final filled = ColoredBox(color: bgColor, child: image);

    // Render order: outer container provides the circular clip + optional
    // border ring; the image fills the entire size including the area the
    // border draws over (the border is painted on top, so the image still
    // looks edge-to-edge).
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: border != null
            ? Border.fromBorderSide(border!)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: filled,
    );
  }

  /// Combine the API origin (scheme + host + port) with the relative path
  /// the backend stores. We use the *origin* not the full baseUrl because
  /// the backend already returns paths like `/api/v1/users/avatar/<id>`,
  /// which would otherwise double up to `/api/v1/api/v1/...`.
  ///
  /// Public so other media widgets (company logo, office photo) can reuse
  /// the same path-resolution rules without duplicating them.
  static String? resolveBackendUrl(String? raw) => _resolveUrl(raw);

  static String? _resolveUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = Uri.tryParse(ApiClient.instance.baseUrl);
    if (base == null) return trimmed;
    final port = base.hasPort ? ':${base.port}' : '';
    final origin = '${base.scheme}://${base.host}$port';
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$origin$path';
  }

  /// Backend avatar endpoints sit behind `authenticate` middleware, so
  /// CachedNetworkImage needs to send the Bearer token. External URLs
  /// (Google etc.) get no headers — sending one to a third party would
  /// leak our session token.
  static Map<String, String>? _authHeaders(String url) {
    if (!url.contains('/users/avatar')) return null;
    final token = StorageService.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }
}

class _Initials extends StatelessWidget {
  final String? name;
  final double size;
  final Color background;
  final Color foreground;

  const _Initials({
    required this.name,
    required this.size,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final letter = (name ?? '').trim().isEmpty
        ? '?'
        : (name!.trim()[0]).toUpperCase();
    return Container(
      width: size,
      height: size,
      color: background,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTextStyles.h2.copyWith(
          color: foreground,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

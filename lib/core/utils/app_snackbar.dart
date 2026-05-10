import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Variant drives the leading icon + accent stripe color.
enum _Variant { success, error, info }

/// Single entry point for floating toasts across the app.
///
/// Implemented over the root [Overlay] (not [ScaffoldMessenger]) so the
/// toast can sit anchored to the **top-right** corner, slide in from
/// off-screen on the right, and slide back out the same way on dismiss.
/// Material's SnackBar locks to the bottom — switching to an overlay was
/// the cleanest way to honour the requested placement without pulling in
/// a third-party toast package.
///
/// Two ergonomic guarantees match the previous SnackBar-based version:
///
/// 1. **Latest wins** — every show clears the existing toast first, so
///    rapid taps (e.g. mashed Apply button, retry storm) collapse to one
///    visible toast instead of stacking.
/// 2. **Close affordance** — every toast has an `x` icon that hides the
///    current bar immediately. Replaces the implicit "wait it out" UX.
class AppSnackbar {
  AppSnackbar._();

  static OverlayEntry? _entry;
  static _ToastController? _controller;

  static void success(BuildContext context, String message) =>
      _show(context, message, _Variant.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _Variant.error);

  static void info(BuildContext context, String message) =>
      _show(context, message, _Variant.info);

  static void _show(BuildContext context, String message, _Variant variant) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Latest wins: animate the previous toast out, then insert a fresh
    // one. We don't await the dismissal — the new one slides in over
    // the top of the leaving animation, which feels snappier than
    // making the user wait for the previous one to fully retract.
    _controller?.dismiss();
    _entry?.remove();
    _entry = null;
    _controller = null;

    final ctrl = _ToastController();
    _controller = ctrl;
    final entry = OverlayEntry(
      builder: (_) => _ToastHost(
        message: message,
        variant: variant,
        controller: ctrl,
        onDismissed: () {
          if (_entry != null) {
            _entry!.remove();
            _entry = null;
          }
          if (_controller == ctrl) _controller = null;
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

/// Tiny pub/sub used between [AppSnackbar] and the active [_ToastHost]
/// — the host owns its own AnimationController, but external callers
/// (close button, "latest wins" replace) need a way to ask it to
/// reverse the entry animation cleanly.
class _ToastController {
  VoidCallback? _onDismissRequested;

  void dismiss() => _onDismissRequested?.call();
}

class _ToastHost extends StatefulWidget {
  final String message;
  final _Variant variant;
  final _ToastController controller;
  final VoidCallback onDismissed;

  const _ToastHost({
    required this.message,
    required this.variant,
    required this.controller,
    required this.onDismissed,
  });

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    widget.controller._onDismissRequested = _dismiss;
    _anim.forward();
    // Auto-dismiss timer matches the prior SnackBar duration so existing
    // callers (Apply success, copy-link confirmations) feel unchanged.
    _autoDismiss = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    _autoDismiss?.cancel();
    _autoDismiss = null;
    if (_anim.status == AnimationStatus.dismissed) return;
    await _anim.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    widget.controller._onDismissRequested = null;
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color accent;
    switch (widget.variant) {
      case _Variant.success:
        icon = Icons.check_circle_rounded;
        accent = AppColors.success;
        break;
      case _Variant.error:
        icon = Icons.error_rounded;
        accent = AppColors.urgent;
        break;
      case _Variant.info:
        icon = Icons.info_rounded;
        accent = AppColors.info;
        break;
    }

    final media = MediaQuery.of(context);
    // Cap width so long messages still wrap inside the toast instead
    // of stretching the full screen — feels more like a "card-toast"
    // than an edge-to-edge banner.
    final maxWidth = (media.size.width - 24).clamp(0.0, 380.0);

    return Positioned(
      top: media.padding.top + 12,
      right: 12,
      child: SafeArea(
        bottom: false,
        left: false,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            // Slide-in from off-screen on the right (translateX = 100% of
            // its own width when t = 0) into resting position (0 when
            // t = 1). On dismiss the controller reverses, so the toast
            // exits along the same axis it entered — entry/exit symmetry.
            final t = Curves.easeOutCubic.transform(_anim.value);
            final dx = (1 - t) * (maxWidth + 16);
            return Opacity(
              opacity: _anim.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          widget.message,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkResponse(
                      onTap: _dismiss,
                      radius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

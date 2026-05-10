import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Animated "back to top" floating action button.
///
/// Drop into any [Scaffold.floatingActionButton] together with a
/// [ScrollController]. The FAB pops in (elastic scale + fade) once the
/// user has scrolled past [showAfterPixels] and breathes gently while
/// visible to draw the eye, then springs out when the user is back near
/// the top. Tap → haptic + smooth animated scroll to offset 0.
class ScrollToTopFab extends StatefulWidget {
  const ScrollToTopFab({
    super.key,
    required this.controller,
    this.showAfterPixels = 600,
    this.additionalCondition,
    this.backgroundColor,
    this.foregroundColor,
  });

  final ScrollController controller;
  final double showAfterPixels;

  /// Optional gate (e.g. only show when list has > N items).
  /// Returning `false` keeps the FAB hidden even past the offset.
  final bool Function()? additionalCondition;

  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _breath;
  late final AnimationController _press;

  late final Animation<double> _scaleEntry;
  late final Animation<double> _scaleBreath;
  late final Animation<double> _scalePress;

  bool _visible = false;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleEntry = CurvedAnimation(
      parent: _entry,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    );

    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _scaleBreath = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
    );

    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scalePress = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );

    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _entry.dispose();
    _breath.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position.pixels;
    final gateOk = widget.additionalCondition?.call() ?? true;
    final shouldShow = gateOk && pos > widget.showAfterPixels;
    if (shouldShow == _visible) return;

    _visible = shouldShow;
    if (shouldShow) {
      _entry.forward(from: 0);
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _entry.reverse();
    }
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    await _press.forward();
    _press.reverse();
    if (!widget.controller.hasClients) return;
    await widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foregroundColor ?? Colors.white;
    final solidBg = widget.backgroundColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleEntry, _scaleBreath, _scalePress]),
      builder: (context, child) {
        final combined =
            _scaleEntry.value * _scaleBreath.value * _scalePress.value;
        return IgnorePointer(
          ignoring: _scaleEntry.value < 0.05,
          child: Opacity(
            opacity: _scaleEntry.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: combined.clamp(0.0, 1.2),
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: solidBg,
              gradient: solidBg == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    )
                  : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              color: fg,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Bottom navigation with a single sliding pill indicator. The pill is the
/// only animated surface — when the user switches tabs it slides
/// horizontally to the new position via `AnimatedAlign`, and its inner
/// icon+label content crossfades via `AnimatedSwitcher`. This reads as
/// one fluid motion instead of two simultaneous shrink/grow animations.
class NavTabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const NavTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavTabItem>? items;
  final List<Color>? pillGradient;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items,
    this.pillGradient,
  });

  static const _defaultItems = <_NavItem>[
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavItem(
      label: 'Applied',
      icon: Icons.work_outline_rounded,
      activeIcon: Icons.work_rounded,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  List<_NavItem> get _items => items != null
      ? items!
          .map((i) => _NavItem(
                label: i.label,
                icon: i.icon,
                activeIcon: i.activeIcon,
              ))
          .toList(growable: false)
      : _defaultItems;

  static const _slideDuration = Duration(milliseconds: 380);
  static const _slideCurve = Curves.easeOutCubic;
  static const _swapDuration = Duration(milliseconds: 220);

  // Map an active index to a horizontal Alignment in [-1, 1].
  // For 3 tabs this gives -1 (left), 0 (center), 1 (right).
  Alignment _alignmentFor(int index) {
    if (_items.length == 1) return Alignment.center;
    return Alignment(((index * 2) / (_items.length - 1)) - 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barGradient = isDark
        ? const [Color(0xFF1A1A1A), AppColors.navBackground]
        : const [Color(0xFFFFFFFF), Color(0xFFF4F6FB)];
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.20)
        : Colors.black.withValues(alpha: 0.08);
    final topHighlightColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: barGradient,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              // Glass-edge highlight along the very top of the bar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: topHighlightColor,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      children: [
                        // Layer 1 — sliding active pill. Sits behind the
                        // tap row, so taps still hit the underlying slots.
                        IgnorePointer(
                          child: AnimatedAlign(
                            alignment: _alignmentFor(currentIndex),
                            duration: _slideDuration,
                            curve: _slideCurve,
                            child: FractionallySizedBox(
                              widthFactor: 1 / _items.length,
                              child: Center(
                                child: _ActivePill(
                                  item: _items[currentIndex],
                                  swapKey: currentIndex,
                                  swapDuration: _swapDuration,
                                  gradient: pillGradient,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Layer 2 — tap targets. Inactive slots show their
                        // icon; the active slot's icon is hidden (the pill
                        // above renders the active state).
                        Row(
                          children: List.generate(_items.length, (i) {
                            final isActive = i == currentIndex;
                            return Expanded(
                              child: _TapSlot(
                                item: _items[i],
                                isActive: isActive,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onTap(i);
                                },
                                swapDuration: _swapDuration,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// The active pill: gradient background, drop-shadow glow, and a content
/// area whose icon+label crossfades when the active tab changes.
class _ActivePill extends StatelessWidget {
  final _NavItem item;
  final int swapKey;
  final Duration swapDuration;
  final List<Color>? gradient;

  const _ActivePill({
    required this.item,
    required this.swapKey,
    required this.swapDuration,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradient ?? const [AppColors.primary, AppColors.primaryDark];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.50),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: swapDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        // Long labels (e.g. "Applicants") on a 4-tab bar can exceed the
        // 1/4-slot width allotted to the pill. Wrap in FittedBox so the
        // pill auto-scales the icon+text to fit instead of overflowing
        // horizontally.
        child: FittedBox(
          key: ValueKey<int>(swapKey),
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.activeIcon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tap target for a single tab slot. Inactive slots render a faded outline
/// icon; the active slot hides its icon (the sliding pill renders it
/// instead) but keeps the same hit area so re-tapping is consistent.
class _TapSlot extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final Duration swapDuration;

  const _TapSlot({
    required this.item,
    required this.isActive,
    required this.onTap,
    required this.swapDuration,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : AppColors.textSecondary;
    final splashColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.primary.withValues(alpha: 0.10);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.primary.withValues(alpha: 0.05);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      splashColor: splashColor,
      highlightColor: highlightColor,
      child: Center(
        child: AnimatedOpacity(
          duration: swapDuration,
          opacity: isActive ? 0.0 : 1.0,
          child: Icon(
            item.icon,
            color: inactiveColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

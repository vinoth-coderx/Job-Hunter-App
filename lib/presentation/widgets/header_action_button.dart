import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Pill-style icon button used in screen headers for top-right actions
/// (notifications, messages, share, etc.). Optional unread/badge count
/// renders a circular red counter on the icon's top-right corner — same
/// look across notification bell, messages, and any future header icon.
class HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  final String? tooltip;

  const HeaderActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: context.surface,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(10),
            side: BorderSide(color: context.cardBorder),
          ),
          icon: Icon(
            icon,
            color: context.textPrimary,
            size: 20,
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.urgent,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

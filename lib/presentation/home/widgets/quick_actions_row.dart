import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';

/// Compact icon+label row pinned near the top of the home feed.
/// Replaces the bulky Auto-Apply / Streak cards so the home feed stays
/// scannable. Tap → existing routes.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: 'Auto-Apply',
        color: AppColors.primary,
        route: AppRoutes.autoApply,
      ),
      _QuickAction(
        icon: Icons.emoji_events_rounded,
        label: 'Achievements',
        color: const Color(0xFFF59E0B),
        route: AppRoutes.badges,
      ),
      _QuickAction(
        icon: Icons.bookmark_rounded,
        label: 'Saved',
        color: const Color(0xFF10B981),
        route: AppRoutes.savedJobs,
      ),
      _QuickAction(
        icon: Icons.workspace_premium_rounded,
        label: 'Assessments',
        color: const Color(0xFF8B5CF6),
        route: AppRoutes.skillAssessments,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          for (final a in actions) ...[
            Expanded(child: _QuickActionTile(action: a)),
            if (a != actions.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () => Navigator.pushNamed(context, a.route),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: Duration(milliseconds: _down ? 120 : 180),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(a.icon, color: a.color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                a.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

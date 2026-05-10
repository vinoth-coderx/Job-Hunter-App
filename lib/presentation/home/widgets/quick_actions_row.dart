import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/starburst_ai_badge.dart';

/// Horizontal scroll strip of quick shortcuts pinned near the top of the
/// home feed. Mixes the heavy-use destinations (Auto-Apply, Saved) with
/// the AI features (Profile Coach, Skill Gap).
///
/// Horizontal scroll over a fixed 4-tile row because we now have 7+
/// shortcuts to expose; first 4 fit on-screen, the rest peek at the right
/// edge to invite a swipe.
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
        ai: true,
      ),
      _QuickAction(
        icon: Icons.psychology_alt_outlined,
        label: 'Coach',
        color: const Color(0xFFEC4899),
        route: AppRoutes.profileOptimizer,
        ai: true,
      ),
      _QuickAction(
        icon: Icons.insights_rounded,
        label: 'Skill Gap',
        color: const Color(0xFF8B5CF6),
        route: AppRoutes.skillGap,
        ai: true,
      ),
      _QuickAction(
        icon: Icons.bookmark_rounded,
        label: 'Saved',
        color: const Color(0xFF10B981),
        route: AppRoutes.savedJobs,
      ),
      _QuickAction(
        icon: Icons.workspace_premium_rounded,
        label: 'Quizzes',
        color: const Color(0xFF0EA5E9),
        route: AppRoutes.skillAssessments,
      ),
      _QuickAction(
        icon: Icons.emoji_events_rounded,
        label: 'Awards',
        color: const Color(0xFFF59E0B),
        route: AppRoutes.badges,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      // Sized to comfortably fit icon + AI badge overhang + single-line
      // label + padding without clipping. Single-line labels (no \n) keep
      // the heights uniform across the strip; longer destinations lose
      // their ampersand-y middle words ("Achievements" → "Awards") so we
      // don't have to compromise typography for the longest entry.
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _QuickActionTile(action: actions[i]),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  // AI tag → renders the starburst badge over the icon corner so the
  // user knows it's a smart feature, not a static destination.
  final bool ai;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.ai = false,
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
          width: 84,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: a.color.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon + AI starburst overlay. The Stack uses Clip.none so
              // the starburst's spikes can extend past the icon container
              // without being trimmed by the parent column's width.
              SizedBox(
                width: 48,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 25),
                    ),
                    if (a.ai)
                      // Top-right corner overhang. Negative offsets keep
                      // the starburst centred on the icon's corner so the
                      // spikes read as a sticker stuck on the icon.
                      Positioned(
                        top: -6,
                        right: -8,
                        child: StarburstAiBadge(
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                a.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.1,
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

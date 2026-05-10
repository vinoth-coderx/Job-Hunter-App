import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/services/gamification_service.dart';

/// Achievements & badges screen, sourced from the backend.
///
/// Single source of truth: [GamificationService] returns the canonical
/// 10 badges + the user's current/longest streak. We previously kept a
/// parallel local-only set of 7 badges that drifted from the server's
/// list (no streak badges, no assessment badge). Now both sides agree
/// and the user's earnedBadges history persists across devices.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final GamificationService _service = GamificationService.instance;

  BadgesSnapshot? _snapshot;
  StreakInfo? _streak;
  bool _loading = true;
  bool _checkInBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Parallel — both endpoints are independent, no need to serialise.
      final results = await Future.wait([
        _service.badges(),
        _service.getStreak(),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = results[0] as BadgesSnapshot;
        _streak = results[1] as StreakInfo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _checkIn() async {
    if (_checkInBusy) return;
    setState(() => _checkInBusy = true);
    try {
      final result = await _service.checkIn();
      if (!mounted) return;
      AppSnackbar.success(
        context,
        result.streakChanged
            ? 'Day ${result.streakCount} 🔥 — keep it going!'
            : 'Already checked in today.',
      );
      // Refresh badges since a streak milestone may have just unlocked.
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _checkInBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final streak = _streak;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Achievements',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800)),
            if (snapshot != null)
              Text(
                '${snapshot.unlocked} of ${snapshot.total} unlocked',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiary,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: context.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _content(snapshot!, streak),
      ),
    );
  }

  Widget _content(BadgesSnapshot snapshot, StreakInfo? streak) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Hero(unlocked: snapshot.unlocked, total: snapshot.total),
        if (streak != null) ...[
          const SizedBox(height: 14),
          _StreakCard(
            streak: streak,
            busy: _checkInBusy,
            onCheckIn: streak.checkedInToday ? null : _checkIn,
          ),
        ],
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final b in snapshot.badges) _BadgeTile(badge: b),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded,
            size: 48, color: context.textTertiary),
        const SizedBox(height: 12),
        Text('Couldn\'t load achievements',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary)),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final StreakInfo streak;
  final bool busy;
  final VoidCallback? onCheckIn;
  const _StreakCard({
    required this.streak,
    required this.busy,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.streakCount > 0
                      ? '${streak.streakCount}-day streak'
                      : 'Start your streak',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  streak.checkedInToday
                      ? 'You\'re in for today · longest ${streak.longestStreak}'
                      : 'Tap check in to keep it alive',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: busy ? null : onCheckIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: streak.checkedInToday
                  ? AppColors.success.withValues(alpha: 0.18)
                  : AppColors.primary,
              foregroundColor:
                  streak.checkedInToday ? AppColors.success : Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    streak.checkedInToday ? 'Done ✓' : 'Check in',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int unlocked;
  final int total;
  const _Hero({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -16,
            child: Icon(
              Icons.emoji_events_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 4,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.22),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$unlocked',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'of $total',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep showing up',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock badges as you build the habit',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Maps a backend badge id to a recognisable icon + tint. Falls back to
/// a generic icon for any unknown id, so a future server-side badge
/// just shows up with a default look until we add an entry here.
class _BadgeStyle {
  final IconData icon;
  final Color tint;
  const _BadgeStyle(this.icon, this.tint);

  static _BadgeStyle forId(String id) {
    switch (id) {
      case 'first_app':
        return const _BadgeStyle(Icons.send_rounded, AppColors.primary);
      case 'power_applicant_10':
        return const _BadgeStyle(Icons.bolt_rounded, AppColors.warning);
      case 'hunter_50':
        return const _BadgeStyle(Icons.gps_fixed_rounded, AppColors.urgent);
      case 'profile_starter':
        return const _BadgeStyle(
            Icons.account_circle_rounded, AppColors.info);
      case 'profile_pro':
        return const _BadgeStyle(
            Icons.workspace_premium_rounded, AppColors.success);
      case 'skill_stacker_5':
        return const _BadgeStyle(Icons.layers_rounded, AppColors.primary);
      case 'bookmarked':
        return const _BadgeStyle(Icons.bookmark_rounded, AppColors.warning);
      case 'streak_3':
        return const _BadgeStyle(
            Icons.local_fire_department_rounded, Color(0xFFFB923C));
      case 'streak_7':
        return const _BadgeStyle(
            Icons.whatshot_rounded, Color(0xFFEF4444));
      case 'first_assessment':
        return const _BadgeStyle(Icons.verified_rounded, AppColors.success);
      default:
        return const _BadgeStyle(
            Icons.emoji_events_rounded, AppColors.primary);
    }
  }
}

class _BadgeTile extends StatelessWidget {
  final ServerBadge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final style = _BadgeStyle.forId(badge.id);
    final unlocked = badge.unlocked;
    return InkWell(
      onTap: () => _showBadgeSheet(context, badge, style),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked
                ? style.tint.withValues(alpha: 0.4)
                : context.cardBorder,
            width: 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: style.tint.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: unlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            style.tint,
                            style.tint.withValues(alpha: 0.6),
                          ],
                        )
                      : null,
                  color: unlocked
                      ? null
                      : context.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  style.icon,
                  color: unlocked ? Colors.white : context.textTertiary,
                  size: 22,
                ),
              ),
              if (!unlocked)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.surface,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: context.cardBorder, width: 1),
                    ),
                    child: Icon(Icons.lock_rounded,
                        size: 10, color: context.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            badge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color:
                  unlocked ? context.textPrimary : context.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Text(
            unlocked ? 'Unlocked' : 'Locked',
            style: AppTextStyles.labelSmall.copyWith(
              color: unlocked ? style.tint : context.textTertiary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

void _showBadgeSheet(
  BuildContext context,
  ServerBadge badge,
  _BadgeStyle style,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) {
      final unlocked = badge.unlocked;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetCtx.divider,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: unlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            style.tint,
                            style.tint.withValues(alpha: 0.6),
                          ],
                        )
                      : null,
                  color: unlocked
                      ? null
                      : sheetCtx.textTertiary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: style.tint.withValues(alpha: 0.32),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  unlocked ? style.icon : Icons.lock_rounded,
                  size: 40,
                  color: unlocked ? Colors.white : sheetCtx.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: sheetCtx.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (unlocked ? style.tint : sheetCtx.textTertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  unlocked ? 'Unlocked ✓' : 'Keep going to unlock',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: unlocked ? style.tint : sheetCtx.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

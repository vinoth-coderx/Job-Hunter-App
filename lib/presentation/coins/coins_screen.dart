import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/services/gamification_service.dart';
import '../../providers/coins_provider.dart';
import 'referral_sheet.dart';

/// "Wallet" screen — opens from the gold pill in the header. Shows the
/// current balance plus every way the seeker can earn more, each with a
/// concrete CTA so the screen drives action rather than just informing.
class CoinsScreen extends StatefulWidget {
  const CoinsScreen({super.key});

  @override
  State<CoinsScreen> createState() => _CoinsScreenState();
}

class _CoinsScreenState extends State<CoinsScreen> {
  final GamificationService _service = GamificationService.instance;

  StreakInfo? _streak;
  // Pulled from /badges → stats.completion (0–100). The same scorer the
  // backend uses to gate the +50 profile-completion bonus.
  int _completion = 0;
  bool _loading = true;
  bool _checkInBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    // `silent` skips the full-page spinner — used for pull-to-refresh
    // (RefreshIndicator gives its own affordance) and post-action
    // resyncs so the screen doesn't visibly "restart" mid-interaction.
    if (!silent) setState(() => _loading = true);
    try {
      // Three independent reads — fan out so the hero renders fast.
      final results = await Future.wait([
        _service.getStreak(),
        _service.badges(),
        context.read<CoinsProvider>().refresh(),
      ]);
      if (!mounted) return;
      final streak = results[0] as StreakInfo;
      final badges = results[1] as BadgesSnapshot;
      setState(() {
        _streak = streak;
        _completion = badges.completion;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _doCheckIn() async {
    if (_checkInBusy) return;
    setState(() => _checkInBusy = true);
    try {
      final result = await _service.checkIn();
      if (!mounted) return;
      context.read<CoinsProvider>().setBalance(result.coinsBalance);
      // The check-in response already carries the post-action streak
      // numbers — synthesize a fresh StreakInfo locally instead of
      // re-fetching, which would otherwise blank the whole screen with
      // the load spinner and feel like a screen restart.
      setState(() {
        _streak = StreakInfo(
          streakCount: result.streakCount,
          longestStreak: result.longestStreak,
          lastCheckinDate: DateTime.now(),
          checkedInToday: true,
        );
      });
      AppSnackbar.success(
        context,
        result.streakChanged
            ? (result.coinsAwarded > 0
                ? 'Day ${result.streakCount} 🔥 +${result.coinsAwarded} coins!'
                : 'Day ${result.streakCount} 🔥 — keep going!')
            : 'Already checked in today.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _checkInBusy = false);
    }
  }

  // Tomorrow's check-in reward — base+(streak)*5 capped at 30.
  int _nextCheckinReward() {
    final s = _streak;
    if (s == null) return 10;
    final next = (s.checkedInToday ? s.streakCount + 1 : s.streakCount.clamp(1, 100));
    return (10 + (next - 1) * 5).clamp(10, 30);
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<CoinsProvider>().balance;
    final streak = _streak;
    final canCheckIn = streak != null && !streak.checkedInToday;
    final profileDone = _completion >= 100;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Coins',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
        ),
        backgroundColor: context.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        color: AppColors.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _BalanceHero(balance: balance),
                  const SizedBox(height: 24),
                  Text(
                    'Ways to earn',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EarnCard(
                    icon: Icons.local_fire_department_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Daily check-in',
                    description: streak == null
                        ? 'Show up daily to grow your streak.'
                        : streak.checkedInToday
                            ? 'Streak: ${streak.streakCount} day${streak.streakCount == 1 ? '' : 's'} · come back tomorrow.'
                            : 'Streak: ${streak.streakCount} day${streak.streakCount == 1 ? '' : 's'} · longest ${streak.longestStreak}.',
                    rewardLabel: '+${_nextCheckinReward()}',
                    cta: streak?.checkedInToday == true
                        ? 'Done today ✓'
                        : 'Check in',
                    enabled: canCheckIn && !_checkInBusy,
                    busy: _checkInBusy,
                    onTap: _doCheckIn,
                  ),
                  const SizedBox(height: 12),
                  _EarnCard(
                    icon: Icons.send_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: 'Apply to jobs',
                    description: 'Earn for every fresh application.',
                    rewardLabel: '+5 each',
                    subRewardLabel: 'up to 50/day',
                    cta: 'Browse jobs',
                    onTap: () {
                      // Pop back to whatever screen sent us here. Most paths
                      // open Coins from the home header, so a single pop
                      // lands the seeker on the jobs feed.
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _EarnCard(
                    icon: Icons.verified_user_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Complete your profile',
                    description: profileDone
                        ? 'Profile is fully complete — bonus claimed.'
                        : 'Add skills, experience, and a resume to hit 100%.',
                    rewardLabel: '+50',
                    subRewardLabel: 'one-time',
                    cta: profileDone ? 'Profile complete ✓' : 'Update profile',
                    enabled: !profileDone,
                    progress: _completion / 100,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.profileInformation,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EarnCard(
                    icon: Icons.share_rounded,
                    iconBg: const Color(0xFFEDE9FE),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Invite friends',
                    description: 'You get +30, your friend gets +20 when they sign up with your code.',
                    rewardLabel: '+30',
                    subRewardLabel: 'each signup',
                    cta: 'Share code',
                    onTap: () => ReferralSheet.show(context),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final int balance;
  const _BalanceHero({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your balance',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$balance',
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  balance == 1 ? 'coin' : 'coins',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String rewardLabel;
  final String? subRewardLabel;
  final String cta;
  final bool enabled;
  final bool busy;
  final double? progress;
  final VoidCallback onTap;

  const _EarnCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.rewardLabel,
    required this.cta,
    required this.onTap,
    this.subRewardLabel,
    this.enabled = true,
    this.busy = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RewardChip(
                          label: rewardLabel,
                          subLabel: subRewardLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: context.cardBorder.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(iconColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress!.clamp(0.0, 1.0) * 100).round()}% complete',
              style: AppTextStyles.labelSmall.copyWith(
                color: context.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled && !busy ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled
                    ? AppColors.primary
                    : context.cardBorder,
                foregroundColor:
                    enabled ? Colors.white : context.textTertiary,
                disabledBackgroundColor: context.cardBorder.withValues(alpha: 0.6),
                disabledForegroundColor: context.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      cta,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final String? subLabel;
  const _RewardChip({required this.label, this.subLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Colors.white, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(width: 4),
            Text(
              '· $subLabel',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

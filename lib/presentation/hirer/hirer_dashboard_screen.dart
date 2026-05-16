import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/hirer_profile_model.dart';
import '../../data/services/hirer_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hirer_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/header_action_button.dart';
import '../widgets/trust_badges.dart';
import 'verification_screen.dart';

/// Landing screen for the Hirer side of the app.
/// First-time hirers see a "set up company" CTA.
/// Returning hirers see stats + quick actions (post job, manage jobs).
class HirerDashboardScreen extends StatefulWidget {
  const HirerDashboardScreen({super.key});

  @override
  State<HirerDashboardScreen> createState() => _HirerDashboardScreenState();
}

class _HirerDashboardScreenState extends State<HirerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HirerProvider>().load();
      // Refresh badges (chat + notifications) on landing so the header
      // pills reflect server state without waiting for the user to open
      // either screen.
      context.read<ChatProvider>()
        ..start()
        ..loadConversations();
      context.read<NotificationProvider>().refreshUnread();
    });
  }

  Future<void> _refresh() async {
    await context.read<HirerProvider>().load();
  }

  /// Push the post-job flow and refresh dashboard stats when it returns.
  /// IndexedStack keeps the dashboard mounted across tab switches, so
  /// `initState` never fires a second time — without this explicit
  /// reload the freshly-posted job's count never makes it into the
  /// active/draft/applicants tiles until the user pulls-to-refresh.
  Future<void> _openPostJob() async {
    await Navigator.pushNamed(context, AppRoutes.hirerPostJob);
    if (!mounted) return;
    await context.read<HirerProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hirer dashboard',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800)),
            Text(
              'Post jobs · Review applicants',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        // Title sits flush on the left — matches the seeker home and lets
        // the action icons (chat, bell, edit) breathe on the right side.
        centerTitle: false,
        titleSpacing: 20,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Messages — primary chat entry point now that Messages was
          // removed from the hirer bottom nav.
          HeaderActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Messages',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.conversations),
            badgeCount:
                context.select<ChatProvider, int>((p) => p.totalUnread),
          ),
          const SizedBox(width: 6),
          HeaderActionButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
            badgeCount: context.watch<NotificationProvider>().unread,
          ),
          const SizedBox(width: 6),
          Consumer<HirerProvider>(
            builder: (context, prov, _) => prov.profile == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit company',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.hirerProfileSetup,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<HirerProvider>(
        builder: (context, prov, _) {
          if (prov.loading && prov.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: prov.profile == null
                ? _emptyState(context)
                : _dashboardBody(context, prov),
          );
        },
      ),
      floatingActionButton: Consumer<HirerProvider>(
        builder: (context, prov, _) {
          if (prov.profile == null) return const SizedBox.shrink();
          return _GradientFab(onPressed: _openPostJob);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: const AppLogo(size: 80, elevated: false),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome, future Hirer',
          textAlign: TextAlign.center,
          style: AppTextStyles.h1.copyWith(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your company profile to start posting jobs, reviewing applicants, and chatting with candidates.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        _GradientPrimaryButton(
          label: 'Set up company profile',
          icon: Icons.business_outlined,
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.hirerProfileSetup),
        ),
        const SizedBox(height: 16),
        _PerksRow(),
      ],
    );
  }

  Widget _dashboardBody(BuildContext context, HirerProvider prov) {
    final stats = prov.stats;
    final profile = prov.profile!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _companyCard(context, profile),
        if (profile.approvalStatus != 'approved')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ApprovalBanner(
              status: profile.approvalStatus,
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HirerVerificationScreen(),
                ),
              ),
            ),
          ),
        if (profile.approvalStatus == 'approved' && !profile.verification.isVerified)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _VerifyPromptCard(
              trustScore: profile.trustScore,
              dailyLimit: profile.dailyPostLimit,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HirerVerificationScreen(),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _statsGrid(context, stats),
        const SizedBox(height: 16),
        const _AttentionCard(),
        const SizedBox(height: 16),
        const _AiDigestCard(),
        const SizedBox(height: 24),
        _SectionHeader('Quick actions'),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.post_add_rounded,
          accent: AppColors.primary,
          title: 'Post a new job',
          subtitle: 'Native posting, applicants apply in-app',
          onTap: _openPostJob,
        ),
        _ActionTile(
          icon: Icons.work_history_outlined,
          accent: AppColors.success,
          title: 'Manage jobs',
          subtitle:
              '${stats?.activeJobs ?? 0} active · ${stats?.draftJobs ?? 0} drafts',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerManageJobs),
        ),
        _ActionTile(
          icon: Icons.people_alt_outlined,
          accent: AppColors.info,
          title: 'Applicants',
          subtitle:
              '${stats?.totalApplications ?? 0} total · ${stats?.totalShortlisted ?? 0} shortlisted',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerApplicants),
        ),
        _ActionTile(
          icon: Icons.groups_outlined,
          accent: AppColors.warning,
          title: 'Team',
          subtitle: 'Invite recruiters, set roles',
          onTap: () => Navigator.pushNamed(context, AppRoutes.hirerTeam),
        ),
        _ActionTile(
          icon: Icons.insights_rounded,
          accent: const Color(0xFF8B5CF6),
          title: 'Analytics',
          subtitle: 'Pipeline, funnel & insights',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerAnalytics),
        ),
      ],
    );
  }

  Widget _companyCard(BuildContext context, HirerProfile p) {
    final logoUrl = p.companyLogoUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.surface,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: (logoUrl != null && logoUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.business, color: AppColors.primary),
                  )
                : const Icon(Icons.business, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.companyName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.verification.isVerified)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  (p.industry != null && p.industry!.isNotEmpty)
                      ? p.industry!
                      : 'Tap edit to add industry',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(BuildContext context, HirerStats? stats) {
    final s = stats;
    return Row(
      children: [
        _StatCard(
          label: 'Active',
          value: (s?.activeJobs ?? 0).toString(),
          color: AppColors.success,
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Drafts',
          value: (s?.draftJobs ?? 0).toString(),
          color: AppColors.warning,
          icon: Icons.edit_note_rounded,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Applicants',
          value: (s?.totalApplications ?? 0).toString(),
          color: AppColors.info,
          icon: Icons.people_alt_rounded,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.14),
              color.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h2.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand-gradient floating action button. Replaces the default
/// FloatingActionButton.extended so the dashboard's primary CTA reads
/// as a hirer-side accent rather than a generic Material colour.
class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF2F6BFF)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Post a job',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same gradient look as the FAB, sized for in-line CTAs on the empty
/// state. Pulled out so we can reuse it for any future "primary intent"
/// buttons elsewhere on the hirer dashboard.
class _GradientPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const _GradientPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF2F6BFF)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three quick "why bother setting up" perks shown beneath the empty
/// state CTA. Each cell is a dense info chip — no interaction, just
/// signal that the hirer side has real depth waiting on the other side
/// of company profile creation.
class _PerksRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _PerkChip(
            icon: Icons.bolt_rounded,
            label: 'Native applies',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _PerkChip(
            icon: Icons.psychology_alt_outlined,
            label: 'AI-ranked applicants',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _PerkChip(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'In-app chat',
          ),
        ),
      ],
    );
  }
}

class _PerkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.status, required this.onAction});
  final String status;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    late final String body;
    late final String cta;
    switch (status) {
      case 'banned':
        bg = AppColors.urgentBg;
        fg = AppColors.urgent;
        icon = Icons.block;
        title = 'Account banned';
        body = 'You can\'t post new jobs. Contact support for details.';
        cta = 'Verify company';
        break;
      case 'suspended':
        bg = AppColors.urgentBg;
        fg = AppColors.urgent;
        icon = Icons.pause_circle_filled;
        title = 'Account suspended';
        body = 'Resolve open reports before posting again.';
        cta = 'Verify company';
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFC2570D);
        icon = Icons.hourglass_top_outlined;
        title = 'Pending review';
        body = 'Verify your company to unlock posting and the Verified badge.';
        cta = 'Verify now';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(body,
                    style: AppTextStyles.bodySmall.copyWith(color: fg)),
              ],
            ),
          ),
          TextButton(onPressed: onAction, child: Text(cta)),
        ],
      ),
    );
  }
}

class _VerifyPromptCard extends StatelessWidget {
  const _VerifyPromptCard({
    required this.trustScore,
    required this.dailyLimit,
    required this.onTap,
  });
  final int trustScore;
  final int dailyLimit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_outlined,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get verified to scale your hiring',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Daily limit: $dailyLimit jobs · Verification raises your limit & shows the green badge.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TrustScorePill(score: trustScore),
          ],
        ),
      ),
    );
  }
}

/// Auto-fetched AI weekly digest card. Renders a one-line headline +
/// up to 4 next-action bullets sourced from the hirer's last-7-day
/// activity. Server-side cache means visits within 24h are quota-free,
/// so we just fire the GET on mount and trust the backend dedup.
class _AiDigestCard extends StatefulWidget {
  const _AiDigestCard();

  @override
  State<_AiDigestCard> createState() => _AiDigestCardState();
}

class _AiDigestCardState extends State<_AiDigestCard> {
  bool _loading = true;
  String? _headline;
  List<String> _bullets = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await HirerService.instance.getDigest();
      if (!mounted) return;
      setState(() {
        _headline = res.headline;
        _bullets = res.bullets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Silent failure — the dashboard has plenty else to show.
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: context.cardBorder),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final headline = _headline;
    if (headline == null || headline.isEmpty) {
      // Backend returned nothing useful — hide the card entirely so the
      // dashboard doesn't carry empty surface area.
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'WEEKLY DIGEST',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (_bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final b in _bullets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Needs attention" card. Pure data aggregation, no AI cost — surfaces
/// the four pipeline blockers we know how to count: pending appeals,
/// flagged listings, unreviewed strong matches, and stale jobs. Renders
/// nothing while loading or when total === 0 so the dashboard layout
/// stays clean.
class _AttentionCard extends StatefulWidget {
  const _AttentionCard();

  @override
  State<_AttentionCard> createState() => _AttentionCardState();
}

class _AttentionCardState extends State<_AttentionCard> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await HirerService.instance.getAttention();
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) return const SizedBox.shrink();
    final data = _data!;
    final total = (data['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return const SizedBox.shrink();

    final rows = <_AttentionRowSpec>[];
    void addRow({
      required String key,
      required String label,
      required IconData icon,
      required Color color,
      required VoidCallback? onTap,
    }) {
      final raw = data[key];
      if (raw is! Map) return;
      final count = (raw['count'] as num?)?.toInt() ?? 0;
      if (count == 0) return;
      final top = raw['topItem'];
      final topLabel =
          top is Map ? (top['label'] ?? '').toString() : '';
      rows.add(
        _AttentionRowSpec(
          icon: icon,
          color: color,
          label: label,
          count: count,
          topLabel: topLabel,
          onTap: onTap,
        ),
      );
    }

    addRow(
      key: 'moderationAppeals',
      label: 'Pending moderation appeals',
      icon: Icons.gavel_outlined,
      color: AppColors.warning,
      onTap: null,
    );
    addRow(
      key: 'moderationFlagged',
      label: 'Listings flagged by moderation',
      icon: Icons.gpp_bad_outlined,
      color: AppColors.urgent,
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.hirerManageJobs),
    );
    addRow(
      key: 'unreviewedTopMatches',
      label: 'Strong matches not yet reviewed',
      icon: Icons.auto_awesome,
      color: AppColors.primary,
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.hirerApplicants),
    );
    addRow(
      key: 'staleJobs',
      label: 'Stale jobs with no recent applicants',
      icon: Icons.schedule_rounded,
      color: AppColors.info,
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.hirerManageJobs),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.priority_high_rounded,
                  size: 16, color: AppColors.urgent),
              const SizedBox(width: 6),
              Text(
                'Needs your attention',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.urgent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.urgent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.urgent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(color: context.cardBorder, height: 14),
            _AttentionRow(spec: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _AttentionRowSpec {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final String topLabel;
  final VoidCallback? onTap;
  const _AttentionRowSpec({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.topLabel,
    required this.onTap,
  });
}

class _AttentionRow extends StatelessWidget {
  final _AttentionRowSpec spec;
  const _AttentionRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: spec.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(spec.icon, size: 16, color: spec.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${spec.count} · ${spec.label}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (spec.topLabel.isNotEmpty)
                    Text(
                      spec.topLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (spec.onTap != null)
              Icon(Icons.chevron_right,
                  size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/hirer_profile_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hirer_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/header_action_button.dart';

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

  Future<void> _refresh() => context.read<HirerProvider>().load();

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
          return FloatingActionButton.extended(
            onPressed: _openPostJob,
            icon: const Icon(Icons.add),
            label: const Text('Post a job'),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.business_center_outlined,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.55)),
        const SizedBox(height: 20),
        Text(
          'Welcome, future Hirer',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(color: context.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your company profile to start posting jobs and reviewing applicants.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.hirerProfileSetup),
          icon: const Icon(Icons.add),
          label: const Text('Set up company profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashboardBody(BuildContext context, HirerProvider prov) {
    final stats = prov.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _companyCard(context, prov.profile!),
        const SizedBox(height: 16),
        _statsGrid(context, stats),
        const SizedBox(height: 24),
        _SectionHeader('Quick actions'),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.post_add,
          title: 'Post a new job',
          subtitle: 'Native posting, applicants apply in-app',
          onTap: _openPostJob,
        ),
        _ActionTile(
          icon: Icons.work_outline,
          title: 'Manage jobs',
          subtitle: '${stats?.activeJobs ?? 0} active · ${stats?.draftJobs ?? 0} drafts',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerManageJobs),
        ),
        _ActionTile(
          icon: Icons.people_outline,
          title: 'Applicants',
          subtitle: '${stats?.totalApplications ?? 0} total · ${stats?.totalShortlisted ?? 0} shortlisted',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerApplicants),
        ),
        _ActionTile(
          icon: Icons.group_outlined,
          title: 'Team',
          subtitle: 'Invite recruiters, set roles',
          onTap: () => Navigator.pushNamed(context, AppRoutes.hirerTeam),
        ),
        _ActionTile(
          icon: Icons.bar_chart_rounded,
          title: 'Analytics',
          subtitle: 'Pipeline, funnel & insights',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.hirerAnalytics),
        ),
      ],
    );
  }

  Widget _companyCard(BuildContext context, HirerProfile p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.business, color: AppColors.primary),
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
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.verification.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.verified,
                            size: 16, color: AppColors.primary),
                      ),
                  ],
                ),
                if (p.industry != null && p.industry!.isNotEmpty)
                  Text(p.industry!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary)),
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
            label: 'Active', value: (s?.activeJobs ?? 0).toString(),
            color: AppColors.success),
        const SizedBox(width: 8),
        _StatCard(
            label: 'Drafts', value: (s?.draftJobs ?? 0).toString(),
            color: AppColors.warning),
        const SizedBox(width: 8),
        _StatCard(
            label: 'Applicants',
            value: (s?.totalApplications ?? 0).toString(),
            color: AppColors.info),
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
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.h3.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700, color: context.textPrimary)),
        subtitle: Text(subtitle,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary)),
        trailing: Icon(Icons.chevron_right, color: context.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

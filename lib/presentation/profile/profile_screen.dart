import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/hirer_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/resume_profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../main_navigation/role_switch_splash.dart';
import '../widgets/app_avatar.dart';
import 'share_profile_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Toggle the active role. The wrapper screen listens to AuthProvider
  /// so the swap happens in-place without needing a route push.
  /// First-time hirers (no company profile yet) are routed through
  /// company setup before the switch is committed. On success we show
  /// the [RoleSwitchSplash] so the seeker registers the swap — without
  /// it the layout silently flips, which felt like a glitch in user
  /// testing.
  Future<void> _handleSwitchRole(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final target = auth.isHirerMode ? 'seeker' : 'hirer';
    final r = await auth.switchRole(target);
    if (!mounted) return;

    if (r.ok) {
      if (!context.mounted) return;
      await RoleSwitchSplash.show(context, targetRole: target);
      return;
    }

    if (r.needsHirerProfile) {
      // Bounce through the setup flow; on success, retry the switch.
      final created = await navigator.pushNamed(AppRoutes.hirerProfileSetup);
      if (!mounted) return;
      if (created == true) {
        final retry = await auth.switchRole('hirer');
        if (!mounted) return;
        if (retry.ok && context.mounted) {
          await RoleSwitchSplash.show(context, targetRole: 'hirer');
        }
      }
      return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text(r.error ?? 'Could not switch role'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isGuest = authProvider.isGuest;
    final isHirer = authProvider.isHirerMode;
    final resumeProfile = context.watch<ResumeProfileProvider>().profile;
    final completion = isGuest ? 0 : resumeProfile.completionPercent;
    final hirerProfile =
        isHirer ? context.watch<HirerProvider>().profile : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.gradientTop, context.gradientBottom],
          stops: const [0.0, 0.4],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky header — sits outside the scroll view so the title
            // and action icons stay pinned as the body scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGuest
                              ? 'Browse jobs without signing in'
                              : 'Manage your profile & preferences',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isGuest) ...[
                    _RoleToggle(
                      isHirer: isHirer,
                      onSwitch: () =>
                          _handleSwitchRole(context, authProvider),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _HeaderIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Share profile',
                    onTap: (user == null || isGuest)
                        ? null
                        : () => showShareProfileSheet(context, user),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  _ProfileCard(
                    name: isGuest ? 'Guest' : (user?.name ?? 'Guest'),
                    headline: isGuest
                        ? 'Browsing without an account'
                        : (isHirer
                            ? (hirerProfile?.companyName.isNotEmpty == true
                                ? 'Hiring at ${hirerProfile!.companyName}'
                                : 'Set up your company profile')
                            : ((user?.headline.isNotEmpty == true)
                                ? user!.headline
                                : (user?.profession ?? 'Job Seeker'))),
                    email: isGuest ? '' : (user?.email ?? ''),
                    phone: isGuest ? '' : (user?.phone ?? ''),
                    photoUrl: isGuest ? null : user?.photoUrl,
                    isPro: (isGuest || isHirer) ? false : (user?.isPro ?? false),
                    isGuest: isGuest,
                    isHirer: isHirer,
                    completion: completion,
                  ),

                  // Pro upgrade is a seeker-side concept. In hirer mode the
                  // seeker subscription doesn't belong on the dashboard.
                  if (!isHirer) ...[
                    const SizedBox(height: 18),
                    _SubscriptionBanner(
                      plan: user?.plan ?? SubscriptionPlan.free,
                      locked: isGuest,
                      onTap: isGuest
                          ? () => _showLoginPrompt(context)
                          : () => Navigator.pushNamed(
                              context, AppRoutes.subscription),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Account section — shown in both modes. Messages is now
                  // a dedicated bottom-nav tab; it lives there, not here.
                  _SectionTitle('Account',
                      icon: Icons.manage_accounts_rounded),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      _AccountTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        subtitle: 'Name, phone, age & contact',
                        locked: isGuest,
                        onTap: isGuest
                            ? () => _showLoginPrompt(context)
                            : () => Navigator.pushNamed(
                                context, AppRoutes.profileInformation),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Company section — hirer-only. Company profile + the
                  // employer-side analytics live here so the profile tab
                  // becomes the hirer's hub for managing their company.
                  if (isHirer) ...[
                    _SectionTitle('Company',
                        icon: Icons.business_rounded),
                    const SizedBox(height: 10),
                    _SectionCard(
                      children: [
                        _AccountTile(
                          icon: Icons.apartment_rounded,
                          title: hirerProfile?.companyName.isNotEmpty == true
                              ? 'Edit company profile'
                              : 'Set up company profile',
                          subtitle: hirerProfile?.companyName.isNotEmpty == true
                              ? 'Logo, description, locations & socials'
                              : 'Add your company so candidates can find you',
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.hirerProfileSetup),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.insights_rounded,
                          title: 'Hiring analytics',
                          subtitle: 'Funnel, reach & response insights',
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.hirerAnalytics),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.group_rounded,
                          title: 'Team',
                          subtitle: 'Recruiters and access',
                          onTap: () => Navigator.pushNamed(
                              context, AppRoutes.hirerTeam),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Career section — seeker-only. Resume profile / salary
                  // insights are not meaningful when the user is posting
                  // jobs rather than applying for them.
                  if (!isHirer) ...[
                    _SectionTitle('Career',
                        icon: Icons.workspace_premium_rounded),
                    const SizedBox(height: 10),
                    _SectionCard(
                      children: [
                        _AccountTile(
                          icon: Icons.assignment_ind_outlined,
                          title: 'My Resume Profile',
                          subtitle: 'Skills, experience & education',
                          trailingText: isGuest ? null : '$completion%',
                          trailingColor: _completionColor(completion),
                          showProgress: !isGuest,
                          progress: completion / 100,
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.resumeProfile),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.auto_fix_high_rounded,
                          title: 'Profile coach',
                          subtitle: 'AI suggestions to improve your profile',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.profileOptimizer),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.psychology_alt_outlined,
                          title: 'Skill gap',
                          subtitle: 'See what skills you need for a role',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.skillGap),
                        ),
                        const _Divider(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _SectionTitle('Practice & growth',
                        icon: Icons.trending_up_rounded),
                    const SizedBox(height: 10),
                    _SectionCard(
                      children: [
                        _AccountTile(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Skill assessments',
                          subtitle: 'Earn verified skill badges',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.skillAssessments),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.emoji_events_rounded,
                          title: 'Achievements',
                          subtitle: 'Streaks & badges',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.badges),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _SectionTitle('Job tools',
                        icon: Icons.work_outline_rounded),
                    const SizedBox(height: 10),
                    _SectionCard(
                      children: [
                        _AccountTile(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Auto-Apply',
                          subtitle: 'Sleep. We apply for you.',
                          trailingBadge: 'AI',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.autoApply),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.bookmark_border_rounded,
                          title: 'Saved jobs',
                          subtitle: 'Jobs you bookmarked',
                          trailingText: (!isGuest &&
                                  user != null &&
                                  user.savedJobIds.isNotEmpty)
                              ? '${user.savedJobIds.length}'
                              : null,
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.savedJobs),
                        ),
                        const _Divider(),
                        _AccountTile(
                          icon: Icons.event_note_rounded,
                          title: 'My interviews',
                          subtitle: 'Scheduled rounds & join links',
                          locked: isGuest,
                          onTap: isGuest
                              ? () => _showLoginPrompt(context)
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.myInterviews),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  _SectionTitle('Settings', icon: Icons.tune_rounded),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      _AccountTile(
                        icon: _themeIconFor(context.watch<ThemeProvider>().mode),
                        title: 'Appearance',
                        subtitle: 'Light, dark or system default',
                        trailingText: _themeLabelFor(
                            context.watch<ThemeProvider>().mode),
                        onTap: () => _showThemePicker(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle('Support', icon: Icons.headset_mic_rounded),
                  const SizedBox(height: 10),
                  _SectionCard(
                    children: [
                      _AccountTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        subtitle: 'FAQs and contact us',
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.helpSupport),
                      ),
                      const _Divider(),
                      _AccountTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About',
                        subtitle: 'App version & legal',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.about),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  isGuest
                      ? _LoginButton(onTap: () => _handleLogin(context))
                      : _LogoutButton(onTap: () => _showLogoutDialog(context)),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Color _completionColor(int percent) {
    if (percent >= 80) return AppColors.success;
    if (percent >= 50) return AppColors.warning;
    return AppColors.urgent;
  }

  void _showLoginPrompt(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Log in with Google to access this'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'Log In',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            _handleLogin(context);
          },
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    ScaffoldMessenger.of(context).clearSnackBars();
    await context.read<AuthProvider>().exitGuestMode();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  IconData _themeIconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _themeLabelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showThemePicker(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final selected = themeProvider.mode;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.divider,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Appearance',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how Job Hunter looks on this device',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(sheetContext).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : context.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                _ThemeOption(
                  icon: Icons.brightness_auto_outlined,
                  label: 'System default',
                  description: 'Match your device setting',
                  selected: selected == ThemeMode.system,
                  onTap: () {
                    themeProvider.setMode(ThemeMode.system);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
                _ThemeOption(
                  icon: Icons.light_mode_outlined,
                  label: 'Light',
                  description: 'Bright surfaces, dark text',
                  selected: selected == ThemeMode.light,
                  onTap: () {
                    themeProvider.setMode(ThemeMode.light);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
                _ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark',
                  description: 'Easier on the eyes at night',
                  selected: selected == ThemeMode.dark,
                  onTap: () {
                    themeProvider.setMode(ThemeMode.dark);
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Tear down the chat socket BEFORE clearing the auth token —
              // otherwise the socket lingers authed as the old user until
              // it's GC'd, which leaks events into the next signed-in
              // session if the user logs back in immediately.
              context.read<ChatProvider>().signOut();
              // Clear job-feed state too: cancels the periodic refresh
              // timer and resets the high-match alert dedup so the next
              // signed-in user gets fresh alerts (otherwise the previous
              // user's "already alerted" set would silently swallow them).
              context.read<JobProvider>().signOut();
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.urgent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final btn = _PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? context.textTertiary : context.textPrimary,
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle(this.title, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: context.textTertiary),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String headline;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isPro;
  final bool isGuest;
  final bool isHirer;
  final int completion;

  const _ProfileCard({
    required this.name,
    required this.headline,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.isPro,
    required this.isGuest,
    required this.isHirer,
    required this.completion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarWithRing(
                photoUrl: photoUrl,
                name: name,
                isGuest: isGuest,
                isPro: isPro,
                completion: completion,
                showRing: !isHirer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isGuest && email.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              size: 16, color: Colors.white),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isGuest) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ContactPill(
                    icon: Icons.mail_outline_rounded,
                    text: email.isNotEmpty ? email : 'No email',
                    verified: email.isNotEmpty,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _ContactPill(
                    icon: Icons.phone_outlined,
                    text: phone,
                    verified: true,
                  ),
                ],
              ],
            ),
            if (!isHirer) ...[
              const SizedBox(height: 14),
              _CompletionBar(percent: completion),
            ],
          ],
        ],
      ),
    );
  }
}

class _AvatarWithRing extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final bool isGuest;
  final bool isPro;
  final int completion;
  final bool showRing;
  const _AvatarWithRing({
    required this.photoUrl,
    required this.name,
    required this.isGuest,
    required this.isPro,
    required this.completion,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    // Avatar sits flush against the inner edge of the progress ring so
    // there's no gradient gap between the photo and the ring track.
    // Avatar diameter = outer 76 − 2 × strokeWidth (3) = 70.
    final avatar = isGuest
        ? Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: context.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          )
        : AppAvatar(
            url: photoUrl,
            name: name,
            size: 70,
            background: Colors.white,
            foreground: AppColors.primary,
            border: const BorderSide(color: Colors.white, width: 2),
          );

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (!isGuest && showRing)
            SizedBox(
              width: 76,
              height: 76,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: completion / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          avatar,
          if (isPro)
            Positioned(
              bottom: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final int percent;
  const _CompletionBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 12, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'Profile strength',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool verified;
  const _ContactPill({
    required this.icon,
    required this.text,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.9)),
          ],
        ],
      ),
    );
  }
}

/// Subscription card. Three visual states:
///   * Locked (guest)   — neutral surface, lock icon, no shimmer.
///   * Upgrade (free)   — soft cream wash + gold accent over the app
///                        surface; reads as "premium" without
///                        out-shouting the rest of the profile.
///   * Active (Pro+)    — warm gold gradient with a small PRO chip.
///
/// Replaces the previous saturated red/orange gradient that felt loud
/// against the rest of the screen.
class _SubscriptionBanner extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool locked;
  final VoidCallback onTap;
  const _SubscriptionBanner({
    required this.plan,
    required this.locked,
    required this.onTap,
  });

  // Gold palette tuned to feel premium but not aggressive.
  static const _gold = Color(0xFFD4A24C);
  static const _goldDeep = Color(0xFFA67324);
  static const _goldTint = Color(0xFFFFF6E0);

  @override
  Widget build(BuildContext context) {
    final isPro = plan != SubscriptionPlan.free;
    if (locked) return _buildLocked(context);
    if (isPro) return _buildActivePro(context);
    return _buildUpgrade(context);
  }

  Widget _buildLocked(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_outline_rounded,
                  color: context.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Log in to manage subscriptions',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: context.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgrade(BuildContext context) {
    final tintAlpha = context.isDark ? 0.05 : 0.32;
    return _PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _gold.withValues(alpha: 0.16),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _goldTint.withValues(alpha: tintAlpha),
              context.surface,
            ],
            stops: const [0.0, 0.85],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: _goldDeep,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Pro',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock unlimited applications & insights',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _goldDeep.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                _FeaturePill(label: 'Auto-Apply'),
                _FeaturePill(label: 'AI Cover Letters'),
                _FeaturePill(label: 'Insights'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePro(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE9C062), _gold, _goldDeep],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            color: _goldDeep,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your subscription',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _SubscriptionBanner._gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _SubscriptionBanner._goldDeep.withValues(alpha: 0.85),
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? trailingColor;
  final String? trailingBadge;
  final bool showProgress;
  final double progress;
  final bool locked;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingColor,
    this.trailingBadge,
    this.showProgress = false,
    this.progress = 0,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      scaleTo: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: locked
                    ? context.textTertiary.withValues(alpha: 0.10)
                    : AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 19,
                color: locked ? context.textTertiary : AppColors.primary,
              ),
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
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: locked
                                ? context.textTertiary
                                : context.textPrimary,
                          ),
                        ),
                      ),
                      if (trailingBadge != null && !locked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trailingBadge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                  if (showProgress && !locked) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          backgroundColor:
                              context.divider.withValues(alpha: 0.6),
                          valueColor: AlwaysStoppedAnimation(
                              trailingColor ?? AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null && !locked) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    color: trailingColor ?? context.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              locked
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              size: locked ? 18 : 22,
              color: context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.urgent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 18, color: AppColors.urgent),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.urgent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Log In',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Container(
        height: 1,
        color: context.divider.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? AppColors.darkSurfaceVariant : context.surfaceVariant;
    final borderColor =
        selected ? AppColors.primary : Colors.transparent;
    final titleColor =
        isDark ? AppColors.darkTextPrimary : context.textPrimary;
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : context.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact two-icon toggle that swaps the active app role.
///
/// Sits in the header row beside the share button — left half = Seeker,
/// right half = Hirer. The selected indicator slides between halves with
/// the same duration and curve in both directions so the swap feels
/// symmetric. Tapping the already-active side is a no-op; the other side
/// delegates to the parent's switch handler (which routes first-time
/// hirers through company setup).
class _RoleToggle extends StatelessWidget {
  final bool isHirer;
  final VoidCallback onSwitch;
  const _RoleToggle({
    required this.isHirer,
    required this.onSwitch,
  });

  static const double _width = 76;
  static const double _height = 38;
  static const double _knob = 32;
  static const double _pad = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_pad),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                isHirer ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: Container(
              width: _knob,
              height: _knob,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_knob / 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _RoleHalf(
                  icon: Icons.person_search_rounded,
                  active: !isHirer,
                  tooltip: 'Seeker mode',
                  onTap: isHirer ? onSwitch : null,
                ),
              ),
              Expanded(
                child: _RoleHalf(
                  icon: Icons.business_center_rounded,
                  active: isHirer,
                  tooltip: 'Hirer mode',
                  onTap: isHirer ? null : onSwitch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleHalf extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoleHalf({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: Icon(
              icon,
              key: ValueKey(active),
              size: 17,
              color: active ? Colors.white : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tap target that scales down on press and back up on release. Symmetric
/// (down ~120ms ease-out, up ~180ms ease-out-back) so press and release feel
/// connected rather than the snap-and-bounce that breaks the symmetry rule.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  const _PressScale({
    required this.child,
    required this.onTap,
    this.scaleTo = 0.97,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTap: disabled ? null : widget.onTap,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scaleTo : 1.0,
        duration:
            Duration(milliseconds: _down ? 120 : 180),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

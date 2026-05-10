import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/job_model.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/job_provider.dart';
import '../ai/widgets/ai_quota_banner.dart';
import '../auth/email_verification_banner.dart';
import 'hirer_main_navigation_screen.dart';
import 'main_navigation_screen.dart';

/// Top-level wrapper that mounts the seeker tab shell or the hirer tab
/// shell based on the user's `activeRole`. Listens to AuthProvider so a
/// role switch from anywhere triggers a clean swap without a route push.
///
/// Also owns:
///   * Chat socket lifecycle — connects as soon as the authenticated
///     user lands on the main shell so push events (new messages, read
///     receipts, typing) arrive even before they open Messages.
///   * High-match alert toaster — listens to [JobProvider.highMatchAlerts]
///     so a 70%+ job posted while the seeker has the app open gets
///     surfaced as a top-right toast regardless of which tab they're on.
class RoleAwareMainScreen extends StatefulWidget {
  const RoleAwareMainScreen({super.key});

  @override
  State<RoleAwareMainScreen> createState() => _RoleAwareMainScreenState();
}

class _RoleAwareMainScreenState extends State<RoleAwareMainScreen> {
  ValueNotifier<List<Job>>? _alertNotifier;
  String? _lastChatRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final role = auth.isHirerMode ? 'hirer' : 'seeker';
      _lastChatRole = role;
      final chat = context.read<ChatProvider>()..start();
      // Use `setActiveRole` rather than a plain `loadConversations` so
      // the chat list is scoped to the current role from the very first
      // fetch — otherwise a hirer-mode account would briefly see seeker
      // threads (and vice versa) before the filter kicked in.
      chat.setActiveRole(role);
      _alertNotifier = context.read<JobProvider>().highMatchAlerts
        ..addListener(_onHighMatches);
      // Pull the user's current AI quota so the banner can show the
      // countdown/upgrade CTA from the very first frame after sign-in.
      context.read<AiQuotaProvider>().refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch role flips here (Provider rebuilds this widget through
    // `select` in build) so toggling seeker ↔ hirer immediately re-
    // fetches the chat list with the new role filter.
    final isHirer = context.read<AuthProvider>().isHirerMode;
    final role = isHirer ? 'hirer' : 'seeker';
    if (_lastChatRole != null && _lastChatRole != role) {
      _lastChatRole = role;
      context.read<ChatProvider>().setActiveRole(role);
    }
  }

  void _onHighMatches() {
    final jobs = _alertNotifier?.value ?? const <Job>[];
    if (jobs.isEmpty) return;
    if (!mounted) {
      // The provider already persisted dedup ids — just clear the
      // notifier so we don't re-trigger when the screen remounts.
      context.read<JobProvider>().consumeHighMatchAlerts();
      return;
    }
    final count = jobs.length;
    final preview = jobs.first.title;
    final message = count == 1
        ? 'New job match: $preview'
        : '$count new job matches — top: $preview';
    AppSnackbar.success(context, message);
    context.read<JobProvider>().consumeHighMatchAlerts();
  }

  @override
  void dispose() {
    _alertNotifier?.removeListener(_onHighMatches);
    _alertNotifier = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHirer = context.select<AuthProvider, bool>((a) => a.isHirerMode);
    final shell = isHirer
        ? const HirerMainNavigationScreen()
        : const MainNavigationScreen();

    // Stack the verification banner ABOVE the navigation shell (not
    // overlaid on top of it) so it pushes the AppBar down instead of
    // covering the logo and greeting. The shared top SafeArea is
    // consumed here so neither the banner nor the shell's own SafeArea
    // double-pads the status-bar inset. Scaffold supplies a theme-aware
    // background so the status-bar strip blends with the app's surface
    // instead of falling through to the underlying black canvas.
    return Scaffold(
      backgroundColor: context.gradientTop,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            const EmailVerificationBanner(),
            AiQuotaBanner(
              onUpgradeTap: () =>
                  Navigator.of(context).pushNamed('/subscription'),
            ),
            Expanded(child: shell),
          ],
        ),
      ),
    );
  }
}

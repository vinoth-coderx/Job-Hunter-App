import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth/animated_auth_background.dart';
import '../widgets/auth/shimmer_primary_button.dart';
import '../widgets/auth/staggered_reveal.dart';
import 'login_screen.dart' show kAuthLogoHeroTag;

/// Sign-in / sign-up entry point for recruiters.
///
/// Reuses the same Google / Email auth path as the seeker login but
/// owns the post-auth flow: a freshly-authenticated user (or any
/// existing seeker account that arrived here by tapping "I'm a
/// recruiter") gets routed through [AppRoutes.hirerProfileSetup] to
/// collect company info, then flipped to `activeRole='hirer'` via
/// [AuthProvider.switchRole] before landing on `/main`.
///
/// An existing hirer account skips the setup screen and goes straight
/// to `/main` — their role is already correct.
class RecruiterLoginScreen extends StatefulWidget {
  const RecruiterLoginScreen({super.key});

  @override
  State<RecruiterLoginScreen> createState() => _RecruiterLoginScreenState();
}

class _RecruiterLoginScreenState extends State<RecruiterLoginScreen> {
  String? _errorMsg;
  bool _busy = false;

  Future<void> _handleGoogleSignIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    // try/finally is the safety net: if anything between here and
    // _afterAuthSuccess throws an uncaught error, we still flip _busy
    // off so the screen doesn't lock up with the buttons disabled.
    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.signInWithGoogle();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _errorMsg = auth.error ?? 'Google sign-in failed';
        });
        return;
      }
      await _afterAuthSuccess();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmailAuth({required bool signUp}) async {
    if (_busy) return;
    setState(() => _errorMsg = null);
    try {
      final result = await Navigator.of(context).pushNamed<bool>(
        AppRoutes.emailAuth,
        arguments: signUp ? 'signup-hirer' : 'signin-hirer',
      );
      if (!mounted) return;
      if (result == true) {
        await _afterAuthSuccess();
      }
    } finally {
      // _afterAuthSuccess (or anything inside the email auth route) can
      // leave _busy=true on its way out — reset here so the screen is
      // always tappable when control returns to it.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bridge between "auth completed" and "/main". Decides whether the
  /// user still needs hirer profile setup based on their current role.
  Future<void> _afterAuthSuccess() async {
    if (!mounted) return;
    setState(() => _busy = true);

    final auth = context.read<AuthProvider>();
    // Existing hirer — nothing to set up.
    if (auth.user?.activeRole == 'hirer') {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.main,
        (_) => false,
      );
      return;
    }

    // Either a brand-new account or an existing seeker switching to the
    // hirer entry. Both need the company-info wizard. The wizard pops
    // `true` when the user finished it; `false` / null when they backed
    // out without saving — in that case stay on this screen so they can
    // either retry or back out themselves.
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.hirerProfileSetup,
    );
    if (!mounted) return;

    if (created != true) {
      setState(() => _busy = false);
      return;
    }

    final r = await auth.switchRole('hirer');
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _errorMsg = r.error ?? 'Could not activate recruiter mode';
      });
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.main,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedAuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const Spacer(flex: 2),
                StaggeredReveal(
                  duration: const Duration(milliseconds: 700),
                  child: Hero(
                    tag: kAuthLogoHeroTag,
                    child: const _BreathingLogoBadge(size: 96, padding: 16),
                  ),
                ),
                const SizedBox(height: 28),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    'Hire on Job Hunter',
                    style: AppTextStyles.h1.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 220),
                  child: const _HirerPill(),
                ),
                const SizedBox(height: 14),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 320),
                  child: Text(
                    'Sign in or create a recruiter account.\nYou will set up your company next.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: context.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 3),
                if (_errorMsg != null) ...[
                  _ErrorBanner(
                    message: _errorMsg!,
                    onDismiss: () => setState(() => _errorMsg = null),
                  ),
                  const SizedBox(height: 16),
                ],
                StaggeredReveal(
                  delay: const Duration(milliseconds: 420),
                  child: ShimmerPrimaryButton(
                    label: 'Continue with Google',
                    icon: Icons.account_circle_outlined,
                    loading: _busy,
                    onPressed: _busy ? null : _handleGoogleSignIn,
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 500),
                  child: _SecondaryButton(
                    label: 'Continue with Email',
                    icon: Icons.alternate_email_rounded,
                    onPressed:
                        _busy ? null : () => _openEmailAuth(signUp: false),
                  ),
                ),
                const SizedBox(height: 8),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 560),
                  child: Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed:
                          _busy ? null : () => _openEmailAuth(signUp: true),
                      child: Text(
                        'Create a recruiter account',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 620),
                  child: Text(
                    'Looking for a job instead? Use the regular sign-in.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Kept around for debug-time toasts during the post-auth flow rewrite;
  // the production code paths use inline _errorMsg banners.
  // ignore: unused_element
  void _toast(String msg) => AppSnackbar.info(context, msg);
}

/// Logo badge with a slow breathing scale loop. Visually matches the
/// seeker login screen so the Hero transition reads as the same brand
/// mark moving between flows.
class _BreathingLogoBadge extends StatefulWidget {
  final double size;
  final double padding;
  const _BreathingLogoBadge({required this.size, required this.padding});

  @override
  State<_BreathingLogoBadge> createState() => _BreathingLogoBadgeState();
}

class _BreathingLogoBadgeState extends State<_BreathingLogoBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.025)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        padding: EdgeInsets.all(widget.padding),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0.02),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AppLogo(size: widget.size, elevated: false),
      ),
    );
  }
}

/// Hirer value-prop pill. Briefcase icon softly pulses so the chip
/// reads as live rather than decorative.
class _HirerPill extends StatefulWidget {
  const _HirerPill();

  @override
  State<_HirerPill> createState() => _HirerPillState();
}

class _HirerPillState extends State<_HirerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl),
            child: const Icon(Icons.business_center_rounded,
                size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          Text(
            'Post jobs · Rank applicants · Hire faster',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.urgent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.urgent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.urgent,
                height: 1.35,
              ),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                color: AppColors.urgent,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: context.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

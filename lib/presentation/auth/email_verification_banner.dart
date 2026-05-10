import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';

/// Slim banner shown above the bottom-nav shells when a logged-in user
/// hasn't verified their email yet. Has two actions:
///   - "Resend"     — re-sends the Firebase verification link.
///   - "I've verified" — reloads the Firebase user, force-refreshes the
///                     ID token, and re-issues the backend session so
///                     the User document's `isEmailVerified` flips on.
///
/// Dismissable: a tap on × hides the banner for 24 hours via
/// SharedPreferences. Re-appears after that — we don't want to let it
/// stay buried indefinitely while the user works with a half-onboarded
/// account.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  static const _dismissKey = 'email_verify_banner_dismissed_until_v1';
  static const _snoozeDuration = Duration(hours: 24);

  bool _hidden = false;
  bool _checked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_dismissKey);
    if (!mounted) return;
    setState(() {
      _checked = true;
      _hidden = raw != null &&
          DateTime.fromMillisecondsSinceEpoch(raw).isAfter(DateTime.now());
    });
  }

  Future<void> _dismiss() async {
    final until = DateTime.now().add(_snoozeDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissKey, until.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _hidden = true);
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendEmailVerification();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppSnackbar.success(context, 'Verification email sent. Check your inbox.');
    } else {
      AppSnackbar.error(
        context,
        auth.error ?? 'Could not send verification email.',
      );
    }
  }

  Future<void> _checkVerified() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.refreshEmailVerifiedStatus();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppSnackbar.success(context, 'Email verified — thanks!');
    } else {
      AppSnackbar.info(
        context,
        "We don't see the verification yet. Click the link in your email and try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, dynamic>((a) => a.user);
    final isAuthenticated =
        context.select<AuthProvider, bool>((a) => a.isAuthenticated);

    // Hide while we don't yet know the dismiss state, while logged out,
    // for verified users, and during the snooze window.
    if (!_checked || !isAuthenticated || user == null) {
      return const SizedBox.shrink();
    }
    final verified = (user.isEmailVerified as bool?) ?? false;
    if (verified || _hidden) return const SizedBox.shrink();

    final email = (user.email as String?) ?? '';

    return Material(
      color: Colors.transparent,
      child: Padding(
        // SafeArea is owned by RoleAwareMainScreen so the banner and
        // the shell beneath it share a single top inset — no double
        // padding when the banner is shown, no missing inset when it
        // self-hides.
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.mail_lock_outlined,
                      color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.body(
                        'Verify your email',
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 2),
                      AppText.caption(
                        email.isEmpty
                            ? 'Click the link we sent to keep your account secure.'
                            : 'Click the link we sent to $email to keep your account secure.',
                        color: context.textSecondary,
                        height: 1.35,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          _BannerActionButton(
                            label: "I've verified",
                            primary: true,
                            onPressed: _busy ? null : _checkVerified,
                          ),
                          _BannerActionButton(
                            label: 'Resend',
                            onPressed: _busy ? null : _resend,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.textTertiary,
                  splashRadius: 20,
                  onPressed: _busy ? null : _dismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _BannerActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onPressed;
  const _BannerActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: primary ? AppColors.primary : Colors.transparent,
          foregroundColor: primary ? Colors.white : AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            side: primary
                ? BorderSide.none
                : BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
          ),
        ),
        child: AppText.caption(
          label,
          color: primary ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

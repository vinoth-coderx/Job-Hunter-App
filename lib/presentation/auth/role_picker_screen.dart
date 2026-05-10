import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';

/// Shown immediately after a fresh signup. The user picks the role they
/// are signing up *as* — that becomes their primary role and drives every
/// future login destination. Picking a role here also gates the
/// role-specific setup that follows:
///
///   Seeker  → 3-step onboarding wizard (avatar, skills, resume)
///   Hirer   → company setup screen → backend `switchRole('hirer')`
///
/// The user can swap later from the profile toggle, but the secondary
/// role's setup will be required at swap time the same way this screen
/// requires it now.
class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen> {
  bool _busy = false;

  Future<void> _pickSeeker() async {
    if (_busy) return;
    // Backend already created the user as `activeRole='seeker'`, so no
    // role-switch call is needed — drop straight into the seeker
    // onboarding wizard, which lands on /main when finished or skipped.
    Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
  }

  Future<void> _pickHirer() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final auth = context.read<AuthProvider>();

    final created = await navigator.pushNamed(AppRoutes.hirerProfileSetup);
    if (!mounted) return;
    if (created != true) {
      // User backed out of company setup. Stay on the picker so they
      // can either retry hirer or fall back to seeker.
      setState(() => _busy = false);
      return;
    }

    final r = await auth.switchRole('hirer');
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _busy = false);
      AppSnackbar.error(context, r.error ?? 'Could not activate hirer mode');
      return;
    }

    navigator.pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText.h1(
                  'Welcome!',
                  color: context.textPrimary,
                ),
                const SizedBox(height: 8),
                AppText.body(
                  'How will you be using Job Hunter?',
                  color: context.textSecondary,
                ),
                const SizedBox(height: 32),
                _RoleTile(
                  icon: Icons.person_search_rounded,
                  title: "I'm a Job Seeker",
                  subtitle:
                      'Search jobs, auto-apply, and track every application.',
                  onTap: _busy ? null : _pickSeeker,
                ),
                const SizedBox(height: 16),
                _RoleTile(
                  icon: Icons.business_center_rounded,
                  title: "I'm a Recruiter / Hirer",
                  subtitle:
                      'Post jobs, manage applicants, and grow your team.',
                  onTap: _busy ? null : _pickHirer,
                ),
                const Spacer(),
                if (_busy)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: AppText.caption(
                    'You can switch between roles anytime from your profile.',
                    color: context.textSecondary,
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

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: context.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: disabled ? 0.15 : 0.4),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.bodyLarge(
                      title,
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 4),
                    AppText.caption(
                      subtitle,
                      color: context.textSecondary,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: context.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

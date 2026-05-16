import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth/animated_auth_background.dart';
import '../widgets/auth/staggered_reveal.dart';

/// Tag used to share the brand badge between login → email auth via Hero.
const String kAuthLogoHeroTag = 'auth-brand-logo';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Inline error banner instead of a snackbar — the snackbar overlay
  // would otherwise cover the auth buttons when Google sign-in failed.
  String? _errorMsg;

  Future<void> _handleGoogleLogin() async {
    final auth = context.read<AuthProvider>();
    setState(() => _errorMsg = null);
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      // Every Google sign-in lands on /main. New users are created as
      // seekers by the backend (the default `activeRole`); recruiters
      // get the explicit "I'm a recruiter" entry in the signup flow,
      // not a post-login picker.
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else {
      setState(() => _errorMsg = auth.error ?? 'Google sign-in failed');
    }
  }

  void _openEmailAuth({required bool signUp}) {
    setState(() => _errorMsg = null);
    Navigator.pushNamed(
      context,
      AppRoutes.emailAuth,
      arguments: signUp ? 'signup' : 'signin',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.isLoading;

    return Scaffold(
      body: AnimatedAuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                StaggeredReveal(
                  duration: const Duration(milliseconds: 700),
                  child: Hero(
                    tag: kAuthLogoHeroTag,
                    flightShuttleBuilder: _logoFlightShuttle,
                    child: const _BreathingLogoBadge(size: 96, padding: 16),
                  ),
                ),
                const SizedBox(height: 28),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 120),
                  child: Text(
                    'Welcome to Job Hunter',
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
                  child: const _BrandPill(),
                ),
                const SizedBox(height: 14),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 320),
                  child: Text(
                    'Sign in to get jobs matched to your profile,\nor browse public listings as a guest.',
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
                  child: _GoogleSignInButton(
                    onPressed: loading ? null : _handleGoogleLogin,
                    isLoading: loading,
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 500),
                  child: _EmailSignInButton(
                    onPressed:
                        loading ? null : () => _openEmailAuth(signUp: false),
                  ),
                ),
                const SizedBox(height: 8),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 560),
                  child: Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed:
                          loading ? null : () => _openEmailAuth(signUp: true),
                      child: Text(
                        'Create an account',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 620),
                  child: const _OrDivider(),
                ),
                const SizedBox(height: 20),
                StaggeredReveal(
                  delay: const Duration(milliseconds: 700),
                  child: _RecruiterEntryCard(
                    onPressed: loading
                        ? null
                        : () => Navigator.of(context)
                            .pushNamed(AppRoutes.recruiterLogin),
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
}

/// Flight shuttle for the auth logo Hero — pins both sides to their
/// natural rendering during the transition. Default flight shuttle
/// keeps the destination widget which can clash with a different
/// padding/size; this keeps the visual stable.
Widget _logoFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final toHero = toContext.widget as Hero;
  return toHero.child;
}

/// Logo badge with a slow, subtle breathing scale loop. Adds life
/// without screaming "animation"; the scale only varies by ±1.5%.
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

/// The "You sleep. We apply." pill. The bolt icon glows softly with a
/// repeating opacity tween so the pill feels live without screaming.
class _BrandPill extends StatefulWidget {
  const _BrandPill();

  @override
  State<_BrandPill> createState() => _BrandPillState();
}

class _BrandPillState extends State<_BrandPill>
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
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl),
            child: const Icon(Icons.bolt_rounded,
                size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          Text(
            'You sleep. We apply.',
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

/// Inline, dismissable error banner. Sits above the auth buttons so a
/// failed Google sign-in (e.g. DEVELOPER_ERROR 10) doesn't visually block
/// the "Continue as Guest" fallback.
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.urgent, size: 20),
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
              child:
                  Icon(Icons.close_rounded, color: AppColors.urgent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.divider, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.divider, thickness: 1)),
      ],
    );
  }
}

/// Recruiter entry chip below the seeker auth buttons. Visually
/// distinct from the seeker CTAs (no card chrome, tinted background)
/// so it reads as "alternate audience" rather than another sign-in
/// option for the same person.
class _RecruiterEntryCard extends StatelessWidget {
  final VoidCallback? onPressed;
  const _RecruiterEntryCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "I'm a recruiter",
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Post jobs and hire faster',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.primary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  const _GoogleSignInButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: context.divider,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleIcon(),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
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

class _EmailSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _EmailSignInButton({required this.onPressed});

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
              Icon(Icons.alternate_email_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Continue with Email',
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

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final r = size.width / 2;
    final c = Offset(size.width / 2, size.height / 2);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.4,
      1.5,
      true,
      paint,
    );
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -3.14,
      1.4,
      true,
      paint,
    );
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      1.7,
      1.4,
      true,
      paint,
    );
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0.1,
      1.5,
      true,
      paint,
    );

    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.55, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - 2, r * 0.7, 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

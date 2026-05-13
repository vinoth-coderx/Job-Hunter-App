import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Inline error banner instead of a snackbar — the snackbar overlay was
  // covering the "Continue as Guest" button when Google sign-in failed,
  // making guest fallback un-tappable.
  String? _errorMsg;

  Future<void> _handleGoogleLogin() async {
    final auth = context.read<AuthProvider>();
    setState(() => _errorMsg = null);
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      // Firebase reports `additionalUserInfo.isNewUser` only on the
      // sign-in that actually created the account, so this is the
      // single moment we route a Google user to the role picker.
      final dest =
          auth.lastSignInIsNewUser ? AppRoutes.rolePicker : AppRoutes.main;
      Navigator.pushReplacementNamed(context, dest);
    } else {
      setState(() => _errorMsg = auth.error ?? 'Google sign-in failed');
    }
  }

  Future<void> _continueAsGuest() async {
    final auth = context.read<AuthProvider>();
    setState(() => _errorMsg = null);
    await auth.enterGuestMode();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.main);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
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
                  child: const AppLogo(size: 96, elevated: false),
                ),
                const SizedBox(height: 28),
                Text(
                  'Welcome to Job Hunter',
                  style: AppTextStyles.h1.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'You sleep. We apply.',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to get jobs matched to your profile,\nor browse public listings as a guest.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
                if (_errorMsg != null) ...[
                  _ErrorBanner(
                    message: _errorMsg!,
                    onDismiss: () => setState(() => _errorMsg = null),
                  ),
                  const SizedBox(height: 16),
                ],
                _GoogleSignInButton(
                  onPressed: loading ? null : _handleGoogleLogin,
                  isLoading: loading,
                ),
                const SizedBox(height: 12),
                _EmailSignInButton(
                  onPressed:
                      loading ? null : () => _openEmailAuth(signUp: false),
                ),
                const SizedBox(height: 8),
                Align(
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
                const SizedBox(height: 12),
                const _OrDivider(),
                const SizedBox(height: 20),
                _GuestButton(
                  onPressed: loading ? null : _continueAsGuest,
                ),
                const SizedBox(height: 12),
                Text(
                  'Guest mode shows public jobs only.\nSign in to apply and get personalised matches.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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

class _GuestButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GuestButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: context.divider, width: 1.4),
          foregroundColor: context.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Continue as Guest',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: context.textPrimary,
          minimumSize: const Size.fromHeight(56),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: context.divider, width: 1.4),
          foregroundColor: context.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alternate_email_rounded,
                size: 20, color: context.textPrimary),
            const SizedBox(width: 12),
            Text(
              'Continue with Email',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
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

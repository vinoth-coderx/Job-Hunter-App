import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../data/services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_text_field.dart';

/// Lets the user request a Firebase password-reset email. Two visual
/// states: (1) form state — collects the email and submits via
/// `FirebaseAuth.sendPasswordResetEmail`; (2) success state — confirms
/// the email is on its way and offers to return to sign-in.
class ForgotPasswordScreen extends StatefulWidget {
  /// Optional pre-fill — when arriving from the sign-in form we already
  /// know the email the user typed there.
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');

  bool _loading = false;
  bool _sent = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final email = _emailCtrl.text.trim();
    try {
      // Pre-flight: Firebase enumeration protection silently succeeds
      // for unknown emails, so we ask the backend first whether the
      // address actually has an account before triggering the reset.
      final exists = await AuthService().checkEmailExists(email);
      if (!exists) {
        if (!mounted) return;
        setState(() => _errorMsg = 'No account found with that email.');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = _firebaseErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Firebase deliberately returns success even for non-existent
      // accounts (anti-enumeration). 'user-not-found' shouldn't surface
      // in normal flow but we map it gracefully if email-enumeration
      // protection is disabled in the project.
      case 'user-not-found':
        return 'No account found with that email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts — try again in a few minutes.';
      case 'network-request-failed':
        return 'Network error — check your connection and try again.';
      default:
        return e.message ?? 'Reset failed: ${e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _sent
                  ? _SuccessView(
                      key: const ValueKey('sent'),
                      email: _emailCtrl.text.trim(),
                      onResend: _loading ? null : _submit,
                      loading: _loading,
                    )
                  : _FormView(
                      key: const ValueKey('form'),
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      validateEmail: _validateEmail,
                      onSubmit: _loading ? null : _submit,
                      loading: _loading,
                      errorMsg: _errorMsg,
                      onDismissError: () =>
                          setState(() => _errorMsg = null),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final String? Function(String?) validateEmail;
  final VoidCallback? onSubmit;
  final bool loading;
  final String? errorMsg;
  final VoidCallback onDismissError;
  const _FormView({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.validateEmail,
    required this.onSubmit,
    required this.loading,
    required this.errorMsg,
    required this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
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
              child: const AppLogo(size: 64, elevated: false),
            ),
          ),
          const SizedBox(height: 18),
          AppText.h1(
            'Reset your password',
            fontWeight: FontWeight.w800,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          AppText.body(
            "Type the email tied to your account and we'll send you a link to set a new password.",
            color: context.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (errorMsg != null) ...[
            _ErrorBanner(message: errorMsg!, onDismiss: onDismissError),
            const SizedBox(height: 16),
          ],
          CustomTextField(
            controller: emailCtrl,
            label: 'Email',
            hint: 'name@example.com',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: validateEmail,
            onSubmitted: (_) => onSubmit?.call(),
          ),
          const SizedBox(height: 24),
          _PrimaryGradientButton(
            label: 'Send reset link',
            loading: loading,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: loading
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: AppText.caption(
                'Back to sign in',
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  final VoidCallback? onResend;
  final bool loading;
  const _SuccessView({
    super.key,
    required this.email,
    required this.onResend,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.14),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.success,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppText.h1(
          'Check your inbox',
          fontWeight: FontWeight.w800,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppText.body(
          "We've sent a password reset link to",
          color: context.textSecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AppText.body(
          email,
          color: context.textPrimary,
          fontWeight: FontWeight.w700,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        AppText.caption(
          'Click the link in the email to set a new password. The link expires in 1 hour.',
          color: context.textTertiary,
          textAlign: TextAlign.center,
          height: 1.4,
        ),
        const SizedBox(height: 28),
        _PrimaryGradientButton(
          label: 'Back to sign in',
          loading: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: onResend,
            child: AppText.caption(
              loading ? 'Sending…' : "Didn't get it? Resend",
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryGradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF2F6BFF)],
                ),
          color: disabled ? AppColors.primary.withValues(alpha: 0.4) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : AppText.button(label, color: Colors.white),
          ),
        ),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.urgent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.urgent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText.caption(
              message,
              color: AppColors.urgent,
              height: 1.35,
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  color: AppColors.urgent, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

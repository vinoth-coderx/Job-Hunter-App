import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_text_field.dart';

/// Email + password sign-in / sign-up. Both modes go through Firebase
/// Auth → backend `/auth/firebase` (the hybrid path), so a successful
/// submission lands us on the same `authenticated` state as Google
/// sign-in.
class EmailAuthScreen extends StatefulWidget {
  /// When `true`, opens in sign-up mode; otherwise sign-in.
  final bool initialSignUp;
  const EmailAuthScreen({super.key, this.initialSignUp = false});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen>
    with TapGuardMixin<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late bool _isSignUp = widget.initialSignUp;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Live-rebuild as the password is typed so the strength meter
    // reflects each keystroke without the form re-validating.
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isBusy('submit')) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await guard(
      () async {
        final auth = context.read<AuthProvider>();
        setState(() => _errorMsg = null);

        final ok = _isSignUp
            ? await auth.signUpWithEmail(
                name: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
              )
            : await auth.signInWithEmail(
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
              );
        if (!mounted) return;

        if (ok) {
          // Fresh sign-up → role picker (seeker/hirer choice gates the
          // role-specific setup that follows). Returning sign-in always
          // goes straight to /main — legacy accounts with empty profiles
          // can fill the gaps later from the profile screen.
          final dest = _isSignUp ? AppRoutes.rolePicker : AppRoutes.main;
          Navigator.pushNamedAndRemoveUntil(context, dest, (_) => false);
        } else {
          setState(() => _errorMsg = auth.error ?? 'Authentication failed');
        }
      },
      key: 'submit',
    );
  }

  void _setMode({required bool signUp}) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _errorMsg = null;
      _formKey.currentState?.reset();
    });
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (_isSignUp && s.length < 8) return 'At least 8 characters';
    return null;
  }

  String? _validateName(String? v) {
    if (!_isSignUp) return null;
    if ((v ?? '').trim().length < 2) return 'Enter your full name';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.isLoading;

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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Brand mark — same glowing badge as login screen.
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
                  // Heading + subtitle. AnimatedSwitcher cross-fades
                  // between modes so the change feels intentional rather
                  // than abrupt.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SizeTransition(
                        sizeFactor: anim,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_isSignUp ? 'signup-head' : 'signin-head'),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AppText.h1(
                          _isSignUp ? 'Create your account' : 'Welcome back',
                          fontWeight: FontWeight.w800,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        AppText.body(
                          _isSignUp
                              ? "A few details and we'll match you to roles in seconds."
                              : 'Sign in to pick up where you left off.',
                          color: context.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Segmented mode toggle — pill at top, both labels
                  // visible so the user knows the alternative exists.
                  _ModeToggle(
                    isSignUp: _isSignUp,
                    onChanged: (signUp) => _setMode(signUp: signUp),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMsg != null) ...[
                    _ErrorBanner(
                      message: _errorMsg!,
                      onDismiss: () => setState(() => _errorMsg = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Name field slides in/out with mode change.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: _isSignUp
                          ? Padding(
                              key: const ValueKey('name'),
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CustomTextField(
                                controller: _nameCtrl,
                                label: 'Full name',
                                hint: 'Your name',
                                prefixIcon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                validator: _validateName,
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('no-name'),
                              width: double.infinity,
                            ),
                    ),
                  ),
                  CustomTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'name@example.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    hint: _isSignUp
                        ? 'At least 8 characters'
                        : 'Your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    onSubmitted: (_) => loading ? null : _submit(),
                  ),
                  // Strength meter (sign-up only) or "Forgot password?"
                  // (sign-in only) — two affordances that wouldn't both
                  // make sense at once.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isSignUp
                        ? _PasswordStrengthMeter(
                            password: _passwordCtrl.text,
                          )
                        : Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => debounceTap(
                                        () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.forgotPassword,
                                          arguments: _emailCtrl.text.trim(),
                                        ),
                                        key: 'forgot',
                                      ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: AppText.caption(
                                'Forgot password?',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _GradientPrimaryButton(
                    label: _isSignUp ? 'Create account' : 'Sign in',
                    loading: loading,
                    onPressed: loading ? null : _submit,
                  ),
                  const SizedBox(height: 18),
                  // Terms only matters at account creation — quietly
                  // tucked away so it doesn't crowd the sign-in mode.
                  if (_isSignUp)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: AppText.caption(
                        'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                        color: context.textTertiary,
                        textAlign: TextAlign.center,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-segment toggle for switching between Sign in / Create account
/// modes. Uses an [AnimatedAlign] for the active-pill backing so the
/// switch feels smooth without an explicit AnimationController.
class _ModeToggle extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isSignUp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.cardBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: isSignUp ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ModeToggleTab(
                  label: 'Sign in',
                  active: !isSignUp,
                  onTap: () => onChanged(false),
                ),
              ),
              Expanded(
                child: _ModeToggleTab(
                  label: 'Create account',
                  active: isSignUp,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            color: active ? Colors.white : context.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Simple zxcvbn-style strength meter — counts character classes plus
/// length and renders 4 segments. Keeps the UX grounded: the user sees
/// "weak / fair / good / strong" before submitting, instead of getting
/// a rejection from Firebase after the fact.
class _PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const _PasswordStrengthMeter({required this.password});

  static const _labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
  static const _colors = [
    AppColors.urgent,
    AppColors.urgent,
    AppColors.warning,
    AppColors.success,
    AppColors.success,
  ];

  int _score() {
    if (password.isEmpty) return 0;
    if (password.length < 8) return 1;
    int classes = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) classes++;
    if (RegExp(r'[A-Z]').hasMatch(password)) classes++;
    if (RegExp(r'[0-9]').hasMatch(password)) classes++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) classes++;
    if (classes <= 1) return 1;
    if (classes == 2) return 2;
    if (classes == 3) return 3;
    return password.length >= 12 ? 4 : 3;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox(height: 8);
    }
    final score = _score();
    final color = _colors[score];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(4, (i) {
              final filled = i < score;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: filled ? color : context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          AppText.caption(
            _labels[score],
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

/// Primary call-to-action with a brand gradient + soft shadow. Falls
/// back to a flat disabled state when [onPressed] is null.
class _GradientPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _GradientPrimaryButton({
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

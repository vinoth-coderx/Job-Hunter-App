import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coins_provider.dart';
import '../../providers/resume_profile_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_text_field.dart';

/// Three-step onboarding wizard the user goes through after their
/// first sign-in. Each step is independently skippable so we never
/// strand a user behind a form they don't want to fill — but the
/// copy makes the matching tradeoff explicit.
///
///   Step 1 — Avatar + name confirm + phone
///   Step 2 — Headline + experience + skills
///   Step 3 — Resume upload (PDF / DOC / DOCX)
///
/// Routing in: `splash_screen.dart` redirects here when
/// `auth.needsOnboarding`, and `email_auth_screen.dart` does the same
/// after a fresh sign-up. Routing out: any "Finish" or "Skip for now"
/// CTA pushes `/main` and clears the back stack.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.popOnFinish = false});

  /// When true, finishing or skipping pops the route with `true`
  /// instead of replacing the stack with `/main`. Used by callers
  /// (e.g. the profile role-toggle) that need control flow back so
  /// they can run a follow-up action like `switchRole('seeker')`.
  final bool popOnFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 3;
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1
  File? _avatarFile;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 2
  final _step2FormKey = GlobalKey<FormState>();
  final _headlineCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();

  // Step 3
  bool _resumeUploaded = false;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the name field with whatever the auth flow already
    // captured so the user doesn't retype it.
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
      _headlineCtrl.text = user.headline;
      if (user.experienceYears > 0) {
        _experienceCtrl.text = user.experienceYears.toString();
      }
      if (user.skills.isNotEmpty) {
        _skillsCtrl.text = user.skills.join(', ');
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _headlineCtrl.dispose();
    _experienceCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  // ── Step 1 ──────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    setState(() => _avatarFile = File(path));
  }

  Future<void> _saveStep1AndAdvance() async {
    if (!mounted) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    try {
      // Profile name + phone (only if changed). The `updateProfile`
      // call uses `fullName` server-side; we map locally as `name`.
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final user = auth.user;
      final nameChanged = user == null || user.name.trim() != name;
      final phoneChanged = user == null || user.phone.trim() != phone;
      if (nameChanged || phoneChanged) {
        await auth.updateProfile(
          name: nameChanged ? name : null,
          phone: phoneChanged ? phone : null,
        );
      }
      if (_avatarFile != null) {
        await auth.uploadAvatar(_avatarFile!);
      }
      _advance();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 2 ──────────────────────────────────────────────────

  Future<void> _saveStep2AndAdvance() async {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;
    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      headline: _headlineCtrl.text.trim(),
      experienceYears: int.tryParse(_experienceCtrl.text.trim()),
      skills: skills.isEmpty ? null : skills,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      // Skills/headline are heavy contributors to completeness — pull
      // the fresh wallet so the pill catches a milestone bonus if the
      // server granted one.
      context.read<CoinsProvider>().refresh();
      _advance();
    } else {
      AppSnackbar.error(context, auth.error ?? 'Could not save details.');
    }
  }

  // ── Step 3 ──────────────────────────────────────────────────

  Future<void> _pickAndUploadResume() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    setState(() => _busy = true);
    final resumeProvider = context.read<ResumeProfileProvider>();
    final auth = context.read<AuthProvider>();

    final result = await resumeProvider.importResume(File(path));
    if (!mounted) return;

    if (!result.ok) {
      setState(() => _busy = false);
      AppSnackbar.error(context, result.error ?? 'Could not upload resume.');
      return;
    }

    await auth.refreshMe();
    if (!mounted) return;
    // Onboarding upload often pushes the seeker over the 100%
    // completion threshold — pull the fresh balance so the home pill
    // already reflects the +50 bonus by the time onboarding ends.
    context.read<CoinsProvider>().refresh();
    setState(() {
      _busy = false;
      _resumeUploaded = true;
    });

    if (result.fieldsFilled > 0) {
      AppSnackbar.success(
        context,
        'Resume saved · auto-filled ${result.fieldsFilled} '
        'section${result.fieldsFilled == 1 ? '' : 's'}.',
      );
    } else if (result.parseEmpty) {
      AppSnackbar.info(
        context,
        "Resume saved. Couldn't auto-read this file — fill the fields manually anytime.",
      );
    }
  }

  // ── Navigation ──────────────────────────────────────────────

  void _advance() {
    if (_step >= _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
    );
  }

  void _finish() {
    // Persist the "wizard seen" flag so future role switches back to
    // seeker don't re-prompt "Make it yours" — applies to skip too,
    // since the user has clearly been shown the prompt and acted on it.
    StorageService.setSeekerOnboardingSeen();
    if (widget.popOnFinish) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
      (_) => false,
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block hardware back so users have to use the in-screen Back /
      // Skip controls — keeps the wizard navigation predictable.
      canPop: false,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _step > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: _busy ? null : _back,
                  color: context.textPrimary,
                )
              : null,
          actions: [
            TextButton(
              onPressed: _busy ? null : _finish,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: AppText.caption(
                'Skip for now',
                color: context.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
            child: Column(
              children: [
                _ProgressIndicator(step: _step, total: _stepCount),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Step1Avatar(
                        avatarFile: _avatarFile,
                        nameCtrl: _nameCtrl,
                        phoneCtrl: _phoneCtrl,
                        busy: _busy,
                        onPickAvatar: _busy ? null : _pickAvatar,
                        onContinue: _busy ? null : _saveStep1AndAdvance,
                      ),
                      _Step2Skills(
                        formKey: _step2FormKey,
                        headlineCtrl: _headlineCtrl,
                        experienceCtrl: _experienceCtrl,
                        skillsCtrl: _skillsCtrl,
                        busy: _busy,
                        onContinue: _busy ? null : _saveStep2AndAdvance,
                      ),
                      _Step3Resume(
                        busy: _busy,
                        uploaded: _resumeUploaded,
                        onPick: _busy ? null : _pickAndUploadResume,
                        onFinish: _busy ? null : _finish,
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────
// Shared visual primitives
// ─────────────────────────────────────────────────────────────────────

class _ProgressIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              height: 6,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: filled ? AppColors.primary : context.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h1(title, fontWeight: FontWeight.w800),
        const SizedBox(height: 6),
        AppText.body(subtitle, color: context.textSecondary, height: 1.4),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryButton({
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

// ─────────────────────────────────────────────────────────────────────
// Step 1 — avatar + name + phone
// ─────────────────────────────────────────────────────────────────────

class _Step1Avatar extends StatelessWidget {
  final File? avatarFile;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool busy;
  final VoidCallback? onPickAvatar;
  final VoidCallback? onContinue;
  const _Step1Avatar({
    required this.avatarFile,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.busy,
    required this.onPickAvatar,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            title: 'Make it yours',
            subtitle:
                'A photo and your name help recruiters and employers recognise you.',
          ),
          const SizedBox(height: 28),
          Center(
            child: GestureDetector(
              onTap: onPickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.surface,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      image: avatarFile != null
                          ? DecorationImage(
                              image: FileImage(avatarFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarFile == null
                        ? Icon(
                            Icons.person_outline_rounded,
                            size: 48,
                            color: context.textTertiary,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.32),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: AppText.caption(
              avatarFile == null
                  ? 'Tap to add a profile photo'
                  : 'Tap to change',
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: 28),
          CustomTextField(
            controller: nameCtrl,
            label: 'Full name',
            hint: 'Your name',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: phoneCtrl,
            label: 'Phone (optional)',
            hint: '+91 …',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            label: 'Continue',
            loading: busy,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Step 2 — headline + experience + skills
// ─────────────────────────────────────────────────────────────────────

class _Step2Skills extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController headlineCtrl;
  final TextEditingController experienceCtrl;
  final TextEditingController skillsCtrl;
  final bool busy;
  final VoidCallback? onContinue;
  const _Step2Skills({
    required this.formKey,
    required this.headlineCtrl,
    required this.experienceCtrl,
    required this.skillsCtrl,
    required this.busy,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepHeader(
              title: 'What do you do?',
              subtitle:
                  "We'll match you against thousands of new jobs every day using these.",
            ),
            const SizedBox(height: 28),
            CustomTextField(
              controller: headlineCtrl,
              label: 'Headline',
              hint: 'e.g. Flutter Developer · 3 yrs',
              prefixIcon: Icons.work_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: experienceCtrl,
              label: 'Years of experience',
              hint: '0',
              prefixIcon: Icons.timeline_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: skillsCtrl,
              label: 'Key skills',
              hint: 'e.g. Flutter, Dart, REST APIs',
              prefixIcon: Icons.bolt_outlined,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            AppText.caption(
              'Comma-separated. The more specific, the better the match.',
              color: context.textTertiary,
            ),
            const SizedBox(height: 28),
            _PrimaryButton(
              label: 'Continue',
              loading: busy,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Step 3 — resume upload
// ─────────────────────────────────────────────────────────────────────

class _Step3Resume extends StatelessWidget {
  final bool busy;
  final bool uploaded;
  final VoidCallback? onPick;
  final VoidCallback? onFinish;
  const _Step3Resume({
    required this.busy,
    required this.uploaded,
    required this.onPick,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            title: 'Drop your resume',
            subtitle:
                "We'll auto-extract your skills and experience so you don't repeat yourself. PDF, DOC, or DOCX.",
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: uploaded
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  uploaded
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 56,
                  color: uploaded
                      ? AppColors.success
                      : AppColors.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                AppText.body(
                  uploaded
                      ? 'Resume saved'
                      : 'Tap "Choose file" to upload',
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                if (!uploaded) ...[
                  const SizedBox(height: 4),
                  AppText.caption(
                    'Max 5 MB. Stored securely on Cloudinary.',
                    color: context.textTertiary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!uploaded)
            _PrimaryButton(
              label: 'Choose file',
              loading: busy,
              onPressed: onPick,
            )
          else
            _PrimaryButton(
              label: 'Finish',
              loading: busy,
              onPressed: onFinish,
            ),
          const SizedBox(height: 12),
          if (!uploaded)
            Center(
              child: TextButton(
                onPressed: busy ? null : onFinish,
                child: AppText.caption(
                  "I'll do this later",
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

// AppLogo import retained for any future header decoration; if you
// want to add the brand badge to the wizard header, drop in:
//   const AppLogo(size: 64, elevated: false)
// at the top of `_StepHeader`.
// ignore: unused_element
class _OnboardingLogo extends StatelessWidget {
  const _OnboardingLogo();

  @override
  Widget build(BuildContext context) => const AppLogo(size: 64, elevated: false);
}

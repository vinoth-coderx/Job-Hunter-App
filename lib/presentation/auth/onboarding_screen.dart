import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_profile_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

enum _OnboardingMode { chooser, resume, details }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingMode _mode = _OnboardingMode.chooser;

  // Basic-details form state
  final _formKey = GlobalKey<FormState>();
  final _headlineCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expectedSalaryCtrl = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _experienceCtrl.dispose();
    _skillsCtrl.dispose();
    _phoneCtrl.dispose();
    _expectedSalaryCtrl.dispose();
    super.dispose();
  }

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

    // Single onboarding step: upload + parse + auto-fill the local
    // profile. Without the parse+apply chain the user lands on Main
    // with an empty profile and has to re-type everything the resume
    // already says.
    final result = await resumeProvider.importResume(File(path));
    if (!mounted) return;

    if (!result.ok) {
      setState(() => _busy = false);
      _showError(result.error ?? 'Could not upload resume');
      return;
    }

    // Refresh auth user so /auth/me-derived UI (resume status pill,
    // avatar) reflects the new file. Non-blocking on the user's path
    // forward — failures here aren't worth gating onboarding on.
    await auth.refreshMe();
    if (!mounted) return;
    setState(() => _busy = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.fieldsFilled > 0) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
          'Resume saved · auto-filled ${result.fieldsFilled} '
          'section${result.fieldsFilled == 1 ? '' : 's'} '
          '— review and edit anytime.',
        ),
      ));
    } else if (result.parseEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'Resume saved. Couldn\'t auto-read this file '
          '— please fill the fields manually.',
        ),
      ));
    }
    _goToMain();
  }

  Future<void> _saveBasicDetails() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      expectedSalaryMin: int.tryParse(_expectedSalaryCtrl.text.trim()),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      _goToMain();
    } else {
      _showError(auth.error ?? 'Could not save details');
    }
  }

  void _goToMain() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
      (_) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.urgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mandatory step — block hardware/system back so users must finish
      // one of the two onboarding paths before reaching the main app.
      canPop: false,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _OnboardingMode.chooser:
        return _Chooser(
          onUploadResume: () => setState(() => _mode = _OnboardingMode.resume),
          onFillDetails: () => setState(() => _mode = _OnboardingMode.details),
        );
      case _OnboardingMode.resume:
        return _ResumeUpload(
          busy: _busy,
          onBack: () => setState(() => _mode = _OnboardingMode.chooser),
          onPick: _pickAndUploadResume,
        );
      case _OnboardingMode.details:
        return _BasicDetailsForm(
          formKey: _formKey,
          headlineCtrl: _headlineCtrl,
          experienceCtrl: _experienceCtrl,
          skillsCtrl: _skillsCtrl,
          phoneCtrl: _phoneCtrl,
          expectedSalaryCtrl: _expectedSalaryCtrl,
          busy: _busy,
          onBack: () => setState(() => _mode = _OnboardingMode.chooser),
          onSubmit: _saveBasicDetails,
        );
    }
  }
}

class _Chooser extends StatelessWidget {
  final VoidCallback onUploadResume;
  final VoidCallback onFillDetails;
  const _Chooser({
    required this.onUploadResume,
    required this.onFillDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text("Let's set up your profile", style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Choose one to start receiving job matches tailored to you.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 32),
        _OptionCard(
          icon: Icons.description_outlined,
          title: 'Upload Resume',
          subtitle: 'PDF or Word — fastest way to get matched',
          onTap: onUploadResume,
        ),
        const SizedBox(height: 16),
        _OptionCard(
          icon: Icons.edit_note_rounded,
          title: 'Fill Basic Details',
          subtitle: 'Headline, experience, key skills',
          onTap: onFillDetails,
        ),
        const Spacer(),
        Center(
          child: Text(
            'Required to continue',
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.divider.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeUpload extends StatelessWidget {
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onPick;
  const _ResumeUpload({
    required this.busy,
    required this.onBack,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubScreenHeader(title: 'Upload your resume', onBack: onBack),
        const SizedBox(height: 12),
        Text(
          'PDF, DOC or DOCX. We extract your skills, experience and education to match you with relevant roles.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              style: BorderStyle.solid,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined,
                  size: 56, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              Text(
                'Tap below to choose a file',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Choose File',
          isLoading: busy,
          onPressed: busy ? () {} : onPick,
        ),
      ],
    );
  }
}

class _BasicDetailsForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController headlineCtrl;
  final TextEditingController experienceCtrl;
  final TextEditingController skillsCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController expectedSalaryCtrl;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const _BasicDetailsForm({
    required this.formKey,
    required this.headlineCtrl,
    required this.experienceCtrl,
    required this.skillsCtrl,
    required this.phoneCtrl,
    required this.expectedSalaryCtrl,
    required this.busy,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubScreenHeader(title: 'A few quick details', onBack: onBack),
            const SizedBox(height: 8),
            Text(
              'These help us match you with the right roles.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: headlineCtrl,
              label: 'Headline',
              hint: 'e.g. Flutter Developer with 3 yrs experience',
              prefixIcon: Icons.work_outline_rounded,
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
              label: 'Key skills (comma separated)',
              hint: 'e.g. Flutter, Dart, REST APIs',
              prefixIcon: Icons.bolt_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: phoneCtrl,
              label: 'Phone (optional)',
              hint: '+91 …',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: expectedSalaryCtrl,
              label: 'Expected salary / month (optional)',
              hint: 'e.g. 50000',
              prefixIcon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Save & Continue',
              isLoading: busy,
              onPressed: busy ? () {} : onSubmit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SubScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _SubScreenHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(title, style: AppTextStyles.h2)),
      ],
    );
  }
}


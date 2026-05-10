import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coins_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_text.dart';

/// User-facing profile editor.
///
/// Field set is deliberately narrowed to what the backend's
/// `PATCH /users/profile` actually accepts (see updateProfileSchema in
/// user.controller.ts). Nothing here is stored locally only.
///
/// Editable: avatar, fullName, phone, headline, experienceYears, expectedSalaryMin.
/// Read-only: email (no API to change it).
class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  State<ProfileInformationScreen> createState() =>
      _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _headline;
  late final TextEditingController _experience;
  late final TextEditingController _expectedSalary;
  bool _saving = false;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _headline = TextEditingController(text: user?.headline ?? '');
    _experience = TextEditingController(
      text: (user?.experienceYears ?? 0) > 0 ? '${user!.experienceYears}' : '',
    );
    _expectedSalary = TextEditingController(
      text: (user?.expectedSalaryMin ?? 0) > 0
          ? '${user!.expectedSalaryMin}'
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _headline.dispose();
    _experience.dispose();
    _expectedSalary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    // Headline / experience / expected salary are seeker-side fields. In
    // hirer mode they're hidden from the form, so don't send them on save.
    final isHirer = auth.isHirerMode;
    final ok = await auth.updateProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      headline: isHirer ? null : _headline.text.trim(),
      experienceYears:
          isHirer ? null : int.tryParse(_experience.text.trim()),
      expectedSalaryMin:
          isHirer ? null : int.tryParse(_expectedSalary.text.trim()),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // The 100%-completion bonus may have just landed — re-fetch the
      // header pill so a returning seeker sees the +50 coins immediately.
      // Cheap (single GET) and only fires on success.
      context.read<CoinsProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not update profile'),
          backgroundColor: AppColors.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    setState(() => _avatarBusy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.uploadAvatar(File(path));
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Photo updated' : (auth.error ?? 'Upload failed')),
        backgroundColor: ok ? AppColors.success : AppColors.urgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeAvatar() async {
    final auth = context.read<AuthProvider>();
    setState(() => _avatarBusy = true);
    final ok = await auth.deleteAvatar();
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Photo removed' : (auth.error ?? 'Could not remove')),
        backgroundColor: ok ? AppColors.success : AppColors.urgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAvatarMenu() async {
    final hasPhoto = (context.read<AuthProvider>().user?.photoUrl ?? '').isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarSheet(canRemove: hasPhoto),
    );
    if (!mounted || action == null) return;
    if (action == 'pick') {
      await _pickAndUploadAvatar();
    } else if (action == 'remove') {
      await _removeAvatar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isHirer = auth.isHirerMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.gradientTop, context.gradientBottom],
              stops: [0.0, 0.4],
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _Header(title: 'Profile Information'),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      child: Column(
                        children: [
                          _AvatarSection(
                            user: user,
                            busy: _avatarBusy,
                            onTap: _avatarBusy ? null : _openAvatarMenu,
                            showHeadline: !isHirer,
                          ),
                          const SizedBox(height: 28),
                          _FieldCard(
                            children: [
                              _LabeledField(
                                label: 'Full Name',
                                icon: Icons.person_outline_rounded,
                                controller: _name,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Name is required'
                                        : null,
                              ),
                              const _CardDivider(),
                              _ReadOnlyField(
                                label: 'Email',
                                icon: Icons.alternate_email_rounded,
                                value: user?.email ?? '',
                                hint: 'Email cannot be changed',
                              ),
                              const _CardDivider(),
                              _LabeledField(
                                label: 'Phone Number',
                                icon: Icons.phone_outlined,
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                hint: '+91 98765 43210',
                              ),
                              if (!isHirer) ...[
                                const _CardDivider(),
                                _LabeledField(
                                  label: 'Headline',
                                  icon: Icons.badge_outlined,
                                  controller: _headline,
                                  hint: 'e.g. Senior Flutter Developer',
                                  maxLength: 200,
                                ),
                              ],
                            ],
                          ),
                          if (!isHirer) ...[
                            const SizedBox(height: 16),
                            _SectionLabel('Job preferences'),
                            const SizedBox(height: 8),
                            _FieldCard(
                              children: [
                                _LabeledField(
                                  label: 'Years of Experience',
                                  icon: Icons.workspace_premium_outlined,
                                  controller: _experience,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                  hint: '3',
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n < 0 || n > 60) {
                                      return 'Enter 0–60';
                                    }
                                    return null;
                                  },
                                ),
                                const _CardDivider(),
                                _LabeledField(
                                  label: 'Expected Salary (min)',
                                  icon: Icons.payments_outlined,
                                  controller: _expectedSalary,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  hint: '800000',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: AppText.caption(
                                'Skills, preferred roles, locations and work modes are managed in Resume profile.',
                                color: context.textTertiary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          if (isHirer) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: AppText.caption(
                                'Company name, logo, locations and socials are managed in Company profile.',
                                color: context.textTertiary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _SaveButton(loading: _saving, onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(title,
                      style: AppTextStyles.h4
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    'Edit your basic info',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: context.textPrimary),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final dynamic user;
  final bool busy;
  final VoidCallback? onTap;
  final bool showHeadline;

  const _AvatarSection({
    required this.user,
    required this.busy,
    this.onTap,
    this.showHeadline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
        // Whole avatar is the tap target — the camera button is just a visual
        // hint. Small icon-only buttons were easy to miss and hard to hit.
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: AppAvatar(
              url: user?.photoUrl as String?,
              name: user?.name as String?,
              size: 104,
              border: const BorderSide(color: Colors.white, width: 4),
            ),
          ),
        ),
        if (busy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          (user?.name as String?)?.isNotEmpty == true
              ? user!.name as String
              : 'Add your name',
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        if (showHeadline &&
            (user?.headline as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Text(
            user!.headline as String,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarSheet extends StatelessWidget {
  final bool canRemove;
  const _AvatarSheet({required this.canRemove});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetTile(
              icon: Icons.image_outlined,
              label: 'Choose photo',
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (canRemove)
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: AppColors.urgent,
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 4),
            _SheetTile(
              icon: Icons.close_rounded,
              label: 'Cancel',
              color: context.textSecondary,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _SheetTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final List<Widget> children;
  const _FieldCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 1,
        color: context.divider.withValues(alpha: 0.6),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hint;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.hint,
    this.validator,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  validator: validator,
                  maxLength: maxLength,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? hint;

  const _ReadOnlyField({
    required this.label,
    required this.icon,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: context.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: context.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              size: 14, color: context.textTertiary),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _SaveButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: GestureDetector(
        onTap: loading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: loading
                  ? [
                      AppColors.primary.withValues(alpha: 0.5),
                      AppColors.primaryDark.withValues(alpha: 0.5),
                    ]
                  : const [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: loading
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Save Changes',
                        style: AppTextStyles.button
                            .copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
        ),
      ),
    );
  }
}

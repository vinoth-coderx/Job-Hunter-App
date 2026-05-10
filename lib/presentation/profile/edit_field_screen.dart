import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';

enum EditFieldKind { email, age, profession }

class EditFieldArgs {
  final EditFieldKind kind;
  const EditFieldArgs(this.kind);
}

class EditFieldScreen extends StatefulWidget {
  final EditFieldKind kind;
  const EditFieldScreen({super.key, required this.kind});

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _verifying = false;
  bool _emailVerified = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final initial = switch (widget.kind) {
      EditFieldKind.email => user?.email ?? '',
      EditFieldKind.age => (user?.age ?? 0) > 0 ? '${user!.age}' : '',
      EditFieldKind.profession => user?.profession ?? '',
    };
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
        EditFieldKind.email => 'Update Email',
        EditFieldKind.age => 'Update Age',
        EditFieldKind.profession => 'Update Profession',
      };

  String get _label => switch (widget.kind) {
        EditFieldKind.email => 'Email Address',
        EditFieldKind.age => 'Your Age',
        EditFieldKind.profession => 'Profession',
      };

  String get _hint => switch (widget.kind) {
        EditFieldKind.email => 'name@example.com',
        EditFieldKind.age => '25',
        EditFieldKind.profession => 'Software Engineer',
      };

  IconData get _icon => switch (widget.kind) {
        EditFieldKind.email => Icons.mail_outline_rounded,
        EditFieldKind.age => Icons.cake_outlined,
        EditFieldKind.profession => Icons.work_outline_rounded,
      };

  String get _description => switch (widget.kind) {
        EditFieldKind.email =>
          'We\'ll send a verification code to confirm your new email.',
        EditFieldKind.age =>
          'Your age helps us recommend roles aligned with your experience.',
        EditFieldKind.profession =>
          'Tell us your current role so we can match you with relevant jobs.',
      };

  TextInputType get _keyboardType => switch (widget.kind) {
        EditFieldKind.email => TextInputType.emailAddress,
        EditFieldKind.age => TextInputType.number,
        EditFieldKind.profession => TextInputType.text,
      };

  List<TextInputFormatter>? get _formatters => switch (widget.kind) {
        EditFieldKind.age => [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
        _ => null,
      };

  String? _validate(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'This field is required';
    switch (widget.kind) {
      case EditFieldKind.email:
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
          return 'Enter a valid email address';
        }
        return null;
      case EditFieldKind.age:
        final n = int.tryParse(value);
        if (n == null || n < 13 || n > 100) return 'Enter a valid age';
        return null;
      case EditFieldKind.profession:
        if (value.length < 2) return 'Profession is too short';
        return null;
    }
  }

  Future<void> _verifyEmail() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(_controller.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email first')),
      );
      return;
    }
    setState(() => _verifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _emailVerified = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email verified successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final value = _controller.text.trim();
    switch (widget.kind) {
      case EditFieldKind.email:
        await auth.updateProfile(email: value);
        break;
      case EditFieldKind.age:
        await auth.updateProfile(age: int.parse(value));
        break;
      case EditFieldKind.profession:
        await auth.updateProfile(profession: value);
        break;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_label updated'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                _Header(title: _title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_icon,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(height: 16),
                        AppText.h2(_title),
                        const SizedBox(height: 8),
                        AppText.body(
                          _description,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_label, style: AppTextStyles.labelSmall),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _controller,
                                keyboardType: _keyboardType,
                                inputFormatters: _formatters,
                                validator: _validate,
                                autofocus: true,
                                style: AppTextStyles.bodyLarge
                                    .copyWith(fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: _hint,
                                  hintStyle: AppTextStyles.bodyLarge.copyWith(
                                      color: AppColors.textHint,
                                      fontWeight: FontWeight.w400),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  suffixIcon: widget.kind == EditFieldKind.email
                                      ? _emailVerified
                                          ? const Icon(Icons.verified_rounded,
                                              color: AppColors.success)
                                          : null
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.kind == EditFieldKind.email) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed:
                                _verifying || _emailVerified ? null : _verifyEmail,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  )
                                : Icon(
                                    _emailVerified
                                        ? Icons.check_circle_rounded
                                        : Icons.send_rounded,
                                    size: 16),
                            label: Text(_emailVerified
                                ? 'Verified'
                                : (_verifying
                                    ? 'Sending code...'
                                    : 'Send verification code')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _emailVerified
                                  ? AppColors.success
                                  : AppColors.primary,
                              side: BorderSide(
                                  color: _emailVerified
                                      ? AppColors.success
                                      : AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text('Update', style: AppTextStyles.button),
                    ),
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

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: context.textPrimary),
            ),
          ),
          Expanded(
            child: Center(child: Text(title, style: AppTextStyles.h4)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

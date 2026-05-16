import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/verification_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/trust_badges.dart';

/// Hirer-side "Verify your company" flow. Top of the screen shows a
/// status pill summarising overall verification + trust; below are four
/// channel rows (GST, Domain email, Website, LinkedIn) that the hirer
/// can tap into to submit proof. Each row reflects approved /
/// auto-verified / pending / rejected / not started.
class HirerVerificationScreen extends StatefulWidget {
  const HirerVerificationScreen({super.key});

  @override
  State<HirerVerificationScreen> createState() =>
      _HirerVerificationScreenState();
}

class _HirerVerificationScreenState extends State<HirerVerificationScreen> {
  final _svc = VerificationService.instance;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _submissions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.status();
      _profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
      _submissions = (data['submissions'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _levels =>
      (_profile?['levels'] as Map?)?.cast<String, dynamic>() ?? const {};

  String _latestStatus(String channel) {
    final s = _submissions.firstWhere(
      (e) => e['channel'] == channel,
      orElse: () => const {},
    );
    return (s['status'] as String?) ?? 'not_started';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify your company', style: AppTextStyles.h3),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText.body(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        PrimaryButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _statusCard(),
                      const SizedBox(height: 24),
                      AppText.labelSmall(
                        'CHANNELS',
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                      const SizedBox(height: 8),
                      _channelRow(
                        title: 'GST number',
                        subtitle:
                            'Submit your registered GSTIN. Admin verifies against the GST portal.',
                        verified: _levels['gst'] == true,
                        status: _latestStatus('gst'),
                        onTap: _openGst,
                      ),
                      _channelRow(
                        title: 'Official domain email',
                        subtitle:
                            'Receive an OTP at name@yourcompany.com. Auto-verified once OTP is confirmed.',
                        verified: _levels['domainEmail'] == true,
                        status: _latestStatus('domain_email'),
                        onTap: _openDomainEmail,
                      ),
                      _channelRow(
                        title: 'Website ownership',
                        subtitle:
                            'Host a token file at /.well-known/jobhunter-verification.txt.',
                        verified: _levels['website'] == true,
                        status: _latestStatus('website'),
                        onTap: _openWebsite,
                      ),
                      _channelRow(
                        title: 'LinkedIn company page',
                        subtitle:
                            'Submit your LinkedIn page URL. Admin matches it against your account.',
                        verified: _levels['linkedin'] == true,
                        status: _latestStatus('linkedin'),
                        onTap: _openLinkedin,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statusCard() {
    final isVerified = _profile?['isVerified'] as bool? ?? false;
    final trust = (_profile?['trustScore'] as num?)?.toInt() ?? 0;
    final approval =
        _profile?['approvalStatus'] as String? ?? 'pending_review';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isVerified) const VerifiedBadge(size: BadgeSize.medium),
              if (isVerified) const SizedBox(width: 8),
              TrustScorePill(score: trust),
            ],
          ),
          const SizedBox(height: 12),
          AppText.body(
            isVerified
                ? 'Your company is verified. Verified accounts get higher posting limits and a green badge on every job.'
                : approval == 'suspended'
                    ? 'Your account is suspended. Resolve open reports before posting.'
                    : approval == 'banned'
                        ? 'Your account is banned. Contact support.'
                        : 'Verify at least one channel to remove posting limits and earn the Verified badge.',
          ),
        ],
      ),
    );
  }

  Widget _channelRow({
    required String title,
    required String subtitle,
    required bool verified,
    required String status,
    required VoidCallback onTap,
  }) {
    final pillColor = verified
        ? AppColors.success
        : status == 'pending'
            ? Colors.orange
            : status == 'rejected'
                ? AppColors.urgent
                : AppColors.textTertiary;
    final pillLabel = verified
        ? 'Verified'
        : status == 'pending'
            ? 'In review'
            : status == 'rejected'
                ? 'Rejected'
                : status == 'auto_verified'
                    ? 'Verified'
                    : 'Not started';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.body(title, fontWeight: FontWeight.w600),
                    const SizedBox(height: 4),
                    AppText.caption(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pillColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText.labelSmall(
                  pillLabel,
                  color: pillColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Channel actions ─────────────────────────────────────────────────────

  Future<void> _openGst() async {
    final controller = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimplePromptSheet(
        title: 'Submit GSTIN',
        hint: '22ABCDE1234F1Z5',
        controller: controller,
        formatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          LengthLimitingTextInputFormatter(15),
        ],
        onSubmit: () async {
          await _svc.submitGst(controller.text.trim().toUpperCase());
        },
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openDomainEmail() async {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DomainEmailSheet(
        emailCtrl: emailCtrl,
        codeCtrl: codeCtrl,
        onSend: () async => _svc.submitDomainEmail(emailCtrl.text.trim()),
        onConfirm: () async => _svc.confirmDomainEmail(
          emailCtrl.text.trim(),
          codeCtrl.text.trim(),
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openWebsite() async {
    final controller = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimplePromptSheet(
        title: 'Submit website',
        hint: 'https://yourcompany.com',
        controller: controller,
        onSubmit: () async {
          final data = await _svc.submitWebsite(controller.text.trim());
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (dctx) => AlertDialog(
              title: const Text('Verification token issued'),
              content: SelectableText(data['token'] as String? ?? ''),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: data['token'] as String? ?? '',
                    ));
                    Navigator.pop(dctx);
                  },
                  child: const Text('Copy & close'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _openLinkedin() async {
    final controller = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SimplePromptSheet(
        title: 'Submit LinkedIn URL',
        hint: 'https://linkedin.com/company/your-company',
        controller: controller,
        onSubmit: () async {
          await _svc.submitLinkedin(controller.text.trim());
        },
      ),
    );
    if (ok == true) _load();
  }
}

class _SimplePromptSheet extends StatefulWidget {
  const _SimplePromptSheet({
    required this.title,
    required this.hint,
    required this.controller,
    required this.onSubmit,
    this.formatters,
  });
  final String title;
  final String hint;
  final TextEditingController controller;
  final Future<void> Function() onSubmit;
  final List<TextInputFormatter>? formatters;

  @override
  State<_SimplePromptSheet> createState() => _SimplePromptSheetState();
}

class _SimplePromptSheetState extends State<_SimplePromptSheet> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.h4(widget.title),
              const SizedBox(height: 12),
              CustomTextField(
                controller: widget.controller,
                hint: widget.hint,
                inputFormatters: widget.formatters,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Submit',
                isLoading: _busy,
                onPressed: _busy ? null : _run,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainEmailSheet extends StatefulWidget {
  const _DomainEmailSheet({
    required this.emailCtrl,
    required this.codeCtrl,
    required this.onSend,
    required this.onConfirm,
  });
  final TextEditingController emailCtrl;
  final TextEditingController codeCtrl;
  final Future<void> Function() onSend;
  final Future<void> Function() onConfirm;

  @override
  State<_DomainEmailSheet> createState() => _DomainEmailSheetState();
}

class _DomainEmailSheetState extends State<_DomainEmailSheet> {
  bool _sent = false;
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSend();
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.h4('Verify company email'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: widget.emailCtrl,
                hint: 'name@yourcompany.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_sent,
              ),
              const SizedBox(height: 12),
              if (_sent) ...[
                CustomTextField(
                  controller: widget.codeCtrl,
                  hint: '6-digit OTP',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Confirm',
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
              ] else
                PrimaryButton(
                  label: 'Send OTP',
                  isLoading: _busy,
                  onPressed: _busy ? null : _send,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/report_service.dart';
import 'app_text.dart';
import 'custom_button.dart';
import 'custom_text_field.dart';

class _ReasonOption {
  final String value;
  final String label;
  const _ReasonOption(this.value, this.label);
}

const _jobReasons = <_ReasonOption>[
  _ReasonOption('fake_job', 'Looks like a fake job'),
  _ReasonOption('asks_payment', 'Asks for payment / fee'),
  _ReasonOption('misleading_salary', 'Misleading salary'),
  _ReasonOption('mlm_scam', 'MLM / pyramid scheme'),
  _ReasonOption('whatsapp_only_contact', 'WhatsApp / Telegram only contact'),
  _ReasonOption('phishing_link', 'Phishing / suspicious link'),
  _ReasonOption('duplicate', 'Duplicate posting'),
  _ReasonOption('discriminatory', 'Discriminatory wording'),
  _ReasonOption('spam', 'Spam'),
  _ReasonOption('other', 'Other'),
];

const _recruiterReasons = <_ReasonOption>[
  _ReasonOption('fake_recruiter', 'Impersonating a real company'),
  _ReasonOption('asks_payment', 'Asked me for money'),
  _ReasonOption('harassment', 'Harassment / inappropriate behaviour'),
  _ReasonOption('discriminatory', 'Discriminatory conduct'),
  _ReasonOption('spam', 'Spamming applicants'),
  _ReasonOption('other', 'Other'),
];

/// Bottom-sheet entry point used from the job detail screen and the
/// recruiter profile screen. Returns true if the user successfully filed
/// a report so the caller can show a confirmation toast.
Future<bool> showReportSheet({
  required BuildContext context,
  required String subjectType, // 'job' | 'recruiter' | 'company' | 'message'
  required String subjectId,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(
      subjectType: subjectType,
      subjectId: subjectId,
    ),
  );
  return res ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.subjectType, required this.subjectId});
  final String subjectType;
  final String subjectId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  List<_ReasonOption> get _options =>
      widget.subjectType == 'recruiter' || widget.subjectType == 'message'
          ? _recruiterReasons
          : _jobReasons;

  Future<void> _submit() async {
    if (_reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ReportService.instance.create(
        subjectType: widget.subjectType,
        subjectId: widget.subjectId,
        reason: _reason!,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppText.h4(
                widget.subjectType == 'recruiter'
                    ? 'Report this recruiter'
                    : 'Report this job',
              ),
              const SizedBox(height: 6),
              AppText.caption(
                'Reports are confidential. Our trust team reviews every submission.',
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              ..._options.map(
                (o) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: o.value,
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  title: AppText.body(o.label),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _descCtrl,
                hint: 'Add details (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Submit report',
                isLoading: _submitting,
                onPressed: _reason == null || _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

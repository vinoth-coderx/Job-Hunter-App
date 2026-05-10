import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/auto_apply_service.dart';
import '../widgets/custom_button.dart';

/// Review-mode UI: shows today's auto-matched candidates, lets the user
/// toggle each on/off, and submits the approved set in bulk.
class AutoApplyReviewScreen extends StatefulWidget {
  const AutoApplyReviewScreen({super.key});

  @override
  State<AutoApplyReviewScreen> createState() => _AutoApplyReviewScreenState();
}

class _AutoApplyReviewScreenState extends State<AutoApplyReviewScreen> {
  final AutoApplyService _service = AutoApplyService.instance;
  AutoApplyPreview? _preview;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final Set<String> _approved = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await _service.getPreview();
      setState(() {
        _preview = preview;
        // Pre-approve everything ≥ 80% — quality matches that don't need
        // a manual gate. User can untick before submitting.
        if (preview != null) {
          _approved
            ..clear()
            ..addAll(
              preview.candidates
                  .where((c) => c.matchScore >= 80)
                  .map((c) => c.jobId),
            );
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final p = _preview;
    if (p == null || _approved.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final r = await _service.approveJobs(
        logId: p.logId,
        jobIds: _approved.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Applied to ${r.applied} jobs · ${r.failed} failed · ${r.skipped} skipped'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Review today\'s matches'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _preview == null
                  ? _emptyState()
                  : _content(_preview!),
      bottomNavigationBar: _preview == null || _preview!.candidates.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: _approved.isEmpty
                      ? 'Approve at least one match'
                      : 'Apply to ${_approved.length} approved',
                  icon: Icons.send,
                  isLoading: _submitting,
                  onPressed: _approved.isEmpty || _submitting ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _content(AutoApplyPreview p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Text(
          '${p.candidates.length} matches found from ${p.jobsScanned} jobs scanned',
          style: AppTextStyles.bodySmall
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 12),
        ...p.candidates.map(_card),
      ],
    );
  }

  Widget _card(AutoApplyPreviewCandidate c) {
    final approved = _approved.contains(c.jobId);
    Color matchColor;
    if (c.matchScore >= 80) {
      matchColor = AppColors.success;
    } else if (c.matchScore >= 65) {
      matchColor = AppColors.warning;
    } else {
      matchColor = context.textTertiary;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: approved
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.cardBorder,
          width: approved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.jobTitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary)),
                    Text(c.companyName,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: context.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${c.matchScore}%',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: matchColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (c.location != null && c.location!.isNotEmpty)
                _tag(c.location!),
              if (c.jobType != null && c.jobType!.isNotEmpty) _tag(c.jobType!),
              if (c.remoteType != null && c.remoteType!.isNotEmpty)
                _tag(c.remoteType!),
              ...c.skills.take(4).map(_tag),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: approved ? 'Skip' : 'Skip',
                  icon: Icons.close,
                  onPressed: () => setState(() => _approved.remove(c.jobId)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: approved ? 'Approved' : 'Approve',
                  icon: approved ? Icons.check : Icons.send,
                  backgroundColor:
                      approved ? AppColors.success : AppColors.primary,
                  onPressed: () => setState(() {
                    if (approved) {
                      _approved.remove(c.jobId);
                    } else {
                      _approved.add(c.jobId);
                    }
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s,
            style: AppTextStyles.labelSmall
                .copyWith(color: context.textSecondary)),
      );

  Widget _emptyState() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.auto_awesome,
              size: 56, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No matches awaiting review',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-Apply will surface matches here at your scheduled run time.',
            textAlign: TextAlign.center,
            style:
                AppTextStyles.bodySmall.copyWith(color: context.textTertiary),
          ),
        ],
      );

  Widget _errorState() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
          const SizedBox(height: 12),
          Text(_error ?? 'Could not load',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
}

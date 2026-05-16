import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/services/ai_service.dart';
import '../../../providers/ai_quota_provider.dart';
import '../../widgets/app_text.dart';
import '../../widgets/custom_button.dart';
import 'ai_feedback_bar.dart';

/// Bottom-sheet that generates + shows a tailored cover letter for a job.
/// Auto-runs on open; users can pick a different tone, copy the letter,
/// or close. Reuses the existing /ai/cover-letter endpoint — cached
/// (job, tone, user) tuples skip quota.
class CoverLetterSheet extends StatefulWidget {
  final String jobId;
  final String? jobTitle;
  const CoverLetterSheet({
    super.key,
    required this.jobId,
    this.jobTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    String? jobTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => CoverLetterSheet(jobId: jobId, jobTitle: jobTitle),
    );
  }

  @override
  State<CoverLetterSheet> createState() => _CoverLetterSheetState();
}

class _CoverLetterSheetState extends State<CoverLetterSheet> {
  static const _tones = ['professional', 'friendly', 'technical'];
  String _tone = 'professional';
  String? _letter;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AiService.instance.generateCoverLetter(
        jobId: widget.jobId,
        tone: _tone,
      );
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(res.quota);
      setState(() {
        _letter = res.data?.letter;
        _loading = false;
      });
    } on AiQuotaExceededException catch (e) {
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(e.quota);
      setState(() {
        _loading = false;
        _error = e.message;
      });
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setTone(String tone) async {
    if (tone == _tone || _loading) return;
    setState(() => _tone = tone);
    await _run();
  }

  Future<void> _copy() async {
    final l = _letter;
    if (l == null || l.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: l));
    if (!mounted) return;
    AppSnackbar.success(context, 'Cover letter copied');
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: AppRadius.pillRadius,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText.h4(
                      widget.jobTitle != null && widget.jobTitle!.isNotEmpty
                          ? 'Cover letter — ${widget.jobTitle}'
                          : 'Cover letter',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _run,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Re-generate',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tones.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = _tones[i];
                    final selected = t == _tone;
                    return ChoiceChip(
                      label: Text(_label(t)),
                      selected: selected,
                      onSelected: _loading ? null : (_) => _setTone(t),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.16),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _body(context),
              ),
            ),
            // Feedback bar only when we actually have a letter to rate.
            // refId combines jobId + tone so a thumbs-down on the
            // 'professional' draft doesn't clobber the user's earlier
            // 'friendly' rating for the same job.
            if (_letter != null && _letter!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AiFeedbackBar(
                  feature: 'cover_letter',
                  refId: '${widget.jobId}:$_tone',
                  label: 'Did this letter feel right?',
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Copy',
                      icon: Icons.copy,
                      onPressed: (_letter == null || _letter!.isEmpty)
                          ? null
                          : _copy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: AppText.body(_error!,
            color: AppColors.urgent, textAlign: TextAlign.center),
      );
    }
    final l = _letter ?? '';
    if (l.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: AppText.body('No letter generated.',
            textAlign: TextAlign.center),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          l,
          style: const TextStyle(height: 1.5),
        ),
      ),
    );
  }

  String _label(String tone) {
    switch (tone) {
      case 'friendly':
        return 'Friendly';
      case 'technical':
        return 'Technical';
      default:
        return 'Professional';
    }
  }
}

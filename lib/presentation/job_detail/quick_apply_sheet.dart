import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/job_model.dart';
import '../../data/services/ai_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coins_provider.dart';
import '../../providers/job_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Bottom sheet for one-click apply on native jobs.
/// Returns:
///   true  → application sent successfully
///   false → user cancelled
///   null  → sheet closed before submit (back gesture)
class QuickApplySheet extends StatefulWidget {
  final Job job;
  const QuickApplySheet({super.key, required this.job});

  @override
  State<QuickApplySheet> createState() => _QuickApplySheetState();

  static Future<bool?> show(BuildContext context, Job job) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickApplySheet(job: job),
    );
  }
}

class _QuickApplySheetState extends State<QuickApplySheet> {
  final _note = TextEditingController();
  final Map<String, TextEditingController> _answers = {};
  bool _submitting = false;
  bool _generatingLetter = false;

  @override
  void initState() {
    super.initState();
    for (final q in widget.job.screeningQuestions) {
      _answers[q.question] = TextEditingController();
    }
  }

  Future<void> _generateAiLetter() async {
    if (_generatingLetter) return;
    setState(() => _generatingLetter = true);
    try {
      final res = await AiService.instance.generateCoverLetter(
        jobId: widget.job.id,
      );
      if (!mounted) return;
      // Keep the global quota banner in sync — every cover-letter call
      // returns a fresh snapshot.
      context.read<AiQuotaProvider>().update(res.quota);
      final letter = res.data?.letter ?? '';
      if (letter.isEmpty) {
        AppSnackbar.error(context, 'AI couldn\'t draft a letter');
        return;
      }
      _note.text = letter;
      AppSnackbar.success(
        context,
        (res.data?.usedAi ?? false)
            ? 'AI cover letter ready — review and edit'
            : 'Generated a base letter (LLM unavailable)',
      );
    } on AiQuotaExceededException catch (e) {
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(e.quota);
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _generatingLetter = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    for (final q in widget.job.screeningQuestions) {
      if (q.isRequired) {
        final a = _answers[q.question]?.text.trim() ?? '';
        if (a.isEmpty) {
          AppSnackbar.info(context, 'Required question: "${q.question}"');
          return;
        }
      }
    }

    setState(() => _submitting = true);
    final jobProvider = context.read<JobProvider>();
    final ok = await jobProvider.quickApplyToJob(
      widget.job,
      quickNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
      screeningAnswers: _answers.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => (question: e.key, answer: e.value.text.trim()))
          .toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      AppSnackbar.error(
        context,
        jobProvider.error ?? 'Could not send application',
      );
      return;
    }
    // Sync the header coin pill from the server-confirmed balance.
    final balance = jobProvider.lastApplyCoinsBalance;
    if (balance != null) {
      context.read<CoinsProvider>().setBalance(balance);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    // Resume presence now derives from the flat profile's extracted text
    // blob — the old nested resumeProfile.resumeFileName field is gone.
    final hasResume = (user?.resumeText ?? '').trim().isNotEmpty;
    final resumeFileName =
        hasResume ? 'Resume on file' : '';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          children: [
            _DragHandle(),
            const SizedBox(height: 14),
            _Header(job: widget.job),
            const SizedBox(height: 18),
            _ProfileCard(
              name: user?.name ?? 'Your name',
              email: user?.email ?? '',
              photoUrl: user?.photoUrl,
            ),
            const SizedBox(height: 10),
            _ResumeStatus(
              hasResume: hasResume,
              fileName: resumeFileName,
            ),
            if (widget.job.matchScore != null) ...[
              const SizedBox(height: 10),
              _MatchPill(score: widget.job.matchScore!),
            ],
            const SizedBox(height: 22),
            _SectionLabel(
              icon: Icons.edit_note_rounded,
              title: 'Quick note',
              trailing: TextButton.icon(
                onPressed: _generatingLetter ? null : _generateAiLetter,
                icon: _generatingLetter
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('AI letter'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _note,
              hint: 'A short message to the hirer (optional)…',
              maxLines: 6,
              minLines: 3,
              maxLength: 4000,
            ),

            if (widget.job.screeningQuestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel(
                icon: Icons.fact_check_outlined,
                title: 'Screening questions',
              ),
              const SizedBox(height: 8),
              ...widget.job.screeningQuestions.map(_buildScreening),
            ],

            const SizedBox(height: 24),
            PrimaryButton(
              label: hasResume ? 'Easy Apply' : 'Upload resume first',
              icon: Icons.bolt_rounded,
              isLoading: _submitting,
              onPressed: !hasResume || _submitting ? null : _submit,
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Cancel',
              onPressed:
                  _submitting ? null : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreening(JobScreeningQuestion q) {
    final c = _answers[q.question]!;
    Widget input;
    if (q.type == 'yes_no') {
      input = _YesNoToggle(
        value: c.text,
        onChanged: (v) => setState(() => c.text = v),
      );
    } else if (q.type == 'mcq' && q.options.isNotEmpty) {
      input = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: q.options
            .map((o) => ChoiceChip(
                  label: Text(o),
                  selected: c.text == o,
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  side: BorderSide(color: context.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.smRadius,
                  ),
                  onSelected: (_) => setState(() => c.text = o),
                ))
            .toList(),
      );
    } else {
      input = CustomTextField(
        controller: c,
        hint: 'Your answer',
        maxLines: 3,
        minLines: 2,
        maxLength: 2000,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    q.question,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                if (q.isRequired)
                  Container(
                    margin: const EdgeInsets.only(left: 6, top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.urgent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.urgent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            input,
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: context.cardBorder,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Job job;
  const _Header({required this.job});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.primary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: AppRadius.mdRadius,
          ),
          child: const Icon(Icons.bolt_rounded,
              color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Easy Apply',
                    style: AppTextStyles.h3.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ONE TAP',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                job.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (job.company.isNotEmpty)
                Text(
                  job.company,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  const _ProfileCard({
    required this.name,
    required this.email,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          AppAvatar(url: photoUrl, name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary),
                  ),
              ],
            ),
          ),
          Icon(Icons.verified_outlined,
              color: AppColors.primary.withValues(alpha: 0.7), size: 20),
        ],
      ),
    );
  }
}

class _ResumeStatus extends StatelessWidget {
  final bool hasResume;
  final String fileName;
  const _ResumeStatus({required this.hasResume, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final color = hasResume ? AppColors.success : AppColors.warning;
    final bg = hasResume
        ? AppColors.success.withValues(alpha: 0.08)
        : AppColors.warning.withValues(alpha: 0.10);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            hasResume
                ? Icons.description_outlined
                : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasResume
                  ? (fileName.isNotEmpty ? fileName : 'Resume on file')
                  : 'No resume on file — upload one before applying',
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Match-fit pill shown above the Quick note section. Colour tier
/// matches the home/job-detail badges so users build a consistent
/// "green = strong fit" intuition across screens.
class _MatchPill extends StatelessWidget {
  final double score;
  const _MatchPill({required this.score});

  @override
  Widget build(BuildContext context) {
    final s = score.round();
    Color color;
    String label;
    if (s >= 90) {
      color = AppColors.success;
      label = 'Strong fit · $s% match';
    } else if (s >= 75) {
      color = AppColors.primary;
      label = 'Good fit · $s% match';
    } else if (s >= 50) {
      color = AppColors.warning;
      label = 'Worth a try · $s% match';
    } else {
      color = context.textSecondary;
      label = 'Stretch · $s% match';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header inside the Easy Apply sheet. Adds a small primary
/// accent bar before the icon so each section reads as a labelled block
/// rather than an unframed icon-text pair (the old version made
/// "Quick note" and "Screening questions" feel like body copy).
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionLabel({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Yes/No toggle for boolean screening questions. Each option is its
/// own card with a colour-coded check/cross icon, so the seeker
/// understands the choice at a glance — the previous plain text buttons
/// felt indistinguishable from a pair of generic CTAs.
class _YesNoToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _YesNoToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(
            context,
            label: 'Yes',
            icon: Icons.check_circle_rounded,
            selected: value == 'Yes',
            color: AppColors.success,
            onTap: () => onChanged('Yes'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(
            context,
            label: 'No',
            icon: Icons.cancel_rounded,
            selected: value == 'No',
            color: AppColors.urgent,
            onTap: () => onChanged('No'),
          ),
        ),
      ],
    );
  }

  Widget _toggleButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : context.surface,
      borderRadius: AppRadius.inputRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.inputRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.inputRadius,
            border: Border.all(
              color: selected ? color : context.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? color : context.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? color : context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/ats_analysis_model.dart';
import '../../data/services/ai_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/ats_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import 'widgets/ai_feedback_bar.dart';
import 'widgets/ai_quota_banner.dart';
import 'widgets/cover_letter_sheet.dart';

/// ATS resume scoring screen. Two flows:
///   - Generic: scores the user's resume on ATS best-practices.
///   - Targeted: pass `jobId` via route arguments to score against that job.
///
/// One AI call per (resume, job) is cached server-side, so re-opening the
/// screen for the same job is free of quota.
class AtsScoreScreen extends StatefulWidget {
  /// When supplied, the analysis is tailored to this job's keywords.
  final String? jobId;
  final String? jobTitle;
  const AtsScoreScreen({super.key, this.jobId, this.jobTitle});

  @override
  State<AtsScoreScreen> createState() => _AtsScoreScreenState();
}

class _AtsScoreScreenState extends State<AtsScoreScreen>
    with TapGuardMixin<AtsScoreScreen> {
  bool _autoRanOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only auto-run if the user has a resume on file. Otherwise show
      // the upload nudge instead of a guaranteed-error analyze call.
      final auth = context.read<AuthProvider>();
      final hasResume = (auth.user?.resumeText?.isNotEmpty ?? false);
      if (hasResume && !_autoRanOnce) {
        _autoRanOnce = true;
        _runAnalysis();
      }
    });
  }

  Future<void> _runAnalysis({bool refresh = false}) async {
    final ats = context.read<AtsProvider>();
    final quota = context.read<AiQuotaProvider>();
    try {
      final newQuota = await ats.analyze(
        jobId: widget.jobId,
        refresh: refresh,
      );
      quota.update(newQuota);
    } on AiQuotaExceededException catch (e) {
      quota.update(e.quota);
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Could not run analysis: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasResume = (auth.user?.resumeText?.isNotEmpty ?? false);
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const AppText.h4('ATS Resume Score'),
        backgroundColor: context.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AiQuotaBanner(),
            if (widget.jobTitle != null && widget.jobTitle!.isNotEmpty) ...[
              _ScopeBadge(label: 'Scoring against: ${widget.jobTitle}'),
              const SizedBox(height: 12),
            ],
            if (!hasResume)
              _NoResumeCard()
            else
              Consumer<AtsProvider>(
                builder: (_, ats, __) {
                  if (ats.isLoading) return const _LoadingCard();
                  final result = ats.result;
                  if (result == null) {
                    return _StartCard(
                      onAnalyze: () => guard(() => _runAnalysis()),
                    );
                  }
                  return _ResultCard(
                    result: result,
                    jobId: widget.jobId,
                    jobTitle: widget.jobTitle,
                    onRefresh: () =>
                        guard(() => _runAnalysis(refresh: true), key: 'refresh'),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ScopeBadge extends StatelessWidget {
  final String label;
  const _ScopeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: AppText.caption(
              label,
              color: AppColors.primary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResumeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.description_outlined,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const AppText.h4(
            'Upload a resume first',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const AppText.caption(
            'We need your resume on file to score it against ATS rules.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Go to profile',
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            AppText.body('Analysing your resume…'),
          ],
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  final VoidCallback onAnalyze;
  const _StartCard({required this.onAnalyze});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.bolt, size: 36, color: AppColors.primary),
          const SizedBox(height: 12),
          const AppText.h3('Get your ATS score'),
          const SizedBox(height: 6),
          const AppText.caption(
            'We score your resume on ATS-friendliness, surface missing keywords, '
            'and suggest fixes to improve your match rate.',
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Run analysis', onPressed: onAnalyze),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AtsAnalysisResult result;
  final VoidCallback onRefresh;
  /// When the analysis is scoped to a specific job, we surface the
  /// "Generate cover letter" CTA at the bottom — same job context, one
  /// fewer screen for the seeker to bounce through.
  final String? jobId;
  final String? jobTitle;
  const _ResultCard({
    required this.result,
    required this.onRefresh,
    this.jobId,
    this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    final scopedToJob = jobId != null && jobId!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreHero(result: result, onRefresh: onRefresh),
        const SizedBox(height: 16),
        if (result.matchedSkills.isNotEmpty)
          _SkillSection(
            title: 'Matched skills',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            chips: result.matchedSkills,
          ),
        if (result.missingKeywords.isNotEmpty)
          _SkillSection(
            title: 'Missing keywords',
            icon: Icons.error_outline,
            color: AppColors.warning,
            chips: result.missingKeywords,
          ),
        if (result.strengths.isNotEmpty)
          _BulletSection(
            title: 'Strengths',
            icon: Icons.thumb_up_alt_outlined,
            color: AppColors.success,
            items: result.strengths,
          ),
        if (result.weaknesses.isNotEmpty)
          _BulletSection(
            title: 'Weaknesses',
            icon: Icons.warning_amber_outlined,
            color: AppColors.warning,
            items: result.weaknesses,
          ),
        if (result.suggestions.isNotEmpty)
          _BulletSection(
            title: 'Suggestions',
            icon: Icons.lightbulb_outline,
            color: AppColors.primary,
            items: result.suggestions,
          ),
        if (result.formattingIssues.isNotEmpty) ...[
          const SizedBox(height: 4),
          _IssuesSection(issues: result.formattingIssues),
        ],
        if (scopedToJob) ...[
          const SizedBox(height: 16),
          _CoverLetterCta(jobId: jobId!, jobTitle: jobTitle),
        ],
        // Only ask for feedback when we actually ran the AI — rating
        // the heuristic fallback is meaningless and pollutes analytics.
        if (result.usedAi) ...[
          const SizedBox(height: 12),
          AiFeedbackBar(
            feature: 'ats_score',
            refId: scopedToJob ? 'job:$jobId' : 'generic',
            label: 'Was this ATS analysis useful?',
          ),
        ],
        const SizedBox(height: 12),
        if (!result.usedAi)
          AppText.caption(
            'Computed without AI (heuristic mode). Configure an AI key to '
            'unlock the full analysis.',
            color: AppColors.textTertiary,
          ),
      ],
    );
  }
}

/// "Generate cover letter for this job" prompt card. Only rendered when
/// the ATS analysis is scoped to a specific job. Opens the existing
/// CoverLetterSheet which calls /ai/cover-letter with the job context.
class _CoverLetterCta extends StatelessWidget {
  final String jobId;
  final String? jobTitle;
  const _CoverLetterCta({required this.jobId, this.jobTitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => CoverLetterSheet.show(
          context,
          jobId: jobId,
          jobTitle: jobTitle,
        ),
        borderRadius: AppRadius.lgRadius,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: AppRadius.lgRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smRadius,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.mail_outline,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.h4('Generate a cover letter'),
                    SizedBox(height: 2),
                    AppText.caption(
                      'Tailored to this job. Pick a tone — copy in one tap.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  final AtsAnalysisResult result;
  final VoidCallback onRefresh;
  const _ScoreHero({required this.result, required this.onRefresh});

  Color _bandColor() {
    if (result.score >= 70) return AppColors.success;
    if (result.score >= 50) return AppColors.warning;
    return AppColors.urgent;
  }

  @override
  Widget build(BuildContext context) {
    final bandColor = _bandColor();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _DonutPainter(
                progress: result.score / 100,
                trackColor: context.surfaceVariant,
                progressColor: bandColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText.h1(
                      '${result.score}',
                      color: bandColor,
                      fontSize: 28,
                    ),
                    const AppText.caption('/ 100'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h4(result.band, color: bandColor),
                const SizedBox(height: 4),
                AppText.caption(
                  result.cached
                      ? 'Cached — re-runs are free until you edit your resume'
                      : 'Fresh analysis',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Re-analyse'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.smRadius,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
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

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  _DonutPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawCircle(center, radius, track);
    final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}

class _SkillSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> chips;
  const _SkillSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                AppText.h4(title),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in chips)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: AppRadius.pillRadius,
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: AppText.chip(c, color: color),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _BulletSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                AppText.h4(title),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: AppText.body(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IssuesSection extends StatelessWidget {
  final List<AtsFormattingIssue> issues;
  const _IssuesSection({required this.issues});

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return AppColors.urgent;
      case 'low':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.format_align_left,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              AppText.h4('Formatting issues'),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _severityColor(issue.severity)
                          .withValues(alpha: 0.12),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: AppText.labelSmall(
                      issue.severity.toUpperCase(),
                      color: _severityColor(issue.severity),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: AppText.body(issue.message)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

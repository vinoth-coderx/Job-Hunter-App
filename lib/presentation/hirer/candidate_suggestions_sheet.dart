import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/applicant_model.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/applicants_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../widgets/app_avatar.dart';

/// Bottom-sheet that surfaces AI candidate suggestions for the given
/// job — pulled from the hirer's past applicant pool and ranked against
/// this job's requirements. Read-only: tap a row to see the strengths /
/// concerns expanded, no actions (yet) since reaching out is a separate
/// product decision (chat invite vs email vs the "invite to apply" flow
/// the hirer side already has).
class CandidateSuggestionsSheet extends StatefulWidget {
  final String jobId;
  final String? jobTitle;
  const CandidateSuggestionsSheet({
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
      builder: (_) =>
          CandidateSuggestionsSheet(jobId: jobId, jobTitle: jobTitle),
    );
  }

  @override
  State<CandidateSuggestionsSheet> createState() =>
      _CandidateSuggestionsSheetState();
}

class _CandidateSuggestionsSheetState
    extends State<CandidateSuggestionsSheet> {
  List<SuggestedCandidate>? _items;
  int? _poolSize;
  bool _cached = false;
  bool _loading = false;
  String? _error;
  final Set<String> _expanded = <String>{};

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
      final res = await ApplicantsService.instance.suggestCandidates(
        jobId: widget.jobId,
      );
      if (!mounted) return;
      // Refresh quota banner so the hirer sees the post-call debit.
      await context.read<AiQuotaProvider>().refresh();
      setState(() {
        _items = res.items;
        _poolSize = res.poolSize;
        _cached = res.cached;
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested candidates',
                      style: AppTextStyles.h4
                          .copyWith(color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _run,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Re-run',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.jobTitle != null && widget.jobTitle!.isNotEmpty
                    ? 'From your past applicant pool — ranked for ${widget.jobTitle}'
                    : 'From your past applicant pool',
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary),
              ),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.urgent, height: 1.4),
        ),
      );
    }
    final items = _items ?? const <SuggestedCandidate>[];
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: context.textTertiary),
            const SizedBox(height: 12),
            Text(
              _poolSize == 0
                  ? 'No past applicants to draw from yet.'
                  : 'No strong fits in your applicant pool for this job.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _cached
                  ? '${items.length} suggestions · cached'
                  : '${items.length} suggestions · from a pool of $_poolSize',
              style: AppTextStyles.labelSmall
                  .copyWith(color: context.textTertiary, letterSpacing: 0.6),
            ),
          );
        }
        final c = items[i - 1];
        return _CandidateCard(
          candidate: c,
          expanded: _expanded.contains(c.userId),
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
          onToggle: () => setState(() {
            if (_expanded.contains(c.userId)) {
              _expanded.remove(c.userId);
            } else {
              _expanded.add(c.userId);
            }
          }),
        );
      },
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final SuggestedCandidate candidate;
  final bool expanded;
  final VoidCallback onToggle;
  final String jobId;
  final String? jobTitle;
  const _CandidateCard({
    required this.candidate,
    required this.expanded,
    required this.onToggle,
    required this.jobId,
    this.jobTitle,
  });

  Color _scoreColor() {
    if (candidate.score >= 75) return AppColors.success;
    if (candidate.score >= 60) return AppColors.primary;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();
    final lastSeen = candidate.lastSeenAt;
    return InkWell(
      onTap: onToggle,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: candidate.rank <= 3
                ? AppColors.primary.withValues(alpha: 0.30)
                : context.cardBorder,
            width: candidate.rank <= 3 ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  url: candidate.avatar,
                  name: candidate.fullName,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  scoreColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    scoreColor.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              '#${candidate.rank}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              candidate.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (candidate.headline != null &&
                          candidate.headline!.isNotEmpty)
                        Text(
                          candidate.headline!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textSecondary),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (candidate.experienceYears != null) ...[
                            Text(
                              '${candidate.experienceYears}y',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.textTertiary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (lastSeen != null)
                            Text(
                              'Applied ${DateFormat('d MMM').format(lastSeen.toLocal())}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.textTertiary,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 11, color: scoreColor),
                      const SizedBox(width: 3),
                      Text(
                        '${candidate.score}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (candidate.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                candidate.summary,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (candidate.topSkills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in candidate.topSkills)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (expanded && candidate.strengths.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Bullets(
                label: 'Strengths',
                icon: Icons.thumb_up_alt_outlined,
                color: AppColors.success,
                items: candidate.strengths,
              ),
            ],
            if (expanded && candidate.concerns.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Bullets(
                label: 'Concerns',
                icon: Icons.warning_amber_outlined,
                color: AppColors.warning,
                items: candidate.concerns,
              ),
            ],
            if (candidate.strengths.isNotEmpty ||
                candidate.concerns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _OutreachSheet.show(
                      context,
                      jobId: jobId,
                      jobTitle: jobTitle,
                      candidate: candidate,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Draft outreach'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                    label: Text(
                      expanded ? 'Hide details' : 'Show details',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> items;
  const _Bullets({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final s in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet that fetches AI-drafted outreach messages for one
/// (job, candidate) pair and lets the hirer copy a variant. The actual
/// "send" path stays separate — most hirers will paste the chosen
/// variant into their existing chat workflow.
class _OutreachSheet extends StatefulWidget {
  final String jobId;
  final String? jobTitle;
  final SuggestedCandidate candidate;
  const _OutreachSheet({
    required this.jobId,
    required this.candidate,
    this.jobTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required SuggestedCandidate candidate,
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
      builder: (_) => _OutreachSheet(
        jobId: jobId,
        candidate: candidate,
        jobTitle: jobTitle,
      ),
    );
  }

  @override
  State<_OutreachSheet> createState() => _OutreachSheetState();
}

class _OutreachSheetState extends State<_OutreachSheet> {
  bool _loading = false;
  String? _error;
  List<({String label, String body})> _drafts = const [];

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
      final res = await ApplicantsService.instance.draftOutreach(
        jobId: widget.jobId,
        candidateUserId: widget.candidate.userId,
      );
      if (!mounted) return;
      if (!res.cached) {
        // ignore: discarded_futures
        context.read<AiQuotaProvider>().refresh();
      }
      setState(() {
        _drafts = res.drafts;
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppSnackbar.success(context, 'Copied to clipboard');
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Outreach drafts — ${widget.candidate.fullName}',
                      style: AppTextStyles.h4.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
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
            if (widget.jobTitle != null && widget.jobTitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'For "${widget.jobTitle}"',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _body(context),
              ),
            ),
            const SizedBox(height: 12),
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
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.urgent),
        ),
      );
    }
    if (_drafts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No drafts generated.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.textSecondary,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _drafts.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: context.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _drafts[i].label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _copy(_drafts[i].body),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _drafts[i].body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

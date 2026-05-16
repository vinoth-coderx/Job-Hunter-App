import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/applicant_model.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/applicants_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/applicants_provider.dart';
import '../widgets/app_avatar.dart';
import 'applicant_detail_screen.dart';
import 'candidate_suggestions_sheet.dart';

/// Applicants screen.
///   - When `jobId` arg is provided, lists applicants for that one job.
///   - When `null`, lists every applicant across the hirer's jobs.
class ApplicantsScreen extends StatefulWidget {
  final String? jobId;
  const ApplicantsScreen({super.key, this.jobId});

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen>
    with TapGuardMixin<ApplicantsScreen> {
  static const _statusFilters = [
    'all',
    'applied',
    'shortlisted',
    'interview',
    'offer',
    'hired',
    'rejected',
  ];

  /// applicationId -> AI ranking. Empty until the hirer hits "Rank with AI".
  /// Cleared whenever the filter changes (the new list might be a different
  /// applicant set, so the old ranks no longer apply 1:1).
  final Map<String, RankedApplicant> _ranked = {};
  bool _ranking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() {
    setState(_ranked.clear);
    final prov = context.read<ApplicantsProvider>();
    if (widget.jobId != null) {
      return prov.loadForJob(jobId: widget.jobId!);
    } else {
      return prov.loadAll();
    }
  }

  Future<void> _setFilter(String status) async {
    setState(_ranked.clear);
    final prov = context.read<ApplicantsProvider>();
    if (widget.jobId != null) {
      await prov.loadForJob(jobId: widget.jobId!, status: status);
    } else {
      await prov.loadAll(status: status);
    }
  }

  /// Trigger AI ranking for the currently scoped job. Disabled when
  /// viewing the all-applicants list because ranking is per-job.
  Future<void> _rankWithAi() async {
    final jobId = widget.jobId;
    if (jobId == null || _ranking) return;
    setState(() => _ranking = true);
    try {
      final ranked = await ApplicantsService.instance.rankForJob(jobId: jobId);
      if (!mounted) return;
      setState(() {
        _ranked
          ..clear()
          ..addEntries(ranked.map((r) => MapEntry(r.applicationId, r)));
      });
      // Quota snapshot lives on the response wrapper, not directly on
      // rankForJob — refresh the banner separately so the user sees the
      // post-call quota immediately.
      await context.read<AiQuotaProvider>().refresh();
      if (mounted) {
        AppSnackbar.success(
          context,
          ranked.isEmpty
              ? 'No applicants to rank yet.'
              : 'Ranked ${ranked.length} candidates.',
        );
      }
    } on AiQuotaExceededException catch (e) {
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(e.quota);
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Rank failed: $e');
    } finally {
      if (mounted) setState(() => _ranking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Consumer<ApplicantsProvider>(
          builder: (_, p, __) {
            final titleText = widget.jobId != null
                ? (p.scopedJobTitle ?? 'Applicants')
                : 'All applicants';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  '${p.items.length} ${p.items.length == 1 ? 'candidate' : 'candidates'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: context.textPrimary,
        actions: [
          if (widget.jobId != null) ...[
            IconButton(
              tooltip: 'Suggested candidates',
              onPressed: () => CandidateSuggestionsSheet.show(
                context,
                jobId: widget.jobId!,
                jobTitle:
                    context.read<ApplicantsProvider>().scopedJobTitle,
              ),
              icon: const Icon(Icons.person_search),
              color: AppColors.primary,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _ranking ? null : _rankWithAi,
                icon: _ranking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_ranking ? 'Ranking…' : 'Rank with AI'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _filterRow(),
          Expanded(
            child: Consumer<ApplicantsProvider>(
              builder: (_, prov, __) {
                if (prov.loading && prov.items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (prov.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Icon(Icons.people_outline,
                            size: 56, color: context.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No applicants yet',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: context.textSecondary),
                        ),
                      ],
                    ),
                  );
                }
                // When AI ranking has run, sort the list by aiScore desc so
                // the top picks bubble to the top. Unranked rows fall to the
                // bottom in their original order (rank null → infinity).
                final items = [...prov.items];
                if (_ranked.isNotEmpty) {
                  items.sort((a, b) {
                    final ra = _ranked[a.applicationId]?.rank ?? 1 << 20;
                    final rb = _ranked[b.applicationId]?.rank ?? 1 << 20;
                    return ra.compareTo(rb);
                  });
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ApplicantCard(
                      applicant: items[i],
                      ranking: _ranked[items[i].applicationId],
                      onTap: () => guard(
                        () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ApplicantDetailScreen(
                                applicationId: items[i].applicationId),
                          ));
                          // Re-fetch in case status changed in the detail view.
                          if (mounted) _refresh();
                        },
                        key: 'open-${items[i].applicationId}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return Consumer<ApplicantsProvider>(
      builder: (_, prov, __) => SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: _statusFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = _statusFilters[i];
            final selected = prov.statusFilter == s;
            return FilterChip(
              label: Text(_capitalize(s)),
              selected: selected,
              onSelected: (_) => _setFilter(s),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
            );
          },
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _ApplicantCard extends StatelessWidget {
  final Applicant applicant;
  final RankedApplicant? ranking;
  final VoidCallback onTap;
  const _ApplicantCard({
    required this.applicant,
    required this.onTap,
    this.ranking,
  });

  Color _matchColor(BuildContext context) {
    final s = applicant.matchScore ?? 0;
    if (s >= 75) return AppColors.success;
    if (s >= 50) return AppColors.warning;
    return context.textTertiary;
  }

  Color _aiScoreColor() {
    final s = ranking?.aiScore ?? 0;
    if (s >= 75) return AppColors.success;
    if (s >= 60) return AppColors.primary;
    if (s >= 40) return AppColors.warning;
    return AppColors.urgent;
  }

  Color _statusColor() {
    switch (applicant.status) {
      case 'shortlisted':
      case 'interview':
      case 'offer':
      case 'hired':
        return AppColors.success;
      case 'rejected':
        return AppColors.urgent;
      case 'withdrawn':
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = applicant.seeker;
    final r = ranking;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: r != null && r.rank <= 3
                ? AppColors.primary.withValues(alpha: 0.40)
                : context.cardBorder,
            width: r != null && r.rank <= 3 ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  url: s?.avatar,
                  name: s?.fullName,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (r != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _aiScoreColor().withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      _aiScoreColor().withValues(alpha: 0.30),
                                ),
                              ),
                              child: Text(
                                '#${r.rank}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: _aiScoreColor(),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              s?.fullName ?? 'Unknown applicant',
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
                      if (s?.headline != null && s!.headline!.isNotEmpty)
                        Text(
                          s.headline!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textSecondary),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor().withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              applicant.status.toUpperCase(),
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: _statusColor()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (applicant.appliedAt != null)
                            Text(
                              DateFormat('d MMM').format(
                                  applicant.appliedAt!.toLocal()),
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: context.textTertiary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (r != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _aiScoreColor().withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _aiScoreColor().withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 11, color: _aiScoreColor()),
                        const SizedBox(width: 3),
                        Text(
                          '${r.aiScore}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: _aiScoreColor(),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (applicant.matchScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _matchColor(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${applicant.matchScore!.round()}%',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: _matchColor(context)),
                    ),
                  ),
              ],
            ),
            if (r != null && r.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.summary,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

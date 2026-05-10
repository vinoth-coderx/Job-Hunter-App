import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/applicant_model.dart';
import '../../providers/applicants_provider.dart';
import '../widgets/app_avatar.dart';
import 'applicant_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() {
    final prov = context.read<ApplicantsProvider>();
    if (widget.jobId != null) {
      return prov.loadForJob(jobId: widget.jobId!);
    } else {
      return prov.loadAll();
    }
  }

  Future<void> _setFilter(String status) async {
    final prov = context.read<ApplicantsProvider>();
    if (widget.jobId != null) {
      await prov.loadForJob(jobId: widget.jobId!, status: status);
    } else {
      await prov.loadAll(status: status);
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
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: prov.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ApplicantCard(
                      applicant: prov.items[i],
                      onTap: () => guard(
                        () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ApplicantDetailScreen(
                                applicationId: prov.items[i].applicationId),
                          ));
                          // Re-fetch in case status changed in the detail view.
                          if (mounted) _refresh();
                        },
                        key: 'open-${prov.items[i].applicationId}',
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
  final VoidCallback onTap;
  const _ApplicantCard({required this.applicant, required this.onTap});

  Color _matchColor(BuildContext context) {
    final s = applicant.matchScore ?? 0;
    if (s >= 75) return AppColors.success;
    if (s >= 50) return AppColors.warning;
    return context.textTertiary;
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
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
                  Text(
                    s?.fullName ?? 'Unknown applicant',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary),
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
            if (applicant.matchScore != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ),
    );
  }
}

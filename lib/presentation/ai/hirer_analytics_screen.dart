import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/hirer_analytics_service.dart';

/// Hirer analytics dashboard (Phase 3).
///
/// Backed by GET /hirer/analytics — every number on this screen comes
/// from real aggregations over the hirer's native jobs and applications.
/// Empty states ship as honest "no data yet" cards rather than zeros.
class HirerAnalyticsScreen extends StatefulWidget {
  const HirerAnalyticsScreen({super.key});

  @override
  State<HirerAnalyticsScreen> createState() => _HirerAnalyticsScreenState();
}

class _HirerAnalyticsScreenState extends State<HirerAnalyticsScreen> {
  Future<HirerAnalytics>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = HirerAnalyticsService.instance.fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800)),
            Text('How your hiring is performing',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiary,
                  fontSize: 11.5,
                )),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: context.textPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<HirerAnalytics>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final a = snap.data!;
          if (a.totalJobs == 0) return _emptyState();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _topRow(a),
                const SizedBox(height: 16),
                _section('Funnel'),
                const SizedBox(height: 8),
                _funnelCard(a),
                const SizedBox(height: 16),
                if (a.daily30.isNotEmpty) ...[
                  _section('Last 30 days'),
                  const SizedBox(height: 8),
                  _timeseriesCard(a.daily30),
                  const SizedBox(height: 16),
                ],
                if (a.sourceBreakdown.isNotEmpty) ...[
                  _section('Application sources'),
                  const SizedBox(height: 8),
                  _sourceCard(a.sourceBreakdown, a.totalApplications),
                  const SizedBox(height: 16),
                ],
                if (a.topJobs.isNotEmpty) ...[
                  _section('Top jobs by applications'),
                  const SizedBox(height: 8),
                  ...a.topJobs.map(_topJobRow),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined,
                  size: 56, color: context.textTertiary),
              const SizedBox(height: 12),
              Text('No native job postings yet',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary)),
              const SizedBox(height: 4),
              Text(
                'Post your first native job and analytics will populate here as applications come in.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textTertiary),
              ),
            ],
          ),
        ),
      );

  Widget _section(String s) => Text(
        s,
        style: AppTextStyles.bodyMedium
            .copyWith(fontWeight: FontWeight.w700, color: context.textPrimary),
      );

  Widget _topRow(HirerAnalytics a) {
    return Row(
      children: [
        _kpiCard(
          label: 'Native jobs',
          value: a.totalJobs.toString(),
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _kpiCard(
          label: 'Applications',
          value: a.totalApplications.toString(),
          color: AppColors.info,
        ),
        const SizedBox(width: 8),
        _kpiCard(
          label: 'Time to hire',
          value: a.timeToHireDays == null ? '—' : '${a.timeToHireDays}d',
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required Color color,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value,
                  style: AppTextStyles.h3
                      .copyWith(color: context.textPrimary)),
            ],
          ),
        ),
      );

  Widget _funnelCard(HirerAnalytics a) {
    if (a.totalApplications == 0) {
      return _hint('No applications yet — funnel will appear here.');
    }
    final visible = a.funnel.where((f) => f.count > 0).toList();
    final maxCount = visible.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        children: visible
            .map((b) => _funnelRow(b, maxCount))
            .toList(growable: false),
      ),
    );
  }

  Widget _funnelRow(FunnelBucket b, int maxCount) {
    final color = switch (b.status) {
      'applied' => AppColors.info,
      'viewed' => AppColors.warning,
      'shortlisted' || 'interview' => AppColors.primary,
      'offer' || 'hired' => AppColors.success,
      'rejected' || 'withdrawn' => AppColors.urgent,
      _ => Colors.grey,
    };
    final width = maxCount == 0 ? 0.0 : b.count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(b.status,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textPrimary)),
              ),
              Text('${b.count}',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: width,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeseriesCard(List<DailyPoint> daily) {
    final maxCount = daily.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Applications received',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary)),
              Text('Peak: $maxCount',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: daily.map((p) {
                final h = maxCount == 0 ? 0.0 : (p.count / maxCount) * 100;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: h,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _shortDate(daily.first.date),
                style: AppTextStyles.labelSmall
                    .copyWith(color: context.textTertiary),
              ),
              const Spacer(),
              Text(
                _shortDate(daily.last.date),
                style: AppTextStyles.labelSmall
                    .copyWith(color: context.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceCard(List<SourceBucket> sources, int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        children: sources.map((s) {
          final pct = total == 0 ? 0 : ((s.count / total) * 100).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.source.replaceAll('_', ' '),
                      style: AppTextStyles.bodySmall),
                ),
                Text('${s.count} · $pct%',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _topJobRow(TopJob j) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(j.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text('${j.applicationsCount} apps',
                style: AppTextStyles.bodySmall),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${j.shortlistedCount} shortlisted',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.success)),
            ),
          ],
        ),
      );

  Widget _hint(String s) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(s,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary)),
      );

  String _shortDate(String iso) {
    try {
      return DateFormat('d MMM').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

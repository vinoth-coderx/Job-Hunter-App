import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../data/services/ai_service.dart';
import '../widgets/app_text.dart';
import 'widgets/ai_quota_banner.dart';

/// Per-user AI activity history. Lists the most recent provider calls
/// the user has made — tokens used, estimated USD cost, cache hits,
/// timestamps. Surfaces the same data the admin /ai-analytics page
/// shows globally, scoped to the calling user.
class AiUsageHistoryScreen extends StatefulWidget {
  const AiUsageHistoryScreen({super.key});

  @override
  State<AiUsageHistoryScreen> createState() => _AiUsageHistoryScreenState();
}

class _AiUsageHistoryScreenState extends State<AiUsageHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<({
    String feature,
    String provider,
    int totalTokens,
    double estimatedCostUsd,
    bool cacheHit,
    DateTime createdAt,
  })> _items = const [];

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
      final res = await AiService.instance.usageHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _items = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _featureLabel(String raw) {
    // Pretty-print common feature ids. Anything we don't know about
    // falls through verbatim — better than blanking unknown rows.
    switch (raw) {
      case 'chat':
        return 'Chat assistant';
      case 'chat:stream':
        return 'Chat assistant (streaming)';
      case 'cover_letter':
        return 'Cover letter';
      case 'ats_score':
        return 'ATS score';
      case 'job_insight':
        return 'Job insight';
      case 'profile_optimizer':
        return 'Profile coach';
      case 'skill_gap':
        return 'Skill gap';
      case 'for_you':
        return 'For-you feed';
      case 'field_suggest':
        return 'Field suggest';
      case 'resume_parse':
        return 'Resume parse';
      case 'resume_tldr':
        return 'Resume TL;DR';
      case 'applicant_rank':
        return 'Applicant ranking';
      case 'candidate_suggest':
        return 'Candidate suggestions';
      case 'recruiter_outreach':
        return 'Outreach drafter';
      case 'jd_generator':
        return 'JD generator';
      case 'jd_polish':
        return 'JD polish';
      case 'screening_questions':
        return 'Screening questions';
      case 'hirer_digest':
        return 'Weekly digest';
      default:
        if (raw.startsWith('resume_rewrite:')) return 'Resume rewrite';
        return raw;
    }
  }

  String _formatUsd(double v) {
    if (v <= 0) return 'free';
    if (v < 0.001) return '<\$0.001';
    if (v < 0.01) return '\$${v.toStringAsFixed(4)}';
    return '\$${v.toStringAsFixed(3)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const AppText.h4('My AI activity'),
        backgroundColor: context.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AiQuotaBanner(),
              const SizedBox(height: 12),
              if (_loading) ...[
                const SizedBox(height: 60),
                const Center(child: CircularProgressIndicator()),
              ] else if (_error != null) ...[
                const SizedBox(height: 60),
                Center(
                  child: AppText.body(
                    _error!,
                    color: AppColors.urgent,
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (_items.isEmpty) ...[
                const SizedBox(height: 60),
                Center(
                  child: AppText.caption(
                    'No AI activity in the last 90 days yet.',
                  ),
                ),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _items.length; i++) ...[
                        if (i > 0)
                          Divider(color: context.cardBorder, height: 1),
                        _UsageRow(
                          row: _items[i],
                          featureLabel: _featureLabel(_items[i].feature),
                          formattedCost: _formatUsd(_items[i].estimatedCostUsd),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final ({
    String feature,
    String provider,
    int totalTokens,
    double estimatedCostUsd,
    bool cacheHit,
    DateTime createdAt,
  }) row;
  final String featureLabel;
  final String formattedCost;
  const _UsageRow({
    required this.row,
    required this.featureLabel,
    required this.formattedCost,
  });

  Color _providerColor(String p) {
    switch (p) {
      case 'gemini':
        return AppColors.primary;
      case 'claude':
        return AppColors.warning;
      case 'groq':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d MMM, h:mm a').format(row.createdAt.toLocal());
    final providerColor = _providerColor(row.provider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: providerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText.body(
                        featureLabel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (row.cacheHit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AppText.labelSmall(
                          'CACHE',
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                AppText.caption(
                  '$time · ${row.provider} · ${row.totalTokens} tokens · $formattedCost',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

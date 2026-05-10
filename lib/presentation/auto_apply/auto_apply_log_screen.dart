import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/auto_apply_log_model.dart';
import '../../data/services/auto_apply_service.dart';

/// Auto-apply run history. One card per cron run, expandable to show
/// applied + skipped jobs.
class AutoApplyLogScreen extends StatefulWidget {
  const AutoApplyLogScreen({super.key});

  @override
  State<AutoApplyLogScreen> createState() => _AutoApplyLogScreenState();
}

class _AutoApplyLogScreenState extends State<AutoApplyLogScreen> {
  final AutoApplyService _service = AutoApplyService.instance;
  Future<List<AutoApplyLog>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _service.listLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Auto-Apply history'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<AutoApplyLog>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _err(snap.error.toString());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) return _empty();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _LogCard(log: list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.history, size: 56, color: context.textTertiary),
          const SizedBox(height: 12),
          Text('No runs yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'Auto-Apply runs will appear here after your first scheduled or manual run.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textTertiary),
          ),
        ],
      );

  Widget _err(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: AppColors.urgent),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _LogCard extends StatefulWidget {
  final AutoApplyLog log;
  const _LogCard({required this.log});
  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM, h:mm a');
    final l = widget.log;
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(df.format(l.runDate.toLocal()),
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'scanned ${l.jobsScanned} · matched ${l.jobsMatched} · applied ${l.jobsApplied} · skipped ${l.jobsSkipped}'
              '${l.triggeredManually ? " · manual" : ""}'
              '${l.awaitingApproval ? " · awaiting review" : ""}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary),
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            if (l.appliedJobs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Applied / staged',
                        style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary)),
                    const SizedBox(height: 6),
                    ...l.appliedJobs.map((e) => _appliedRow(context, e)),
                  ],
                ),
              ),
            if (l.skippedJobs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Skipped',
                        style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary)),
                    const SizedBox(height: 6),
                    ...l.skippedJobs.take(20).map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '· ${s.reason}${s.matchScore != null ? " (${s.matchScore}%)" : ""}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: context.textSecondary),
                            ),
                          ),
                        ),
                    if (l.skippedJobs.length > 20)
                      Text('… and ${l.skippedJobs.length - 20} more',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textTertiary)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _appliedRow(BuildContext context, AutoApplyLogEntry e) {
    Color statusColor;
    if (e.status == 'applied') {
      statusColor = AppColors.success;
    } else if (e.status == 'pending_review') {
      statusColor = AppColors.warning;
    } else if (e.status.startsWith('failed')) {
      statusColor = AppColors.urgent;
    } else {
      statusColor = context.textSecondary;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${e.jobTitle} · ${e.companyName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ),
          Text('${e.matchScore}%',
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textTertiary)),
        ],
      ),
    );
  }
}

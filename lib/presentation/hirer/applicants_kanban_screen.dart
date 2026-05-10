import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/applicant_model.dart';
import '../../data/services/applicants_service.dart';
import 'applicant_detail_screen.dart';

/// Drag-and-drop Kanban for a single job. Columns map 1:1 to the
/// AppliedJob.status enum the backend already supports. Dragging a card
/// fires PUT /hirer/applicants/:id/status — terminal columns
/// (hired/rejected/withdrawn) are accepted as drop targets but not as
/// drag sources, since the backend rejects status edits from terminal
/// states.
class ApplicantsKanbanScreen extends StatefulWidget {
  final String jobId;
  const ApplicantsKanbanScreen({super.key, required this.jobId});

  @override
  State<ApplicantsKanbanScreen> createState() =>
      _ApplicantsKanbanScreenState();
}

class _ApplicantsKanbanScreenState extends State<ApplicantsKanbanScreen> {
  final _service = ApplicantsService.instance;

  // Column order matches the doc's funnel.
  static const _columnOrder = [
    'applied',
    'shortlisted',
    'interview',
    'offer',
    'hired',
    'rejected',
  ];
  static const _terminalCols = {'hired', 'rejected', 'withdrawn'};

  Map<String, List<Applicant>> _columns = {
    for (final c in _columnOrder) c: const [],
  };
  String? _jobTitle;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.kanbanForJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        // Preserve column order even if backend returns extra/fewer keys.
        _columns = {
          for (final c in _columnOrder) c: r.columns[c] ?? const <Applicant>[],
        };
        _jobTitle = r.jobTitle;
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

  Future<void> _moveTo({
    required Applicant applicant,
    required String fromStatus,
    required String toStatus,
  }) async {
    if (fromStatus == toStatus) return;
    if (_terminalCols.contains(fromStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Application is in terminal state ($fromStatus)'),
        ),
      );
      return;
    }

    // Optimistic — move locally, roll back on error.
    setState(() {
      _columns[fromStatus] = _columns[fromStatus]!
          .where((a) => a.applicationId != applicant.applicationId)
          .toList();
      _columns[toStatus] = [
        applicant,
        ...?_columns[toStatus],
      ];
    });

    try {
      await _service.updateStatus(
        id: applicant.applicationId,
        status: toStatus,
      );
    } catch (e) {
      if (!mounted) return;
      // Roll back.
      setState(() {
        _columns[toStatus] = _columns[toStatus]!
            .where((a) => a.applicationId != applicant.applicationId)
            .toList();
        _columns[fromStatus] = [
          applicant,
          ...?_columns[fromStatus],
        ];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Move failed: $e')));
    }
  }

  Color _columnColor(String status) {
    switch (status) {
      case 'applied':
        return AppColors.info;
      case 'shortlisted':
      case 'interview':
        return AppColors.primary;
      case 'offer':
      case 'hired':
        return AppColors.success;
      case 'rejected':
      case 'withdrawn':
        return AppColors.urgent;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(_jobTitle ?? 'Pipeline'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _err()
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  children: _columnOrder
                      .map((status) => _column(status, _columns[status] ?? []))
                      .toList(),
                ),
    );
  }

  Widget _err() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Could not load',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _column(String status, List<Applicant> applicants) {
    final color = _columnColor(status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 280,
        child: DragTarget<({Applicant applicant, String fromStatus})>(
          onWillAcceptWithDetails: (details) =>
              details.data.fromStatus != status,
          onAcceptWithDetails: (details) => _moveTo(
            applicant: details.data.applicant,
            fromStatus: details.data.fromStatus,
            toStatus: status,
          ),
          builder: (context, candidate, _) {
            final isHovering = candidate.isNotEmpty;
            return Container(
              decoration: BoxDecoration(
                color: isHovering
                    ? color.withValues(alpha: 0.12)
                    : context.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isHovering
                      ? color.withValues(alpha: 0.5)
                      : context.cardBorder,
                  width: isHovering ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text('${applicants.length}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: context.textSecondary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: applicants.isEmpty
                        ? Center(
                            child: Text(
                              'Drop here',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.textTertiary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                            itemCount: applicants.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _draggableCard(applicants[i], status),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _draggableCard(Applicant a, String status) {
    final isTerminal = _terminalCols.contains(status);
    final card = _ApplicantCard(applicant: a, locked: isTerminal);

    if (isTerminal) {
      // Terminal cards aren't draggable; tap still opens detail.
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(a),
        child: card,
      );
    }

    return LongPressDraggable<({Applicant applicant, String fromStatus})>(
      data: (applicant: a, fromStatus: status),
      hapticFeedbackOnStart: true,
      feedback: SizedBox(
        width: 264,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: _ApplicantCard(applicant: a, locked: false),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(a),
        child: card,
      ),
    );
  }

  Future<void> _openDetail(Applicant a) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ApplicantDetailScreen(applicationId: a.applicationId),
    ));
    if (mounted) _refresh();
  }
}

class _ApplicantCard extends StatelessWidget {
  final Applicant applicant;
  final bool locked;
  const _ApplicantCard({required this.applicant, required this.locked});

  @override
  Widget build(BuildContext context) {
    final s = applicant.seeker;
    final score = applicant.matchScore;
    Color matchColor;
    if (score == null) {
      matchColor = context.textTertiary;
    } else if (score >= 75) {
      matchColor = AppColors.success;
    } else if (score >= 50) {
      matchColor = AppColors.warning;
    } else {
      matchColor = context.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              s == null || s.fullName.isEmpty
                  ? '?'
                  : s.fullName.substring(0, 1).toUpperCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.fullName.isNotEmpty == true
                      ? s!.fullName
                      : (s?.email ?? 'Unknown'),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (s?.headline != null && s!.headline!.isNotEmpty)
                  Text(
                    s.headline!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (score != null)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: matchColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${score.round()}%',
                  style: AppTextStyles.labelSmall.copyWith(color: matchColor)),
            ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.lock_outline, size: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

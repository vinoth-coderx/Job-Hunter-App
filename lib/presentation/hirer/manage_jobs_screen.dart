import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/hirer_job_model.dart';
import '../../data/services/hirer_job_service.dart';
import '../../providers/hirer_jobs_provider.dart';
import 'candidate_suggestions_sheet.dart';

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _tabStatuses = ['active', 'draft', 'closed'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabStatuses.length, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _loadFor(_tabStatuses[_tabs.index]);
    });
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadFor(_tabStatuses[_tabs.index]));
  }

  void _loadFor(String status) =>
      context.read<HirerJobsProvider>().load(status: status);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage jobs'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Drafts'),
            Tab(text: 'Closed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _tabStatuses
            .map((s) => _JobsList(status: s))
            .toList(growable: false),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.hirerPostJob).then((_) {
          // Refresh whichever tab is currently visible.
          _loadFor(_tabStatuses[_tabs.index]);
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _JobsList extends StatelessWidget {
  final String status;
  const _JobsList({required this.status});

  @override
  Widget build(BuildContext context) {
    return Consumer<HirerJobsProvider>(
      builder: (context, prov, _) {
        // Filter locally to the tab — provider holds whatever was last loaded.
        final list = prov.jobs.where((j) => j.status == status).toList();
        if (prov.loading && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (list.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => prov.load(status: status),
            child: ListView(
              children: [
                const SizedBox(height: 100),
                Icon(Icons.inbox_outlined,
                    size: 56,
                    color: context.textTertiary),
                const SizedBox(height: 12),
                Text(
                  'No $status jobs',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => prov.load(status: status),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _JobCard(job: list[i]),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatefulWidget {
  final HirerJob job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> with TapGuardMixin<_JobCard> {
  HirerJob get job => widget.job;

  Color _statusColor(BuildContext context) {
    switch (job.status) {
      case 'active':
        return AppColors.success;
      case 'paused':
        return AppColors.warning;
      case 'draft':
        return AppColors.info;
      case 'closed':
      case 'expired':
        return context.textTertiary;
    }
    return context.textSecondary;
  }

  /// Opens the appeal sheet for the current job. The backend rejects a
  /// duplicate while one is pending, so we re-load the list afterwards
  /// to flip the moderation pill to its new state.
  Future<void> _showAppealSheet(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AppealReasonSheet(),
    );
    if (reason == null || reason.isEmpty) return;
    if (!context.mounted) return;
    try {
      await HirerJobService.instance.appealModeration(
        jobId: job.id,
        reason: reason,
      );
      if (!context.mounted) return;
      AppSnackbar.success(
        context,
        'Appeal submitted. Admin will review shortly.',
      );
      await context.read<HirerJobsProvider>().load(status: job.status);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.error(context, 'Could not submit appeal: $e');
    }
  }

  void _handleAction(BuildContext context, _JobMenuAction action) {
    // Navigation actions debounce by time (no async work to wait on);
    // status mutations use the in-flight guard so the popup can't fire
    // duplicate /jobs PATCHes if the user re-opens the menu mid-call.
    switch (action) {
      case _JobMenuAction.viewApplicants:
        debounceTap(
          () => Navigator.pushNamed(
            context,
            AppRoutes.hirerApplicants,
            arguments: job.id,
          ),
          key: 'nav',
        );
        return;
      case _JobMenuAction.kanban:
        debounceTap(
          () => Navigator.pushNamed(
            context,
            AppRoutes.hirerKanban,
            arguments: job.id,
          ),
          key: 'nav',
        );
        return;
      case _JobMenuAction.publish:
      case _JobMenuAction.pause:
      case _JobMenuAction.resume:
      case _JobMenuAction.close:
      case _JobMenuAction.deleteDraft:
        guard(() => _runMutation(context, action), key: 'mutate');
        return;
      case _JobMenuAction.appealModeration:
        guard(() => _showAppealSheet(context), key: 'appeal');
        return;
      case _JobMenuAction.suggestCandidates:
        debounceTap(
          () => CandidateSuggestionsSheet.show(
            context,
            jobId: job.id,
            jobTitle: job.title,
          ),
          key: 'nav',
        );
        return;
    }
  }

  Future<void> _runMutation(
      BuildContext context, _JobMenuAction action) async {
    final prov = context.read<HirerJobsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case _JobMenuAction.publish:
        if (await prov.updateStatus(job.id, 'active')) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Job published')));
        }
        break;
      case _JobMenuAction.pause:
        if (await prov.updateStatus(job.id, 'paused')) {
          messenger.showSnackBar(const SnackBar(content: Text('Job paused')));
        }
        break;
      case _JobMenuAction.resume:
        if (await prov.updateStatus(job.id, 'active')) {
          messenger.showSnackBar(const SnackBar(content: Text('Job resumed')));
        }
        break;
      case _JobMenuAction.close:
        final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Close this job?'),
                content: const Text(
                    'Closed jobs are read-only and cannot be reopened.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close job')),
                ],
              ),
            ) ??
            false;
        if (!ok) return;
        if (await prov.updateStatus(job.id, 'closed')) {
          messenger.showSnackBar(const SnackBar(content: Text('Job closed')));
        }
        break;
      case _JobMenuAction.deleteDraft:
        if (await prov.deleteDraft(job.id)) {
          messenger
              .showSnackBar(const SnackBar(content: Text('Draft deleted')));
        }
        break;
      case _JobMenuAction.viewApplicants:
      case _JobMenuAction.kanban:
      case _JobMenuAction.appealModeration:
      case _JobMenuAction.suggestCandidates:
        // Handled in _handleAction directly.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final published = job.publishedAt;
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job.status.toUpperCase(),
                    style: AppTextStyles.labelSmall
                        .copyWith(color: _statusColor(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                job.location,
                job.jobType,
                job.remoteType,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                    icon: Icons.visibility_outlined,
                    value: job.viewsCount.toString(),
                    label: 'views'),
                const SizedBox(width: 16),
                _Stat(
                    icon: Icons.people_outline,
                    value: job.applicationsCount.toString(),
                    label: 'apps'),
                const SizedBox(width: 16),
                _Stat(
                    icon: Icons.check_circle_outline,
                    value: job.shortlistedCount.toString(),
                    label: 'shortlisted'),
                const Spacer(),
                if (published != null)
                  Text(
                    df.format(published.toLocal()),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textTertiary),
                  ),
              ],
            ),
            if (job.moderationStatus == 'rejected') ...[
              const SizedBox(height: 10),
              _AppealRejectedRow(
                onAppeal: () => _showAppealSheet(context),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (job.status != 'closed' && job.status != 'expired')
                  TextButton.icon(
                    onPressed: () => _handleAction(
                        context, _JobMenuAction.viewApplicants),
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('Applicants'),
                  ),
                const Spacer(),
                PopupMenuButton<_JobMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (a) => _handleAction(context, a),
                  itemBuilder: (_) => [
                    if (job.status == 'draft')
                      const PopupMenuItem(
                        value: _JobMenuAction.publish,
                        child: ListTile(
                          leading: Icon(Icons.send),
                          title: Text('Publish'),
                        ),
                      ),
                    if (job.status == 'active')
                      const PopupMenuItem(
                        value: _JobMenuAction.pause,
                        child: ListTile(
                          leading: Icon(Icons.pause_circle_outline),
                          title: Text('Pause'),
                        ),
                      ),
                    if (job.status == 'paused')
                      const PopupMenuItem(
                        value: _JobMenuAction.resume,
                        child: ListTile(
                          leading: Icon(Icons.play_circle_outline),
                          title: Text('Resume'),
                        ),
                      ),
                    if (job.status != 'closed' && job.status != 'expired')
                      const PopupMenuItem(
                        value: _JobMenuAction.close,
                        child: ListTile(
                          leading: Icon(Icons.cancel_outlined),
                          title: Text('Close job'),
                        ),
                      ),
                    if (job.status == 'draft')
                      const PopupMenuItem(
                        value: _JobMenuAction.deleteDraft,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete draft'),
                        ),
                      ),
                    if (job.status == 'active' || job.status == 'paused')
                      const PopupMenuItem(
                        value: _JobMenuAction.kanban,
                        child: ListTile(
                          leading: Icon(Icons.view_kanban_outlined),
                          title: Text('Pipeline'),
                        ),
                      ),
                    if (job.status == 'active' || job.status == 'paused')
                      const PopupMenuItem(
                        value: _JobMenuAction.suggestCandidates,
                        child: ListTile(
                          leading: Icon(Icons.person_search),
                          title: Text('AI candidate suggestions'),
                        ),
                      ),
                    if (job.moderationStatus == 'rejected')
                      const PopupMenuItem(
                        value: _JobMenuAction.appealModeration,
                        child: ListTile(
                          leading: Icon(Icons.gavel_outlined),
                          title: Text('Appeal moderation'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat(
      {required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: context.textTertiary),
          const SizedBox(width: 4),
          Text('$value $label',
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary)),
        ],
      );
}

enum _JobMenuAction {
  publish,
  pause,
  resume,
  close,
  deleteDraft,
  viewApplicants,
  kanban,
  appealModeration,
  suggestCandidates,
}

/// Inline banner shown on rejected jobs in the manage list. The "Appeal"
/// button opens the reason sheet — see [_AppealReasonSheet].
class _AppealRejectedRow extends StatelessWidget {
  final VoidCallback onAppeal;
  const _AppealRejectedRow({required this.onAppeal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.urgent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.gpp_bad_outlined,
              size: 16, color: AppColors.urgent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI moderation rejected this listing.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.urgent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onAppeal,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.urgent,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Appeal'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that collects the hirer's appeal reason. Returns the
/// trimmed reason string when submitted, or null when dismissed.
/// Backend requires 20+ chars; we enforce it client-side too so a
/// short note never burns a network round-trip.
class _AppealReasonSheet extends StatefulWidget {
  const _AppealReasonSheet();

  @override
  State<_AppealReasonSheet> createState() => _AppealReasonSheetState();
}

class _AppealReasonSheetState extends State<_AppealReasonSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.length < 20) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.cardBorder,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          Text(
            'Appeal moderation decision',
            style: AppTextStyles.h4.copyWith(color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell admin why this job was wrongly flagged. Be specific — '
            'mention the bits the AI got wrong (max 2000 chars).',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 6,
            minLines: 4,
            maxLength: 2000,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'e.g. The AI flagged my legitimate referral bonus as MLM. '
                  'Please re-review.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (_, value, __) => FilledButton(
                  onPressed:
                      value.text.trim().length >= 20 ? _submit : null,
                  child: const Text('Submit appeal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

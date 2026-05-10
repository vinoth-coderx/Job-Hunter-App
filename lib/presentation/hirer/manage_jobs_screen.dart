import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/hirer_job_model.dart';
import '../../providers/hirer_jobs_provider.dart';

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

class _JobCard extends StatelessWidget {
  final HirerJob job;
  const _JobCard({required this.job});

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

  Future<void> _handleAction(BuildContext context, _JobMenuAction action) async {
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
        Navigator.pushNamed(
          context,
          AppRoutes.hirerApplicants,
          arguments: job.id,
        );
        break;
      case _JobMenuAction.kanban:
        Navigator.pushNamed(
          context,
          AppRoutes.hirerKanban,
          arguments: job.id,
        );
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
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/home_section.dart';
import '../widgets/job_card.dart';
import '../widgets/scroll_to_top_fab.dart';

/// refresh.
class JobListScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Job> Function(JobProvider) selector;

  const JobListScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.selector,
  });

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final isGuest = context.watch<AuthProvider>().isGuest;
    final jobs = widget.selector(jobProvider);
    final loading = jobProvider.isLoading;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: ScrollToTopFab(
        controller: _scrollCtrl,
        showAfterPixels: 600,
        additionalCondition: () => jobs.length > 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => jobProvider.loadJobs(asGuest: isGuest),
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: context.gradientTop,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 64,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: context.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: AppTextStyles.h4,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle != null)
                                Text(
                                  widget.subtitle!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: context.textTertiary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${jobs.length}',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (loading && jobs.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverList.separated(
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) => const JobCardSkeleton(),
                    ),
                  )
                else if (jobs.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final job = jobs[i];
                        final applied = jobProvider.hasApplied(job.id);
                        final saved = jobProvider.isJobSaved(job.id);
                        return AnimatedListItem(
                          key: ValueKey(job.id),
                          child: JobCard(
                            job: job,
                            statusBadge: applied ? 'Applied' : null,
                            statusColor: applied ? AppColors.success : null,
                            statusBgColor:
                                applied ? context.successBg : null,
                            isSaved: saved,
                            onSave: () => context
                                .read<JobProvider>()
                                .toggleSaveJob(job.id),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.jobDetail,
                              arguments: job,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.work_history_outlined,
              size: 56,
              color: context.textTertiary,
            ),
            const SizedBox(height: 16),
            Text('Nothing here yet', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Pull down to refresh, or check back in a bit.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

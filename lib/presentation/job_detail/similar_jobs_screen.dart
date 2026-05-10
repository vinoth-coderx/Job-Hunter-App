import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../providers/job_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/job_card.dart';
import '../widgets/scroll_to_top_fab.dart';
import 'job_detail_screen.dart';

/// Full-screen list of jobs similar to a given job. Pulls from the
/// already-loaded match feed in JobProvider — filters to same category
/// and excludes the current job. No mocked data: if the loaded feed
/// doesn't have more matches, we surface a "load more" prompt that
/// pulls the next page of the real backend feed.
class SimilarJobsScreen extends StatefulWidget {
  final Job currentJob;
  const SimilarJobsScreen({super.key, required this.currentJob});

  @override
  State<SimilarJobsScreen> createState() => _SimilarJobsScreenState();
}

class _SimilarJobsScreenState extends State<SimilarJobsScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels < pos.maxScrollExtent - 320) return;
    context.read<JobProvider>().loadMoreJobs();
  }

  List<Job> _similarFrom(JobProvider provider) {
    return provider.jobs
        .where((j) =>
            j.id != widget.currentJob.id &&
            j.category == widget.currentJob.category)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    final jobs = _similarFrom(provider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: context.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Similar jobs', style: AppTextStyles.h4),
            Text(
              widget.currentJob.category,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
      body: jobs.isEmpty && provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : jobs.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () async {
                    await context.read<JobProvider>().loadJobs();
                  },
                  color: AppColors.primary,
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: jobs.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i == jobs.length) {
                        return _Footer(
                          isLoadingMore: provider.isLoadingMore,
                          hasMore: provider.hasMore,
                          jobsShown: jobs.length,
                        );
                      }
                      final job = jobs[i];
                      final applied =
                          context.read<JobProvider>().hasApplied(job.id);
                      return AnimatedListItem(
                        key: ValueKey(job.id),
                        child: JobCard(
                          job: job,
                          statusBadge: applied ? 'Applied' : null,
                          statusColor: applied ? AppColors.success : null,
                          statusBgColor: applied ? context.successBg : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(job: job),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: ScrollToTopFab(
        controller: _scrollCtrl,
        showAfterPixels: 600,
        additionalCondition: () => jobs.length > 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off_outlined,
                size: 64, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No similar jobs found',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find more ${widget.currentJob.category} roles in the loaded feed yet. Pull to refresh or scroll to load more.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;
  final int jobsShown;
  const _Footer({
    required this.isLoadingMore,
    required this.hasMore,
    required this.jobsShown,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            jobsShown == 0
                ? 'Nothing more to show right now'
                : "You've seen all similar jobs",
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textTertiary),
          ),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

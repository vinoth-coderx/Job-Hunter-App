import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../providers/job_provider.dart';
import '../widgets/job_card.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  Future<List<Job>>? _future;
  String _filter = 'all'; // 'all' | 'native' | 'external'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Sync the saved-id set in the background so the bookmark icons on
      // other screens stay correct when the user comes back.
      context.read<JobProvider>().syncSavedJobIds();
      _refresh();
    });
  }

  void _refresh() {
    setState(() {
      _future = context.read<JobProvider>().fetchSavedJobs();
    });
  }

  List<Job> _applyFilter(List<Job> jobs) {
    switch (_filter) {
      case 'native':
        return jobs.where((j) => j.isNative).toList();
      case 'external':
        return jobs.where((j) => !j.isNative).toList();
      default:
        return jobs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved jobs',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800)),
            Text(
              'Bookmarked openings to revisit',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _filterRow(),
          Expanded(
            child: FutureBuilder<List<Job>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _errorState(snap.error.toString());
                }
                final all = snap.data ?? [];
                final filtered = _applyFilter(all);
                if (filtered.isEmpty) return _emptyState();

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => JobCard(
                      job: filtered[i],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.jobDetail,
                        arguments: filtered[i],
                      ).then((_) => _refresh()),
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

  Widget _filterRow() => SizedBox(
        height: 48,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: [
            for (final f in const [
              ('all', 'All'),
              ('native', 'Native (Quick Apply)'),
              ('external', 'External'),
            ]) ...[
              FilterChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) => setState(() => _filter = f.$1),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );

  Widget _emptyState() => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.bookmark_border,
              size: 56, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(
            'No saved jobs yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the bookmark icon on any job to save it for later.',
            textAlign: TextAlign.center,
            style:
                AppTextStyles.bodySmall.copyWith(color: context.textTertiary),
          ),
        ],
      );

  Widget _errorState(String msg) => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
}

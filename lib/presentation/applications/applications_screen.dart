import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/application_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/job_model.dart';
import '../../data/services/chat_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/job_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/scroll_to_top_fab.dart';

/// Status grouping shown in the chip row. We collapse the seven backend
/// states into five user-meaningful buckets so the row stays scannable
/// on a phone screen — "viewed" is hidden behind "active" because the
/// seeker doesn't act differently on it, and "withdrawn" hides under
/// closed for the same reason.
enum _StatusBucket { all, active, interview, offered, closed }

extension on _StatusBucket {
  String get label {
    switch (this) {
      case _StatusBucket.all:
        return 'All';
      case _StatusBucket.active:
        return 'Active';
      case _StatusBucket.interview:
        return 'Interview';
      case _StatusBucket.offered:
        return 'Offered';
      case _StatusBucket.closed:
        return 'Closed';
    }
  }

  bool matches(ApplicationStatus s) {
    switch (this) {
      case _StatusBucket.all:
        return true;
      case _StatusBucket.active:
        return s == ApplicationStatus.applied ||
            s == ApplicationStatus.viewed ||
            s == ApplicationStatus.shortlisted;
      case _StatusBucket.interview:
        return s == ApplicationStatus.interview;
      case _StatusBucket.offered:
        return s == ApplicationStatus.offered;
      case _StatusBucket.closed:
        return s == ApplicationStatus.rejected ||
            s == ApplicationStatus.withdrawn;
    }
  }
}

enum _DateRange { any, last7, last30, last90 }

extension on _DateRange {
  String get label {
    switch (this) {
      case _DateRange.any:
        return 'Any time';
      case _DateRange.last7:
        return 'Last 7 days';
      case _DateRange.last30:
        return 'Last 30 days';
      case _DateRange.last90:
        return 'Last 90 days';
    }
  }

  bool matches(DateTime appliedAt) {
    final now = DateTime.now();
    switch (this) {
      case _DateRange.any:
        return true;
      case _DateRange.last7:
        return now.difference(appliedAt).inDays <= 7;
      case _DateRange.last30:
        return now.difference(appliedAt).inDays <= 30;
      case _DateRange.last90:
        return now.difference(appliedAt).inDays <= 90;
    }
  }
}

enum _JobTypeFilter { any, fullTime, partTime, contract, remote }

extension on _JobTypeFilter {
  String get label {
    switch (this) {
      case _JobTypeFilter.any:
        return 'Any type';
      case _JobTypeFilter.fullTime:
        return 'Full-time';
      case _JobTypeFilter.partTime:
        return 'Part-time';
      case _JobTypeFilter.contract:
        return 'Contract';
      case _JobTypeFilter.remote:
        return 'Remote';
    }
  }

  bool matches(JobApplication app) {
    final t = app.job.employmentType.toLowerCase();
    switch (this) {
      case _JobTypeFilter.any:
        return true;
      case _JobTypeFilter.fullTime:
        return t.contains('full');
      case _JobTypeFilter.partTime:
        return t.contains('part');
      case _JobTypeFilter.contract:
        return t.contains('contract') || t.contains('freelance');
      case _JobTypeFilter.remote:
        return app.job.isRemote;
    }
  }
}

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  _StatusBucket _statusBucket = _StatusBucket.all;
  _DateRange _dateRange = _DateRange.last90;
  _JobTypeFilter _jobType = _JobTypeFilter.any;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().loadJobs();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() {});
    });
  }

  List<JobApplication> _filterApplications(List<JobApplication> apps) {
    final q = _searchController.text.trim().toLowerCase();
    return apps.where((a) {
      if (!_statusBucket.matches(a.status)) return false;
      if (!_dateRange.matches(a.appliedAt)) return false;
      if (!_jobType.matches(a)) return false;
      if (q.isEmpty) return true;
      // Multi-field text match — query has to land somewhere meaningful
      // (title, company, skills, description, responsibilities or
      // category) so a search for "react" also surfaces a job whose
      // title is "Frontend Engineer" but whose skills include "react".
      // Tokens are AND'd: every whitespace-separated word must hit at
      // least one field, mirroring the AI search ranking on the
      // catalog side.
      final haystack = [
        a.job.title,
        a.job.company,
        a.job.description,
        a.job.category,
        ...a.job.skills,
        ...a.job.responsibilities,
      ].join(' ').toLowerCase();
      final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
      return tokens.every(haystack.contains);
    }).toList();
  }

  Map<_StatusBucket, int> _bucketCounts(List<JobApplication> apps) {
    final m = {for (final b in _StatusBucket.values) b: 0};
    for (final a in apps) {
      for (final b in _StatusBucket.values) {
        if (b.matches(a.status)) m[b] = (m[b] ?? 0) + 1;
      }
    }
    return m;
  }

  Future<void> _openMoreFilters() async {
    final result = await showModalBottomSheet<_MoreFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreFiltersSheet(
        initialDate: _dateRange,
        initialJobType: _jobType,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _dateRange = result.date;
        _jobType = result.jobType;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobProvider>();
    // The provider's `applications` list carries every record so the home
    // feed can dedupe "Already Applied" badges across native + external.
    // This tab only tracks in-app applies though — external-redirect
    // applies (LinkedIn / company site) have no status workflow on our
    // end, so they'd just sit at "Applied" forever and clutter the
    // tracker. Filter them out at the view layer.
    final allApps = provider.applications
        .where((a) => a.applyType != ApplyType.externalManual)
        .toList(growable: false);
    final counts = _bucketCounts(allApps);
    final filtered = _filterApplications(allApps);

    final secondaryFilterActive =
        _dateRange != _DateRange.last90 || _jobType != _JobTypeFilter.any;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: const [0.0, 0.32],
          ),
        ),
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
              toolbarHeight: 76,
              titleSpacing: 0,
              title: const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: _Header(),
              ),
            ),
            if (allApps.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: _HuntOverviewCard(apps: allApps),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: CustomSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hint: 'Search company or title…',
                  showFilter: false,
                  showMic: false,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatusChipsRow(
                selected: _statusBucket,
                counts: counts,
                onSelect: (b) => setState(() => _statusBucket = b),
                onMoreFilters: _openMoreFilters,
                moreActive: secondaryFilterActive,
              ),
            ),
            if (secondaryFilterActive)
              SliverToBoxAdapter(
                child: _ActiveSecondaryFilters(
                  date: _dateRange,
                  jobType: _jobType,
                  onClearDate: () =>
                      setState(() => _dateRange = _DateRange.last90),
                  onClearJobType: () =>
                      setState(() => _jobType = _JobTypeFilter.any),
                ),
              ),
            if (allApps.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _NoMatchState(
                  onReset: () => setState(() {
                    _statusBucket = _StatusBucket.all;
                    _dateRange = _DateRange.last90;
                    _jobType = _JobTypeFilter.any;
                    _searchController.clear();
                  }),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final app = filtered[i];
                    final isFirst = i == 0;
                    final isLast = i == filtered.length - 1;
                    return AnimatedListItem(
                      key: ValueKey(app.id),
                      child: _TimelineRow(
                        app: app,
                        isFirst: isFirst,
                        isLast: isLast,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: ScrollToTopFab(
        controller: _scrollCtrl,
        showAfterPixels: 600,
        additionalCondition: () =>
            context.read<JobProvider>().applications.length > 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ─────────────────────────── Header ───────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 42,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Applications',
                style: AppTextStyles.h2.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track every step of your hunt',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Hunt overview card ───────────────────────

class _HuntOverviewCard extends StatelessWidget {
  final List<JobApplication> apps;
  const _HuntOverviewCard({required this.apps});

  @override
  Widget build(BuildContext context) {
    final active = apps
        .where((a) => _StatusBucket.active.matches(a.status))
        .length;
    final interviewing = apps
        .where((a) => a.status == ApplicationStatus.interview)
        .length;
    final offered =
        apps.where((a) => a.status == ApplicationStatus.offered).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hunt overview',
                style: AppTextStyles.label.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                'Last 90 days',
                style: AppTextStyles.labelSmall.copyWith(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${apps.length}',
                style: AppTextStyles.h1.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  apps.length == 1 ? 'application' : 'applications',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Active',
                  value: '$active',
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: context.divider.withValues(alpha: 0.6),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Interview',
                  value: '$interviewing',
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: context.divider.withValues(alpha: 0.6),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Offers',
                  value: '$offered',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: context.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────── Status chips ──────────────────────────

class _StatusChipsRow extends StatelessWidget {
  final _StatusBucket selected;
  final Map<_StatusBucket, int> counts;
  final ValueChanged<_StatusBucket> onSelect;
  final VoidCallback onMoreFilters;
  final bool moreActive;

  const _StatusChipsRow({
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onMoreFilters,
    required this.moreActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        scrollDirection: Axis.horizontal,
        children: [
          for (final b in _StatusBucket.values) ...[
            _StatusChip(
              label: b.label,
              count: counts[b] ?? 0,
              selected: selected == b,
              onTap: () => onSelect(b),
            ),
            const SizedBox(width: 8),
          ],
          _MoreFiltersChip(active: moreActive, onTap: onMoreFilters),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primary : context.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : context.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : context.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.label.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : context.surfaceVariant,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreFiltersChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _MoreFiltersChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : context.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : context.surface,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : context.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: AppTextStyles.label.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
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

class _ActiveSecondaryFilters extends StatelessWidget {
  final _DateRange date;
  final _JobTypeFilter jobType;
  final VoidCallback onClearDate;
  final VoidCallback onClearJobType;
  const _ActiveSecondaryFilters({
    required this.date,
    required this.jobType,
    required this.onClearDate,
    required this.onClearJobType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (date != _DateRange.last90)
            _RemovableChip(label: date.label, onRemove: onClearDate),
          if (jobType != _JobTypeFilter.any)
            _RemovableChip(label: jobType.label, onRemove: onClearJobType),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 4),
          InkResponse(
            onTap: onRemove,
            radius: 16,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────── More-filters bottom sheet ──────────────────────

class _MoreFilters {
  final _DateRange date;
  final _JobTypeFilter jobType;
  const _MoreFilters({required this.date, required this.jobType});
}

class _MoreFiltersSheet extends StatefulWidget {
  final _DateRange initialDate;
  final _JobTypeFilter initialJobType;
  const _MoreFiltersSheet({
    required this.initialDate,
    required this.initialJobType,
  });

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late _DateRange _date = widget.initialDate;
  late _JobTypeFilter _jobType = widget.initialJobType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.cardBorder,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          Text(
            'Filters',
            style: AppTextStyles.h3.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Date applied',
            style: AppTextStyles.labelSmall.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _DateRange.values)
                _ChoicePill(
                  label: d.label,
                  selected: _date == d,
                  onTap: () => setState(() => _date = d),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Job type',
            style: AppTextStyles.labelSmall.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _JobTypeFilter.values)
                _ChoicePill(
                  label: t.label,
                  selected: _jobType == t,
                  onTap: () => setState(() => _jobType = t),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _date = _DateRange.last90;
                      _jobType = _JobTypeFilter.any;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lgRadius,
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _MoreFilters(date: _date, jobType: _jobType),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.lgRadius,
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Apply',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : context.surfaceVariant,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.primary : context.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Timeline application card ───────────────────────

class _TimelineRow extends StatelessWidget {
  final JobApplication app;
  final bool isFirst;
  final bool isLast;
  const _TimelineRow({
    required this.app,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail — quiet gray dot + line, no glow. The status
          // pill on the card already carries the colour cue.
          SizedBox(
            width: 22,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: isFirst ? 24 : 0,
                  bottom: isLast ? null : 0,
                  child: Container(
                    width: 2,
                    color: context.cardBorder,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.textTertiary.withValues(alpha: 0.55),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ApplicationCard(app: app),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final JobApplication app;
  const _ApplicationCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final job = app.job;
    final accent = _statusAccent(context, app.status);
    final accentBg = _statusAccentBg(context, app.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.jobDetail,
          arguments: job,
        ),
        borderRadius: AppRadius.xlRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.xlRadius,
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xlRadius,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusPill(
                            label: app.statusLabel,
                            accent: accent,
                            bg: accentBg,
                          ),
                          const Spacer(),
                          if (app.isAiApplied) const _AiAppliedTag(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        job.title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (job.company.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          job.company,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 13,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (job.location.isNotEmpty) ...[
                            Icon(Icons.location_on_outlined,
                                size: 13, color: context.textTertiary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                job.location,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(Icons.schedule_rounded,
                              size: 12, color: context.textTertiary),
                          const SizedBox(width: 3),
                          Text(
                            _relativeTime(app.appliedAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      if (job.salary.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.10),
                            borderRadius: AppRadius.smRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_money_rounded,
                                  size: 14, color: Color(0xFF1B7F3C)),
                              Text(
                                job.salary,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: const Color(0xFF1B7F3C),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _ApplicationChatShortcut(application: app),
                    ],
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;
  final Color bg;
  const _StatusPill({
    required this.label,
    required this.accent,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAppliedTag extends StatelessWidget {
  const _AiAppliedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'AUTO',
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Empty states ───────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Your hunt starts here',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Apply to jobs and we\'ll track every step here. '
              'Records older than 90 days auto-archive.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Browse jobs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  final VoidCallback onReset;
  const _NoMatchState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_outlined,
                size: 64, color: context.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No applications match',
              style: AppTextStyles.h4.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing the status, date or job type filters.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset filters'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

Color _statusAccent(BuildContext context, ApplicationStatus s) {
  switch (s) {
    case ApplicationStatus.shortlisted:
      return AppColors.primary;
    case ApplicationStatus.rejected:
      return AppColors.urgent;
    case ApplicationStatus.interview:
      return const Color(0xFF7C3AED);
    case ApplicationStatus.offered:
      return AppColors.success;
    case ApplicationStatus.applied:
    case ApplicationStatus.viewed:
      return AppColors.warning;
    case ApplicationStatus.withdrawn:
      return context.textSecondary;
  }
}

Color _statusAccentBg(BuildContext context, ApplicationStatus s) {
  switch (s) {
    case ApplicationStatus.shortlisted:
      return context.infoBg;
    case ApplicationStatus.rejected:
      return context.urgentBg;
    case ApplicationStatus.interview:
      return const Color(0xFF7C3AED).withValues(alpha: 0.10);
    case ApplicationStatus.offered:
      return context.successBg;
    case ApplicationStatus.applied:
    case ApplicationStatus.viewed:
      return context.warningBg;
    case ApplicationStatus.withdrawn:
      return context.surfaceVariant;
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

// ─────────────────────── Chat shortcut (kept) ───────────────────────

/// Inline shortcut beneath an applied job card. For native jobs, it opens
/// (or starts) the conversation with the recruiter directly — saving the
/// user a hop into Job Detail to find the chat button. If a conversation
/// already exists, it surfaces the unread count too.
class _ApplicationChatShortcut extends StatefulWidget {
  final JobApplication application;
  const _ApplicationChatShortcut({required this.application});

  @override
  State<_ApplicationChatShortcut> createState() =>
      _ApplicationChatShortcutState();
}

class _ApplicationChatShortcutState
    extends State<_ApplicationChatShortcut> {
  bool _busy = false;

  Conversation? _findConversation(List<Conversation> all) {
    for (final c in all) {
      if (c.applicationId == widget.application.id) return c;
    }
    return null;
  }

  Future<void> _open(Conversation? existing) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String convId;
      if (existing != null) {
        convId = existing.id;
      } else {
        final c = await ChatService.instance.startConversation(
          otherUserId: widget.application.job.postedByUserId,
          jobId: widget.application.job.id,
          applicationId: widget.application.id,
        );
        convId = c.id;
        if (mounted) {
          await context.read<ChatProvider>().loadConversations();
        }
      }
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.chat, arguments: convId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.application.job;
    final canMessage = job.isNative && job.postedByUserId.isNotEmpty;
    if (!canMessage) return const SizedBox.shrink();

    final conv = context.select<ChatProvider, Conversation?>(
      (p) => _findConversation(p.conversations),
    );
    final unread = conv?.unreadCount ?? 0;
    final hasThread = conv != null;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: _busy ? null : () => _open(conv),
        borderRadius: AppRadius.smRadius,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: AppRadius.smRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasThread
                    ? Icons.forum_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasThread
                      ? 'Continue chat with recruiter'
                      : 'Message recruiter',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.urgent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (_busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

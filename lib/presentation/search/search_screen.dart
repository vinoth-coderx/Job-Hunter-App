import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/search_history_service.dart';
import '../../providers/job_provider.dart';
import '../alerts/alerts_screen.dart' show AlertSearchArgs;
import '../widgets/animated_list_item.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/job_card.dart';
import '../widgets/scroll_to_top_fab.dart';
import '../widgets/voice_search_sheet.dart';

class SearchScreen extends StatefulWidget {
  final bool autoStartVoice;

  /// Optional: pre-fill query/filters/location/sort when arriving from
  /// an alert tap (or any other deep link).
  final AlertSearchArgs? prefill;

  /// Hides the back button when the screen is hosted inside a bottom-nav
  /// tab (where there is no parent route to pop back to).
  final bool embedded;

  const SearchScreen({
    super.key,
    this.autoStartVoice = false,
    this.prefill,
    this.embedded = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _resultsScrollCtrl = ScrollController();
  final List<String> _activeFilters = [];
  SortOption _sort = SortOption.newestFirst;
  Timer? _debounce;
  Timer? _recordTimer;
  bool _isListening = false;

  // Local search history — recent (auto) entries only.
  List<SavedSearch> _recent = [];
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Rebuild the body whenever focus changes — drives the
    // "suggestion-overlay" state (focused + non-empty query → show
    // filtered recent searches; unfocused → show results).
    _searchFocus.addListener(_onFocusChanged);
    final prefill = widget.prefill;
    if (prefill != null) {
      _searchController.text = prefill.query;
      _activeFilters.addAll(prefill.filters);
      _sort = SortOption.values.firstWhere(
        (o) => o.name == prefill.sort,
        orElse: () => SortOption.newestFirst,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoStartVoice) {
        _openVoiceSearch();
      } else if (prefill != null) {
        _runSearch();
      } else if (!widget.embedded) {
        // When search is a tab, don't auto-pop the keyboard on every
        // tab-switch — only focus when arriving via a push route.
        _searchFocus.requestFocus();
      }
    });
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recordTimer?.cancel();
    _searchController.dispose();
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _resultsScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final recent = await SearchHistoryService.getRecent();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _historyLoaded = true;
    });
  }

  bool get _hasQuery =>
      _searchController.text.trim().isNotEmpty || _activeFilters.isNotEmpty;

  SavedSearch _currentSearch() => SavedSearch(
        query: _searchController.text.trim(),
        filters: List<String>.from(_activeFilters),
        sort: _sort.name,
        savedAt: DateTime.now(),
      );

  void _onSearchChanged(String _) {
    setState(() {}); // refresh empty-state vs results toggle
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  void _runSearch() {
    if (!_hasQuery) return;
    // AI semantic search: the typed query and any filter chips fold into
    // a single natural-language string sent to /jobs/ai-search, where
    // Claude extracts intent and matches across title, skills,
    // description, responsibilities and company. Replaces the legacy
    // skill-only keyword endpoint.
    final filterText = _activeFilters.join(' ');
    final combined = filterText.isEmpty
        ? _searchController.text
        : '${_searchController.text} $filterText'.trim();
    context.read<JobProvider>().aiSearchJobs(combined, sort: _sort);
    // Record into recent shortly after the user pauses typing — avoids
    // recording every intermediate keystroke as a separate entry.
    _recordTimer?.cancel();
    _recordTimer = Timer(const Duration(milliseconds: 800), () async {
      await SearchHistoryService.recordRecent(_currentSearch());
      _loadHistory();
    });
  }

  void _applySearch(SavedSearch s) {
    _searchController.text = s.query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: s.query.length),
    );
    setState(() {
      _activeFilters
        ..clear()
        ..addAll(s.filters);
      _sort = SortOption.values.firstWhere(
        (o) => o.name == s.sort,
        orElse: () => SortOption.newestFirst,
      );
    });
    _searchFocus.unfocus();
    _runSearch();
  }

  Future<void> _openFilterSheet() async {
    _searchFocus.unfocus();
    final result = await showFilterSheet(
      context,
      currentFilters: _activeFilters,
    );
    if (result == null) return;
    setState(() {
      _activeFilters
        ..clear()
        ..addAll(result);
    });
    if (_hasQuery) _runSearch();
  }

  Future<void> _openSortSheet() async {
    _searchFocus.unfocus();
    final result = await showSortSheet(context, current: _sort);
    if (result == null) return;
    setState(() => _sort = result);
    if (_hasQuery) _runSearch();
  }

  Future<void> _openVoiceSearch() async {
    _searchFocus.unfocus();
    setState(() => _isListening = true);
    final spoken = await showVoiceSearchSheet(context);
    if (!mounted) return;
    setState(() => _isListening = false);
    if (spoken != null && spoken.isNotEmpty) {
      _searchController.text = spoken;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: spoken.length),
      );
      _runSearch();
    }
  }

  void _clearAll() {
    _searchController.clear();
    setState(() => _activeFilters.clear());
  }

  Future<void> _removeRecent(SavedSearch s) async {
    await SearchHistoryService.removeRecent(s);
    _loadHistory();
  }

  Future<void> _clearAllRecent() async {
    await SearchHistoryService.clearRecent();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    // The search bar drives a single floating popover whenever it's
    // focused. With a typed query the popover shows filtered
    // recent/saved suggestions; with an empty query it shows the most
    // recent searches outright (Indeed-style autocomplete). The page
    // beneath it always renders either the search results or the empty
    // discovery state — the popover overlays it instead of replacing it.
    final isFocused = _searchFocus.hasFocus;
    final showPopover = isFocused;
    final showResults = _hasQuery;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        widget.embedded ? 24 : 16, 16, 24, 12),
                    child: Row(
                      children: [
                        if (!widget.embedded) ...[
                          _BackButton(onTap: () => Navigator.of(context).pop()),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: CustomSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            isListening: _isListening,
                            onChanged: _onSearchChanged,
                            onSubmitted: (_) {
                              _searchFocus.unfocus();
                              _runSearch();
                            },
                            onMicTap: _openVoiceSearch,
                            onClear: () => setState(() {}),
                            showFilter: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: showResults
                        ? _buildResultsView()
                        : _buildDiscoveryView(),
                  ),
                ],
              ),
              if (showPopover)
                Positioned.fill(
                  child: _SearchPopoverOverlay(
                    horizontalPadding: widget.embedded ? 24 : 16,
                    rightPadding: 24,
                    topOffset: 12 + 56 + 12 + 8,
                    onTapOutside: () => _searchFocus.unfocus(),
                    child: _buildPopoverContent(query),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: !showResults
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 50,
                child: Stack(
                  children: [
                    Center(
                      child: _SortFilterPill(
                        activeFilterCount: _activeFilters.length,
                        onFilter: _openFilterSheet,
                        onSort: _openSortSheet,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: ScrollToTopFab(
                          controller: _resultsScrollCtrl,
                          showAfterPixels: 600,
                          additionalCondition: () =>
                              context.read<JobProvider>().searchResults.length >
                              8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Background view shown when there is no active query — empty/explore
  /// state shown when there is no active query — pure empty/explore
  /// prompt. Recents now live inside the focused-search popover overlay.
  Widget _buildDiscoveryView() {
    if (!_historyLoaded) return const SizedBox.shrink();
    return _buildEmptyHistory();
  }

  /// Picks the right popover body based on whether the user has typed
  /// anything. With a query: filtered suggestions (matched recents +
  /// a "search for X" action). Without a query: a compact recent-
  /// searches list.
  Widget _buildPopoverContent(String query) {
    if (!_historyLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (query.isNotEmpty) {
      return _buildSuggestionsView(query);
    }
    return _buildRecentPopoverList();
  }

  Widget _buildRecentPopoverList() {
    if (_recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(
          'Start typing to search jobs, companies, or skills.',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.textTertiary,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      children: [
        if (_recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: context.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearAllRecent,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: context.textSecondary,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          for (final s in _recent.take(8))
            _SuggestionTile(
              icon: Icons.history_rounded,
              iconColor: context.textTertiary,
              primaryQuery: s.query,
              label: s.query.isEmpty ? '(filters only)' : s.query,
              highlight: '',
              trailing: GestureDetector(
                onTap: () => _removeRecent(s),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: context.textTertiary,
                  ),
                ),
              ),
              onTap: () => _applySearch(s),
            ),
        ],
      ],
    );
  }

  Widget _buildResultsView() {
    final provider = context.watch<JobProvider>();
    final results = provider.searchResults;

    return CustomScrollView(
      controller: _resultsScrollCtrl,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style:
                          AppTextStyles.h4.copyWith(color: context.textPrimary),
                      children: [
                        const TextSpan(text: 'Results '),
                        TextSpan(
                          text: '(${results.length})',
                          style: AppTextStyles.h4
                              .copyWith(color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (provider.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoResults(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 110),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final job = results[i];
                final applied = provider.hasApplied(job.id);
                final saved = provider.isJobSaved(job.id);
                return AnimatedListItem(
                  key: ValueKey(job.id),
                  child: JobCard(
                    job: job,
                    statusBadge: applied ? 'Applied' : null,
                    statusColor: applied ? AppColors.success : null,
                    statusBgColor: applied ? context.successBg : null,
                    isSaved: saved,
                    onSave: () =>
                        context.read<JobProvider>().toggleSaveJob(job.id),
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
    );
  }

  /// Inline suggestions rendered while the search bar is focused and the
  /// user has typed at least one character. Filters recent searches to
  /// entries whose query contains the typed substring (case-insensitive).
  /// Top entry is always a `Search for '...'` action so the user can
  /// submit even when nothing matches.
  Widget _buildSuggestionsView(String query) {
    if (!_historyLoaded) return const SizedBox.shrink();
    final q = query.toLowerCase();
    final matchedRecent = _recent
        .where((s) => s.query.toLowerCase().contains(q))
        .take(6)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _SuggestionTile(
            icon: Icons.search_rounded,
            iconColor: AppColors.primary,
            primaryQuery: query,
            label: "Search for '$query'",
            highlight: query,
            onTap: () {
              _searchFocus.unfocus();
              _runSearch();
            },
          ),
          if (matchedRecent.isNotEmpty) ...[
            _SuggestionSectionLabel(label: 'Recent'),
            for (final s in matchedRecent)
              _SuggestionTile(
                icon: Icons.history_rounded,
                iconColor: context.textTertiary,
                primaryQuery: s.query,
                label: s.query.isEmpty ? '(filters only)' : s.query,
                highlight: query,
                trailing: GestureDetector(
                  onTap: () => _removeRecent(s),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: context.textTertiary,
                    ),
                  ),
                ),
                onTap: () => _applySearch(s),
              ),
          ],
          if (matchedRecent.isEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'No matching past searches.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text('Search for jobs',
              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "Try a role, company, or skill — we'll remember your recent searches here.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 80, color: context.textTertiary),
          const SizedBox(height: 16),
          Text('No jobs found', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(
            'Try a different keyword or remove some filters',
            style: AppTextStyles.bodyMedium
                .copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: context.textPrimary,
        ),
      ),
    );
  }
}

class _SortFilterPill extends StatelessWidget {
  final int activeFilterCount;
  final VoidCallback onFilter;
  final VoidCallback onSort;

  const _SortFilterPill({
    required this.activeFilterCount,
    required this.onFilter,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.navBackground,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillButton(
            icon: Icons.tune_rounded,
            label: 'Filter',
            badgeCount: activeFilterCount,
            onTap: onFilter,
          ),
          Container(width: 1, height: 24, color: Colors.white24),
          _PillButton(
            icon: Icons.swap_vert_rounded,
            label: 'Sort',
            onTap: onSort,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '$badgeCount',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Single suggestion row inside the focused-search dropdown. Highlights the
/// portion of the query that already matches what the user typed so the
/// completion is visually clear.
class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String highlight;
  final String primaryQuery;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.highlight,
    required this.primaryQuery,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: _highlightedText(context, label, highlight),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  /// Bolds the substring of [text] that matches [highlight] (case-
  /// insensitive). The non-matching parts stay regular weight so the
  /// matching span pops without making the whole label heavy.
  Widget _highlightedText(
      BuildContext context, String text, String highlight) {
    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    if (highlight.isEmpty || !lowerText.contains(lowerHighlight)) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(
          color: context.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final start = lowerText.indexOf(lowerHighlight);
    final end = start + highlight.length;
    final base = AppTextStyles.bodyMedium.copyWith(
      color: context.textPrimary,
      fontWeight: FontWeight.w500,
    );
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

class _SuggestionSectionLabel extends StatelessWidget {
  final String label;
  const _SuggestionSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: context.textTertiary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

/// Floating popover that appears below the search bar while it's
/// focused — shows recent/saved searches when the query is empty and
/// filtered suggestions while typing. Sits in a Positioned-fill stack
/// layer so it floats over the results/discovery view instead of
/// replacing it (the Indeed/Naukri behaviour the previous full-page
/// history list got wrong).
///
/// A tap outside the popover dismisses focus, which in turn unmounts
/// this overlay.
class _SearchPopoverOverlay extends StatelessWidget {
  final double horizontalPadding;
  final double rightPadding;
  final double topOffset;
  final VoidCallback onTapOutside;
  final Widget child;

  const _SearchPopoverOverlay({
    required this.horizontalPadding,
    required this.rightPadding,
    required this.topOffset,
    required this.onTapOutside,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap-outside catcher. Transparent so the page underneath is
        // still visible; only intercepts taps so unfocusing the search
        // bar feels natural without an obvious scrim.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTapOutside,
          ),
        ),
        Positioned(
          top: topOffset,
          left: horizontalPadding,
          right: rightPadding,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            builder: (context, t, c) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * -8),
                child: c,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                // Cap height so the popover never pushes off-screen
                // on shorter devices; inner ListView handles scroll.
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: AppRadius.lgRadius,
                    border: Border.all(color: context.cardBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.lgRadius,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

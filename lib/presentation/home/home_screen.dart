import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../data/services/push_service.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coins_provider.dart';
import '../../providers/job_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/app_avatar.dart';
import '../widgets/coin_pill.dart';
import '../widgets/compact_job_card.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/header_action_button.dart';
import '../widgets/home_section.dart';
import '../widgets/job_card.dart';
import '../widgets/scroll_to_top_fab.dart';
import 'widgets/quick_actions_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollCtrl = ScrollController();

  // Gate the scroll-to-top FAB until the list is meaningfully long.
  static const int _fabMinJobs = 20;
  static const double _fabShowOffset = 800;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isGuest = context.read<AuthProvider>().isGuest;
      final jobs = context.read<JobProvider>();
      jobs.loadJobs(asGuest: isGuest);
      // Resolve current city in parallel with the feed load. Idempotent
      // per-session, so re-entering home doesn't re-prompt for permission.
      jobs.loadCurrentLocation();
      if (!isGuest) {
        context.read<AlertProvider>().load();
        // Bell badge reflects the unified notification inbox
        // (`/api/v1/notifications`), not saved-search alerts. Refresh on
        // landing so the count is fresh; the inbox screen does its own
        // full load on open.
        context.read<NotificationProvider>().refreshUnread();
        // Same idea for the chat tab badge: pull conversations so the
        // unread count is accurate the moment the user lands on Home,
        // without requiring them to open Messages first.
        context.read<ChatProvider>()
          ..start()
          ..loadConversations();
        // Coin balance for the header pill. Best-effort — the pill
        // falls back to whatever value the provider last cached.
        context.read<CoinsProvider>().refresh();
        PushService.init();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App back from background → re-pull the feed if it has gone stale.
    // JobProvider gates the actual fetch behind a freshness window, so
    // toggling foreground frequently won't cause a request flood.
    if (state == AppLifecycleState.resumed && mounted) {
      final isGuest = context.read<AuthProvider>().isGuest;
      context.read<JobProvider>().maybeAutoRefresh(asGuest: isGuest);
      if (!isGuest) {
        // Pick up any coins earned while we were backgrounded
        // (server-side grants from cron, referrals, etc.).
        context.read<CoinsProvider>().refresh();
      }
    }
  }

  // Trigger the next page slightly before the user actually hits the
  // bottom — feels seamless and keeps the spinner gap small.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      context.read<JobProvider>().loadMoreJobs();
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openSearch({bool voice = false}) {
    Navigator.pushNamed(
      context,
      AppRoutes.search,
      arguments: voice ? 'voice' : null,
    );
  }

  void _openJobDetail(Job job) {
    Navigator.pushNamed(context, AppRoutes.jobDetail, arguments: job);
  }

  /// category tab. 'All' is always first.
  List<String> _categoriesForUser(JobProvider jobProvider) {
    final counts = <String, int>{};
    for (final job in jobProvider.jobs) {
      final c = job.category;
      if (c.isEmpty) continue;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ['All', ...ordered.map((e) => e.key)];
  }

  @override
  Widget build(BuildContext context) {
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
        child: SafeArea(child: _buildDefaultView()),
      ),
      floatingActionButton: ScrollToTopFab(
        controller: _scrollCtrl,
        showAfterPixels: _fabShowOffset,
        additionalCondition: () =>
            context.read<JobProvider>().jobs.length > _fabMinJobs,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDefaultView() {
    final user = context.watch<AuthProvider>().user;
    final jobProvider = context.watch<JobProvider>();
    final categories = _categoriesForUser(jobProvider);
    if (!categories.contains(jobProvider.selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<JobProvider>().selectCategory('All');
      });
    }

    final auth = context.watch<AuthProvider>();
    final isGuest = auth.isGuest;
    final loading = jobProvider.isLoading;
    final allJobs = jobProvider.jobs;
    final visibleJobs = jobProvider.matchedJobs;
    // Resolve a city for the "Jobs in <city>" section. Prefer the
    // GPS-derived label; if location was denied / unavailable AND the
    // signed-in user has a preferred location on file, fall back to that
    // so the section still renders something useful.
    String? nearbyCity = jobProvider.locationLabel;
    if ((nearbyCity == null || nearbyCity.isEmpty) &&
        auth.isAuthenticated &&
        (auth.user?.preferredLocations.isNotEmpty ?? false)) {
      nearbyCity = auth.user!.preferredLocations.first;
    }
    final nearbyJobs = (nearbyCity != null && nearbyCity.isNotEmpty)
        ? jobProvider.jobsInCity(nearbyCity, limit: 8)
        : const <Job>[];

    return RefreshIndicator(
      onRefresh: () => jobProvider.loadJobs(asGuest: isGuest),
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _scrollCtrl,
        // Pull-to-refresh needs an overscrollable list; without this,
        // the empty state has no scrollable extent and the user can't
        // pull at all.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: context.gradientTop,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                children: [
                  AppAvatar(
                    url: user?.photoUrl,
                    name: user?.name,
                    size: 48,
                    border: const BorderSide(color: Colors.white, width: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _greeting(),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name
                                    : 'User',
                                style: AppTextStyles.h4
                                    .copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isGuest && (user?.isPro ?? false)) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFEF4444)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Coin balance pill — gold gradient so it reads as a
                  // wallet at-a-glance, not just another secondary icon.
                  // Guests don't have a balance to show.
                  if (!isGuest) ...[
                    const CoinPill(),
                    const SizedBox(width: 8),
                  ],
                  // Messages icon — primary entry point for chat now that
                  // it's been removed from the bottom-nav. Sits left of
                  // the bell so the urgent-coloured badges don't stack.
                  HeaderActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Messages',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.conversations),
                    badgeCount: isGuest
                        ? 0
                        : context
                            .select<ChatProvider, int>((p) => p.totalUnread),
                  ),
                  const SizedBox(width: 8),
                  HeaderActionButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                    badgeCount: isGuest
                        ? 0
                        : context.watch<NotificationProvider>().unread,
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: CustomSearchBar(
                showFilter: false,
                onTap: _openSearch,
                onMicTap: () => _openSearch(voice: true),
              ),
            ),
          ),

          // Quick actions — Auto-Apply, Achievements, Saved, Assessments.
          // Replaces the bulky single-purpose cards so the home feed stays
          // scannable on small screens.
          if (!isGuest) const SliverToBoxAdapter(child: QuickActionsRow()),

          // Jobs near current location — visible whenever we resolved a
          // city (GPS or profile fallback) and at least one loaded job
          // mentions it. Skipped while still loading the first page.
          if (!loading &&
              nearbyCity != null &&
              nearbyCity.isNotEmpty &&
              nearbyJobs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                  title: 'Jobs in $nearbyCity',
                  subtitle: auth.isAuthenticated && !auth.needsOnboarding
                      ? 'Match-scored openings near you'
                      : 'Openings near you'),
            ),
            SliverToBoxAdapter(
              child: HorizontalCardList(
                itemCount: nearbyJobs.length,
                itemBuilder: (_, i) {
                  final job = nearbyJobs[i];
                  return CompactJobCard(
                    job: job,
                    applied: jobProvider.hasApplied(job.id),
                    onTap: () => _openJobDetail(job),
                  );
                },
              ),
            ),
          ],

          // "Recently posted" was removed — the hand-picked carousel
          // above already buckets by recency, so a separate section
          // would surface the same listings under a second header.

          SliverToBoxAdapter(
            child: SectionHeader(
              title: jobProvider.selectedCategory == 'All'
                  ? 'More for you'
                  : '${jobProvider.selectedCategory} jobs',
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            ),
          ),

          if (loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverList.separated(
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const JobCardSkeleton(),
              ),
            )
          else if (visibleJobs.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                error: jobProvider.error,
                hasAnyJobs: allJobs.isNotEmpty,
                onShowAll: () => jobProvider.selectCategory('All'),
                onRetry: () => jobProvider.loadJobs(),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverList.separated(
                itemCount: visibleJobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final job = visibleJobs[i];
                  final applied = jobProvider.hasApplied(job.id);
                  return AnimatedListItem(
                    key: ValueKey(job.id),
                    child: JobCard(
                      job: job,
                      statusBadge: applied ? 'Applied' : null,
                      statusColor: applied ? AppColors.success : null,
                      statusBgColor: applied ? context.successBg : null,
                      onTap: () => _openJobDetail(job),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _PaginationFooter(
                isLoadingMore: jobProvider.isLoadingMore,
                hasMore: jobProvider.hasMore,
                jobsShown: visibleJobs.length,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;
  final int jobsShown;
  const _PaginationFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.jobsShown,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 120),
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
    if (!hasMore && jobsShown > 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
        child: Center(
          child: Text(
            "You're all caught up",
            style:
                AppTextStyles.bodySmall.copyWith(color: context.textTertiary),
          ),
        ),
      );
    }
    return const SizedBox(height: 120);
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  final bool hasAnyJobs;
  final VoidCallback? onShowAll;
  final VoidCallback? onRetry;

  const _EmptyState({
    this.error,
    this.hasAnyJobs = false,
    this.onShowAll,
    this.onRetry,
  });

  /// Map raw exception text to a short, human-readable line. The provider
  /// surfaces `e.toString()` from the underlying http/socket layer, which
  /// is fine for logs but useless to a user staring at "ClientException
  /// with SocketException…". Pattern-match the common cases and fall
  /// back to a generic "Try again" message.
  static (String title, String body) _humanize(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused')) {
      return (
        'Server unreachable',
        "We couldn't reach the server. Check your internet and try again.",
      );
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return ('Request timed out', 'Slow connection — give it another try.');
    }
    if (lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('tls')) {
      return (
        'Secure connection failed',
        'Network is blocking the connection. Try a different network.'
      );
    }
    return (
      'Could not load jobs',
      'Something went wrong. Pull to refresh or try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    String title;
    String body;
    if (hasError) {
      final (t, b) = _humanize(error!);
      title = t;
      body = b;
    } else {
      title = hasAnyJobs ? 'No jobs in this category' : 'No matches yet';
      body = hasAnyJobs
          ? 'Try a different category, or view all jobs.'
          : 'Add skills and preferred roles to your profile to unlock personalized matches.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 80),
      child: Column(
        children: [
          Icon(
            hasError ? Icons.cloud_off_rounded : Icons.work_history_outlined,
            size: 56,
            color: context.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style:
                AppTextStyles.bodySmall.copyWith(color: context.textSecondary),
          ),
          if (hasError && onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
          if (!hasError && hasAnyJobs && onShowAll != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Show all jobs'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

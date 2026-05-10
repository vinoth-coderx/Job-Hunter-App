import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/application_model.dart';
import '../data/models/job_model.dart';
import '../data/services/api_client.dart';
import '../data/services/applied_service.dart';
import '../data/services/job_service.dart';
import '../data/services/location_service.dart';
import '../data/services/storage_service.dart';
import '../presentation/widgets/filter_sort_sheet.dart';

class JobProvider extends ChangeNotifier {
  final JobService _jobService = JobService();
  final AppliedService _appliedService = AppliedService();

  List<Job> _jobs = [];
  List<Job> _searchResults = [];
  SearchScope _searchScope = SearchScope.primary;
  List<JobApplication> _applications = [];
  final Set<String> _savedJobIds = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  bool _wasGuestLoad = false;
  static const int _pageSize = 20;
  String _selectedCategory = 'All';
  String? _error;

  // Auto-detected current city used to drive the "Jobs in <city>" home
  // section. Resolved lazily on first home-screen view via
  // `loadCurrentLocation`; null means we either haven't tried yet, the
  // user denied permission, or geocoding came back empty.
  LocationResult? _location;
  bool _locationLoading = false;

  // Last successful `loadJobs` completion. Used by the home shell to
  // decide whether returning to the Home tab (or app foreground) should
  // re-fetch — without this every tab tap would slam the API.
  DateTime? _lastLoadedAt;
  static const Duration _autoRefreshAfter = Duration(seconds: 90);

  // Background re-fetch every 2 hours so a seeker who leaves the app
  // open in a tab (or in the recents tray) keeps seeing fresh listings
  // without manually pulling-to-refresh. Each tick also runs the high-
  // match dedup pipeline below so newly-posted 70%+ jobs surface as a
  // toast even when the user is on a different screen.
  static const Duration _periodicRefreshInterval = Duration(hours: 2);
  Timer? _periodicTimer;
  bool _wasGuestSession = false;

  // High-match alerting state. `_alertedHighMatchIds` is the persisted
  // set of job ids the user has already been told about — without it
  // every periodic refresh would re-toast the same job. The notifier
  // emits the *new* jobs (post-dedup) so a top-level listener can show
  // a single toast/snackbar; consumers should clear via [consumeAlerts]
  // after rendering.
  static const double _highMatchThreshold = 70.0;
  Set<String> _alertedHighMatchIds = {};
  bool _alertedHydrated = false;
  final ValueNotifier<List<Job>> highMatchAlerts =
      ValueNotifier<List<Job>>(const []);

  List<Job> get jobs => _jobs;
  List<Job> get searchResults => _searchResults;
  SearchScope get searchScope => _searchScope;
  List<JobApplication> get applications => _applications;
  Set<String> get savedJobIds => _savedJobIds;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get selectedCategory => _selectedCategory;
  String? get error => _error;

  int get appliedCount => _applications.length;
  int get shortlistedCount => _applications
      .where((a) => a.status == ApplicationStatus.shortlisted)
      .length;
  int get rejectedCount => _applications
      .where((a) => a.status == ApplicationStatus.rejected)
      .length;
  int get interviewCount =>
      _applications.where((a) => a.status == ApplicationStatus.interview).length;

  /// Read-time view of `_jobs` with applied rows stripped. Auto-Apply
  /// runs server-side and can silently land applications while the app
  /// is open, so the load-time `_stripApplied` snapshot goes stale.
  /// Re-filtering at read keeps every discovery surface (matchedJobs /
  /// topMatches / handPickedForYou / city / nearby / recentlyPosted)
  /// self-healing — once `_applications` refreshes (loadJobs, resume,
  /// refreshApplications), the next render hides the just-applied row
  /// without needing a feed reload.
  List<Job> get _visibleJobs => _stripApplied(_jobs);

  List<Job> get matchedJobs {
    final base = _visibleJobs;
    if (_selectedCategory == 'All') return base;
    return base.where((j) => j.category == _selectedCategory).toList();
  }

  /// Top match-scored jobs from the already-loaded feed. Backend returns
  /// score-sorted; this is just a capped slice for the home carousel.
  /// Returns empty when no jobs carry a score (guest sessions and the
  /// profile-incomplete fallback both surface `score: null`), so the home
  /// section can hide cleanly instead of showing un-scored "matches".
  List<Job> topMatches({int limit = 5}) {
    return _visibleJobs.where((j) => j.matchScore != null).take(limit).toList();
  }

  /// Curated "Hand-picked for you" feed that replaces the old separate
  /// "Top matches" + "Recently posted" carousels. Combines both signals
  /// the seeker actually scans for:
  ///
  ///   1. Recency bucket — jobs posted in the last 24h come first, then
  ///      7 days, then 30 days, then older. New listings always lead.
  ///   2. Match score within the bucket — best fit ranks higher inside
  ///      the same recency window so a 92% match doesn't sink behind a
  ///      35% match just because the latter was posted an hour earlier.
  ///   3. Score floor — only jobs with `matchScore` ≥ 30 are surfaced.
  ///      Below 30% reads as "irrelevant" to the seeker; we'd rather
  ///      hide than dilute the feed.
  ///
  /// Returns an empty list when the user is unscored (guest / pre-
  /// onboarding) so the home section can hide cleanly. Falls back to
  /// recency-only sort for the few jobs missing a score in an
  /// otherwise-scored feed.
  List<Job> handPickedForYou({int limit = 8}) {
    final now = DateTime.now();
    int bucket(DateTime? when) {
      if (when == null) return 4;
      final age = now.difference(when);
      if (age.inHours <= 24) return 0;
      if (age.inDays <= 7) return 1;
      if (age.inDays <= 30) return 2;
      return 3;
    }

    final scored = _visibleJobs
        .where((j) => j.matchScore != null && j.matchScore! >= 30)
        .toList();
    if (scored.isEmpty) return const [];

    scored.sort((a, b) {
      final ba = bucket(a.postedAt);
      final bb = bucket(b.postedAt);
      if (ba != bb) return ba.compareTo(bb);
      // Within the bucket, higher match wins.
      return (b.matchScore ?? 0).compareTo(a.matchScore ?? 0);
    });
    return scored.take(limit).toList();
  }

  LocationResult? get location => _location;
  bool get locationLoading => _locationLoading;
  String? get locationLabel => _location?.label;

  /// Resolve current device location and notify listeners. Idempotent
  /// per-session unless `force: true`: a previously-cached `ok` result is
  /// returned without re-prompting. Failures (denied / service off /
  /// geocode error) cache too, so we don't re-prompt on every home view.
  Future<void> loadCurrentLocation({bool force = false}) async {
    if (_locationLoading) return;
    final cached = LocationService.instance.cached;
    if (!force && cached != null) {
      _location = cached;
      notifyListeners();
      return;
    }
    _locationLoading = true;
    notifyListeners();
    try {
      _location = await LocationService.instance.resolve(force: force);
    } finally {
      _locationLoading = false;
      notifyListeners();
    }
  }

  /// Jobs from the already-loaded feed whose `location` text contains
  /// `city` (case-insensitive). Preserves the underlying order so a
  /// score-sorted feed yields score-sorted nearby results, and a
  /// recency-sorted guest feed yields recency-sorted nearby results.
  List<Job> jobsInCity(String city, {int limit = 1000}) {
    final needle = city.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final out = <Job>[];
    for (final j in _visibleJobs) {
      if (j.location.toLowerCase().contains(needle)) {
        out.add(j);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// Convenience: jobs in the auto-detected current city. Empty when
  /// location hasn't resolved yet or no loaded job mentions the city.
  List<Job> jobsNearby({int limit = 1000}) {
    final city = _location?.label;
    if (city == null || city.isEmpty) return const [];
    return jobsInCity(city, limit: limit);
  }

  /// Most recently posted jobs from the already-loaded feed, sorted by
  /// `postedAt` desc. Jobs without a parseable date sink to the end.
  List<Job> recentlyPosted({int limit = 8}) {
    final list = List<Job>.from(_visibleJobs);
    list.sort((a, b) {
      final ad = a.postedAt;
      final bd = b.postedAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return list.take(limit).toList();
  }

  Future<void> loadJobs({bool asGuest = false}) async {
    _isLoading = true;
    _error = null;
    _page = 1;
    _hasMore = false;
    _wasGuestLoad = asGuest;
    _wasGuestSession = asGuest;
    notifyListeners();
    try {
      final fetch = asGuest
          ? _jobService.guestFeedPage(page: 1, limit: _pageSize)
          : _jobService.homeFeedPage(page: 1, limit: _pageSize);
      final results = await Future.wait<dynamic>([
        fetch,
        if (!asGuest) _appliedService.list(limit: 100) else Future.value(<JobApplication>[]),
      ]);
      final firstPage = results[0] as JobPage;
      _applications = (results[1] as List<JobApplication>);
      _jobs = _stripApplied(_dedupe(firstPage.jobs));
      _hasMore = firstPage.hasMore;
      _page = firstPage.page;
      _lastLoadedAt = DateTime.now();
      _detectHighMatchAlerts();
    } catch (e) {
      _error = _formatError(e);
      _jobs = [];
      _applications = [];
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    // First-load also kicks off the periodic background refresh; the
    // call is idempotent so calling it on every loadJobs is fine.
    _ensurePeriodicRefresh();
  }

  /// Starts (or no-ops if already running) the 2-hour background refresh
  /// loop. Only runs while we have a non-empty session — guest loads
  /// also keep ticking so guests see fresh public listings without
  /// having to pull-to-refresh. Cancelled on signOut/dispose.
  void _ensurePeriodicRefresh() {
    if (_periodicTimer != null && _periodicTimer!.isActive) return;
    _periodicTimer = Timer.periodic(_periodicRefreshInterval, (_) async {
      // Skip the tick if the user is mid-load — the in-flight call will
      // refresh the same data anyway, and racing them would clobber
      // pagination state.
      if (_isLoading || _isLoadingMore) return;
      await _backgroundRefresh();
    });
  }

  Future<void> _backgroundRefresh() async {
    try {
      final page = _wasGuestSession
          ? await _jobService.guestFeedPage(page: 1, limit: _pageSize)
          : await _jobService.homeFeedPage(page: 1, limit: _pageSize);
      _jobs = _stripApplied(_dedupe(page.jobs));
      _hasMore = page.hasMore;
      _page = page.page;
      _lastLoadedAt = DateTime.now();
      _detectHighMatchAlerts();
      notifyListeners();
    } catch (_) {
      // Silent — periodic refresh failure shouldn't disrupt the user;
      // they'll get a fresh attempt 2h later or when they pull-to-refresh.
    }
  }

  /// Find jobs at or above [_highMatchThreshold] that the user hasn't
  /// already been told about, surface them via [highMatchAlerts] for
  /// the root listener to toast, and persist the dedup set so the next
  /// app launch / refresh tick doesn't re-alert the same jobs.
  ///
  /// Guests skip — match scores are user-profile bound, so a guest
  /// session's "70% match" is meaningless.
  Future<void> _detectHighMatchAlerts() async {
    if (_wasGuestSession) return;
    if (!_alertedHydrated) {
      _alertedHighMatchIds = StorageService.getAlertedHighMatchJobIds();
      _alertedHydrated = true;
    }
    final fresh = <Job>[];
    final freshIds = <String>{};
    for (final j in _jobs) {
      final score = j.matchScore;
      if (score == null || score < _highMatchThreshold) continue;
      if (j.id.isEmpty) continue;
      if (_alertedHighMatchIds.contains(j.id)) continue;
      fresh.add(j);
      freshIds.add(j.id);
    }
    if (fresh.isEmpty) return;
    _alertedHighMatchIds = {..._alertedHighMatchIds, ...freshIds};
    await StorageService.saveAlertedHighMatchJobIds(_alertedHighMatchIds);
    highMatchAlerts.value = fresh;
  }

  /// Called by the listener after it's rendered the toast — clears the
  /// notifier so the same alert isn't re-shown on the next rebuild.
  void consumeHighMatchAlerts() {
    if (highMatchAlerts.value.isNotEmpty) {
      highMatchAlerts.value = const [];
    }
  }

  /// Fetch the next page of jobs and append. Safe to call multiple times —
  /// re-entrancy is guarded by `_isLoadingMore`, and the `_hasMore` flag
  /// from the previous page short-circuits when the server has no more.
  Future<void> loadMoreJobs() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final page = _wasGuestLoad
          ? await _jobService.guestFeedPage(page: next, limit: _pageSize)
          : await _jobService.homeFeedPage(page: next, limit: _pageSize);
      _jobs = _stripApplied(_dedupe([..._jobs, ...page.jobs]));
      _hasMore = page.hasMore;
      _page = page.page;
    } catch (e) {
      _error = _formatError(e);
      // Don't drop accumulated jobs on a paginated failure — the UI can
      // surface the snackbar and let the user retry the next scroll.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Re-fetch the home feed if the last successful load is older than
  /// `_autoRefreshAfter`. Cheap no-op when the data is fresh, so the home
  /// shell can call it on every tab return / app resume without spamming.
  /// Skips while a load is already in flight.
  Future<void> maybeAutoRefresh({bool asGuest = false}) async {
    if (_isLoading) return;
    final last = _lastLoadedAt;
    if (last != null && DateTime.now().difference(last) < _autoRefreshAfter) {
      return;
    }
    await loadJobs(asGuest: asGuest);
  }

  Future<void> refreshApplications() async {
    try {
      _applications = await _appliedService.list(limit: 100);
      notifyListeners();
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
    }
  }

  /// AI-powered semantic search. Sends the raw natural-language query
  /// to `POST /jobs/ai-search`; the backend extracts intent via Claude
  /// and ranks across title/skills/description/responsibilities/role.
  /// Optional [sort] re-orders the AI-ranked list (newest / highest
  /// salary / most applications) without dropping the relevance rank.
  Future<void> aiSearchJobs(
    String query, {
    int limit = 30,
    SortOption? sort,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _jobService.aiSearchJobs(
        query: trimmed,
        limit: limit,
      );
      final deduped = _stripApplied(_dedupe(response.jobs));
      _searchResults = sort == null ? deduped : _applySort(deduped, sort);
      _searchScope = response.scope;
    } catch (e) {
      _error = _formatError(e);
      _searchResults = [];
      _searchScope = SearchScope.empty;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchJobs(
    String query, {
    List<String>? filters,
    SortOption sort = SortOption.newestFirst,
    String? location,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      String? jobType;
      String? remoteType;
      final skills = <String>[];
      for (final f in filters ?? const <String>[]) {
        final lc = f.toLowerCase();
        if (['full-time', 'part-time', 'contract', 'internship'].contains(lc)) {
          jobType = lc;
        } else if (['remote', 'hybrid', 'onsite', 'on-site'].contains(lc)) {
          remoteType = lc.replaceAll('on-site', 'onsite');
        } else {
          skills.add(f);
        }
      }
      final results = await _jobService.searchJobs(
        q: query,
        location: location,
        jobType: jobType,
        remoteType: remoteType,
        skills: skills.isEmpty ? null : skills,
        sort: _sortKey(sort),
      );
      final deduped = _stripApplied(_dedupe(results));
      _searchResults = _applySort(deduped, sort);
    } catch (e) {
      _error = _formatError(e);
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _sortKey(SortOption sort) {
    switch (sort) {
      case SortOption.highestSalary:
        return 'salary';
      case SortOption.newestFirst:
        return 'newest';
      case SortOption.mostApplications:
        return 'applications';
    }
  }

  List<Job> _applySort(List<Job> jobs, SortOption sort) {
    final list = List<Job>.from(jobs);
    switch (sort) {
      case SortOption.newestFirst:
        return list.reversed.toList();
      case SortOption.highestSalary:
        list.sort(
            (a, b) => _salaryNum(b.salary).compareTo(_salaryNum(a.salary)));
        return list;
      case SortOption.mostApplications:
        // The API does not surface application counts; fall back to newest.
        return list.reversed.toList();
    }
  }

  int _salaryNum(String salary) {
    final digits = salary.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  /// Drop repeats coming back from the feed. Same posting often shows up
  /// twice when multiple sources (Adzuna, SerpAPI, scrapers) ingest it,
  /// so we key on the API id first and fall back to title+company+location
  /// fingerprint for sourceless duplicates. We keep the first occurrence
  /// so the original ordering (and any match score) is preserved.
  List<Job> _dedupe(List<Job> jobs) {
    final seen = <String>{};
    final out = <Job>[];
    for (final job in jobs) {
      final keys = <String>[];
      if (job.id.isNotEmpty) keys.add('id:${job.id}');
      keys.add(_fingerprint(job));
      if (keys.any(seen.contains)) continue;
      seen.addAll(keys);
      out.add(job);
    }
    return out;
  }

  String _fingerprint(Job job) {
    String norm(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return 'fp:${norm(job.title)}|${norm(job.company)}|${norm(job.location)}';
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Optimistic save toggle. Updates local state immediately, then syncs
  /// with the backend; rolls back on error.
  Future<void> toggleSaveJob(String jobId) async {
    final wasSaved = _savedJobIds.contains(jobId);
    if (wasSaved) {
      _savedJobIds.remove(jobId);
    } else {
      _savedJobIds.add(jobId);
    }
    notifyListeners();
    try {
      if (wasSaved) {
        await _jobService.unsaveJob(jobId);
      } else {
        await _jobService.saveJob(jobId);
      }
    } catch (e) {
      // Roll back on failure.
      if (wasSaved) {
        _savedJobIds.add(jobId);
      } else {
        _savedJobIds.remove(jobId);
      }
      _error = _formatError(e);
      notifyListeners();
    }
  }

  bool isJobSaved(String jobId) => _savedJobIds.contains(jobId);

  /// Pull the persisted save list from the server. Called once at app start
  /// + after login so saved state survives reinstall / device change.
  Future<void> syncSavedJobIds() async {
    try {
      final ids = await _jobService.fetchSavedJobIds();
      _savedJobIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (_) {
      // Best-effort — local state is fine even if sync misses.
    }
  }

  /// Full saved jobs list (with details) for the saved jobs screen.
  Future<List<Job>> fetchSavedJobs() => _jobService.fetchSavedJobs();

  // Coin-grant snapshot from the most recent apply / quick-apply. Read
  // by the screen that triggered the apply so it can push the balance
  // into CoinsProvider — provider doesn't have a BuildContext, so the
  // UI mediates the cross-provider write.
  int? _lastApplyCoinsBalance;
  int? _lastApplyCoinsAwarded;
  int? get lastApplyCoinsBalance => _lastApplyCoinsBalance;
  int? get lastApplyCoinsAwarded => _lastApplyCoinsAwarded;

  Future<bool> applyToJob(Job job, {String? notes}) async {
    if (hasApplied(job.id)) return false;
    try {
      final result =
          await _appliedService.apply(jobId: job.id, notes: notes);
      _applications = [result.application, ..._applications];
      _lastApplyCoinsBalance = result.coinsBalance;
      _lastApplyCoinsAwarded = result.coinsAwarded;
      _removeFromDiscoveryFeeds(job.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> quickApplyToJob(
    Job job, {
    String? quickNote,
    List<({String question, String answer})>? screeningAnswers,
  }) async {
    if (hasApplied(job.id)) return false;
    try {
      final result = await _appliedService.quickApply(
        jobId: job.id,
        quickNote: quickNote,
        screeningAnswers: screeningAnswers,
      );
      _applications = [result.application, ..._applications];
      _lastApplyCoinsBalance = result.coinsBalance;
      _lastApplyCoinsAwarded = result.coinsAwarded;
      _removeFromDiscoveryFeeds(job.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Drop a just-applied job from the home feed and any cached search
  /// results. Backend `/jobs/matched` and `/jobs` already exclude applied
  /// IDs, so a fresh fetch wouldn't include this job — but the local lists
  /// are kept across navigations, so the just-applied row would otherwise
  /// linger on Home / Search until pull-to-refresh.
  void _removeFromDiscoveryFeeds(String jobId) {
    _jobs = _jobs.where((j) => j.id != jobId).toList();
    if (_searchResults.isNotEmpty) {
      _searchResults = _searchResults.where((j) => j.id != jobId).toList();
    }
  }

  /// Defence-in-depth filter for discovery feeds. Backend already strips
  /// applied jobs from `/jobs/matched` and `/jobs`, but we re-apply the
  /// filter locally so a temporarily-stale backend (mid-deploy, cache,
  /// race with `_applications` update) never surfaces an applied row in
  /// Home / Search.
  List<Job> _stripApplied(List<Job> jobs) {
    if (_applications.isEmpty) return jobs;
    final appliedIds = _applications.map((a) => a.job.id).toSet();
    return jobs.where((j) => !appliedIds.contains(j.id)).toList();
  }

  Future<bool> updateApplication(
    String id, {
    ApplicationStatus? status,
    String? notes,
    DateTime? followUpDate,
  }) async {
    try {
      final updated = await _appliedService.update(
        id,
        status: status,
        notes: notes,
        followUpDate: followUpDate,
      );
      _applications = _applications
          .map((a) => a.id == id ? updated : a)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> withdrawApplication(String id) async {
    try {
      await _appliedService.remove(id);
      _applications = _applications.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  bool hasApplied(String jobId) {
    return _applications.any((a) => a.job.id == jobId);
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }

  /// Cleanup hook called from the Sign Out flow. Cancels the periodic
  /// refresh timer and clears the in-memory high-match alert dedup set
  /// so the next signed-in user starts with a clean slate. Persisted
  /// alerted ids stay on disk — they're keyed by job id, not user, and
  /// re-clearing on sign-in would re-alert old listings; if needed, the
  /// next user will simply have a few extra ids in the dedup set that
  /// they'd never have matched on anyway.
  void signOut() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _alertedHydrated = false;
    _alertedHighMatchIds = const {};
    highMatchAlerts.value = const [];
    _jobs = [];
    _applications = [];
    _searchResults = [];
    _hasMore = false;
    _page = 1;
    _lastLoadedAt = null;
    _wasGuestLoad = false;
    _wasGuestSession = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    highMatchAlerts.dispose();
    super.dispose();
  }
}

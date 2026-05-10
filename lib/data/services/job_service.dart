import '../models/application_model.dart';
import '../models/job_model.dart';
import 'api_client.dart';

/// Result scope returned by `POST /jobs/ai-search`. The backend
/// cascades through these widening filters when the primary one
/// produces zero hits — exposed so the UI can warn the user when
/// they're seeing stale data instead of a fresh match.
enum SearchScope { primary, extended, archived, empty }

extension SearchScopeX on SearchScope {
  static SearchScope fromString(String? raw) {
    switch (raw) {
      case 'extended':
        return SearchScope.extended;
      case 'archived':
        return SearchScope.archived;
      case 'empty':
        return SearchScope.empty;
      case 'primary':
      default:
        return SearchScope.primary;
    }
  }
}

class AiSearchResponse {
  final List<Job> jobs;
  final SearchScope scope;
  const AiSearchResponse({required this.jobs, required this.scope});
}

/// One page of `/jobs/matched`. `hasMore=true` means another `page+1`
/// fetch is worth attempting; `false` means the caller should stop
/// listening for scroll-end triggers.
class JobPage {
  final List<Job> jobs;
  final int page;
  final bool hasMore;
  final int total;
  const JobPage({
    required this.jobs,
    required this.page,
    required this.hasMore,
    required this.total,
  });
}

/// Job catalog endpoints under `/api/v1/jobs`.
class JobService {
  final ApiClient _api = ApiClient.instance;

  /// First page of the authenticated home feed: all ranked jobs sorted by
  /// match score desc. Threshold is 0 so a weakly-overlapping profile still
  /// sees jobs (the matcher already ranks best-first); the backend further
  /// falls back to recency when the candidate pool is empty.
  Future<JobPage> homeFeedPage({int page = 1, int limit = 20}) =>
      matchedFeedPage(page: page, limit: limit, threshold: 0);

  /// First page of the guest feed — same endpoint, backend recognises the
  /// guest JWT and returns recency-sorted public jobs across all domains.
  Future<JobPage> guestFeedPage({int page = 1, int limit = 20}) =>
      matchedFeedPage(page: page, limit: limit);

  /// Backwards-compatible single-shot fetch. Kept for callers that don't
  /// paginate (refresh, applications screen). Returns just the jobs list.
  Future<List<Job>> homeFeed({int threshold = 0, int limit = 50}) async =>
      (await matchedFeedPage(limit: limit, threshold: threshold)).jobs;

  Future<List<Job>> guestFeed({int limit = 50}) async =>
      (await matchedFeedPage(limit: limit)).jobs;

  Future<List<Job>> matchedFeed({
    int threshold = 50,
    int limit = 50,
    bool ai = false,
  }) async =>
      (await matchedFeedPage(limit: limit, threshold: threshold, ai: ai)).jobs;

  /// `GET /jobs/matched?page=&limit=&threshold=&ai=`. Returns a single
  /// page plus pagination metadata. For users the backend filters
  /// score >= threshold and sorts highest-first; for guests it returns
  /// recency-sorted public jobs.
  Future<JobPage> matchedFeedPage({
    int page = 1,
    int limit = 20,
    int threshold = 50,
    bool ai = false,
  }) async {
    final raw = await _api.get('jobs/matched', query: {
      'page': page,
      'limit': limit,
      'threshold': threshold,
      if (ai) 'ai': 'true',
    });
    final jobs = ApiClient.unwrapList(raw)
        .map((e) => Job.fromApiJson(e as Map<String, dynamic>))
        .toList();
    // Backend already sorts, but normalize defensively in case the
    // matcher fallback returns recency-ordered jobs without scores.
    jobs.sort((a, b) =>
        (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));

    final meta = (raw is Map<String, dynamic> && raw['meta'] is Map)
        ? raw['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final hasMore = meta['hasMore'] == true;
    final total = (meta['total'] as num?)?.toInt() ?? jobs.length;
    return JobPage(jobs: jobs, page: page, hasMore: hasMore, total: total);
  }

  /// `GET /jobs?q=&location=&jobType=&...`.
  Future<List<Job>> searchJobs({
    String? q,
    String? location,
    String? jobType,
    String? remoteType,
    List<String>? skills,
    int? minSalary,
    String? company,
    int page = 1,
    int limit = 20,
    String? sort,
  }) async {
    final raw = await _api.get('jobs', query: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (location != null && location.isNotEmpty) 'location': location,
      if (jobType != null && jobType.isNotEmpty) 'jobType': jobType,
      if (remoteType != null && remoteType.isNotEmpty) 'remoteType': remoteType,
      if (skills != null && skills.isNotEmpty) 'skills': skills.join(','),
      if (minSalary != null) 'minSalary': minSalary,
      if (company != null && company.isNotEmpty) 'company': company,
      'page': page,
      'limit': limit,
      if (sort != null) 'sort': sort,
    });
    return ApiClient.unwrapList(raw)
        .map((e) => Job.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /jobs/ai-search` — natural-language search powered by Claude.
  /// Returns jobs ranked by multi-field relevance across title, skills,
  /// description, responsibilities and company. Already-applied jobs are
  /// excluded by default so they don't pollute discovery.
  ///
  /// The backend cascades through three filter scopes when results are
  /// sparse — the [SearchScope] that was returned is exposed so the UI
  /// can warn the user when they're seeing stale or archived listings.
  Future<AiSearchResponse> aiSearchJobs({
    required String query,
    int limit = 30,
    bool excludeAppliedJobs = true,
  }) async {
    final raw = await _api.post('jobs/ai-search', body: {
      'query': query,
      'limit': limit,
      'excludeAppliedJobs': excludeAppliedJobs,
    });

    final jobs = ApiClient.unwrapList(raw)
        .map((e) => Job.fromApiJson(e as Map<String, dynamic>))
        .toList();

    SearchScope scope = SearchScope.primary;
    if (raw is Map<String, dynamic>) {
      final meta = raw['meta'];
      if (meta is Map<String, dynamic>) {
        scope = SearchScopeX.fromString(meta['scope'] as String?);
      }
    }
    return AiSearchResponse(jobs: jobs, scope: scope);
  }

  Future<Job?> getJobById(String id) async {
    if (id.isEmpty) return null;
    try {
      final raw = await _api.get('jobs/$id');
      final data = ApiClient.unwrapMap(raw);
      return Job.fromApiJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---- Saved jobs (server-persisted) ----

  Future<List<String>> fetchSavedJobIds() async {
    final raw = await _api.get('jobs/saved/ids');
    return ApiClient.unwrapList(raw).map((e) => e.toString()).toList();
  }

  Future<List<Job>> fetchSavedJobs({int page = 1, int limit = 50}) async {
    final raw =
        await _api.get('jobs/saved', query: {'page': page, 'limit': limit});
    return ApiClient.unwrapList(raw)
        .map((e) => Job.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveJob(String jobId) =>
      _api.post('jobs/$jobId/save');

  Future<void> unsaveJob(String jobId) =>
      _api.delete('jobs/$jobId/save');

  // ---- Backwards-compatible wrappers used by the existing UI ----

  Future<List<Job>> fetchJobs() => homeFeed();

  Future<List<Job>> fetchJobsByCategory(String category) async {
    final feed = await homeFeed();
    if (category == 'All') return feed;
    return feed.where((j) => j.category == category).toList();
  }

  Future<List<Job>> searchJobsLegacy(String query, {List<String>? filters}) {
    final params = (filters ?? const <String>[])
        .where((f) => f.isNotEmpty)
        .toList();
    String? jobType;
    String? remoteType;
    final skills = <String>[];
    for (final f in params) {
      final lc = f.toLowerCase();
      if (['full-time', 'part-time', 'contract', 'internship'].contains(lc)) {
        jobType = lc;
      } else if (['remote', 'hybrid', 'onsite', 'on-site'].contains(lc)) {
        remoteType = lc;
      } else {
        skills.add(f);
      }
    }
    return searchJobs(
      q: query,
      jobType: jobType,
      remoteType: remoteType,
      skills: skills.isEmpty ? null : skills,
    );
  }

  /// Existing screens still call this; delegates to the applied service.
  Future<List<JobApplication>> fetchApplications() async {
    // Imported lazily here to avoid a circular import in providers.
    final appliedRaw = await _api.get('applied', query: {'limit': 100});
    return ApiClient.unwrapList(appliedRaw)
        .map((e) => JobApplication.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }
}

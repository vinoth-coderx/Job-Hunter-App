import '../models/applicant_model.dart';
import 'api_client.dart';

class ApplicantsService {
  ApplicantsService._();
  static final ApplicantsService instance = ApplicantsService._();

  final ApiClient _api = ApiClient.instance;

  /// AI 2-line TL;DR of the applicant's resume. Cached server-side
  /// by hash(resumeText) — same resume re-opened across hirers is
  /// free of quota. The dynamic Map shape lets the UI consume the
  /// fields it cares about without a dedicated model class.
  Future<({
    String summary,
    List<String> strengths,
    int? yearsOfExperience,
    List<String> topRoles,
    bool usedAi,
    bool cached,
  })> resumeTldr({required String applicationId}) async {
    final raw = await _api.get('hirer/applicants/$applicationId/resume-tldr');
    final data = ApiClient.unwrapMap(raw);
    return (
      summary: (data['summary'] ?? '').toString(),
      strengths: (data['strengths'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      yearsOfExperience: (data['yearsOfExperience'] as num?)?.toInt(),
      topRoles: (data['topRoles'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      usedAi: data['usedAi'] as bool? ?? false,
      cached: data['cached'] as bool? ?? false,
    );
  }

  /// AI-drafted recruiter outreach for one (job, candidate) pair.
  /// Returns 2-3 short opener variants the hirer can paste into chat.
  /// Cached server-side by (jobId + candidateId + jobUpdatedAt) so the
  /// same candidate card never burns a fresh quota slot on re-open.
  Future<({List<({String label, String body})> drafts, bool cached})>
      draftOutreach({
    required String jobId,
    required String candidateUserId,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/$jobId/candidates/$candidateUserId/outreach',
      body: const {},
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['drafts'] as List?) ?? const [];
    final drafts = list
        .whereType<Map>()
        .map((e) {
          final m = e.cast<String, dynamic>();
          return (
            label: (m['label'] ?? 'Draft').toString(),
            body: (m['body'] ?? '').toString(),
          );
        })
        .where((d) => d.body.isNotEmpty)
        .toList();
    return (drafts: drafts, cached: data['cached'] as bool? ?? false);
  }

  /// AI-suggested "silver medalist" candidates from the hirer's PAST
  /// applicant pool — users who applied to one of the hirer's OTHER
  /// jobs and would fit THIS job, but haven't applied to it yet. Returns
  /// up to [limit] decorated suggestions with score + summary + skills.
  /// Costs one `candidate_suggest` quota slot for a fresh ranking; cache
  /// hits (same job + same pool) are free.
  Future<({List<SuggestedCandidate> items, int poolSize, bool cached})>
      suggestCandidates({
    required String jobId,
    int limit = 10,
    int poolSize = 50,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/$jobId/candidate-suggestions',
      body: {'limit': limit, 'poolSize': poolSize},
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['suggestions'] as List?) ?? const [];
    final items = list
        .whereType<Map>()
        .map((e) => SuggestedCandidate.fromJson(e.cast<String, dynamic>()))
        .toList();
    return (
      items: items,
      poolSize: (data['poolSize'] as num?)?.toInt() ?? items.length,
      cached: data['cached'] as bool? ?? false,
    );
  }

  /// AI-rank the most-recent applicants for a job. Returns the ranking list
  /// keyed by applicationId so callers can merge it into the existing
  /// applicant cards. Costs one quota slot per fresh ranking; cached
  /// repeats (same job + applicant set) are free.
  Future<List<RankedApplicant>> rankForJob({
    required String jobId,
    int limit = 25,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/$jobId/applicants/rank',
      body: {'limit': limit},
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['rankings'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => RankedApplicant.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<({List<Applicant> items, int total, String? jobTitle})> listForJob({
    required String jobId,
    String status = 'all',
    int? minMatch,
    String? skill,
    String sort = 'recent',
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _api.get(
      'hirer/jobs/$jobId/applicants',
      query: {
        'status': status,
        if (minMatch != null) 'minMatch': minMatch,
        if (skill != null && skill.isNotEmpty) 'skill': skill,
        'sort': sort,
        'page': page,
        'limit': limit,
      },
    );
    final list = ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Applicant.fromJson)
        .toList();
    int total = list.length;
    String? jobTitle;
    if (raw is Map<String, dynamic> && raw['meta'] is Map<String, dynamic>) {
      final meta = raw['meta'] as Map<String, dynamic>;
      if (meta['total'] is num) total = (meta['total'] as num).toInt();
      jobTitle = meta['jobTitle'] as String?;
    }
    return (items: list, total: total, jobTitle: jobTitle);
  }

  Future<({List<Applicant> items, int total})> listAll({
    String status = 'all',
    int? minMatch,
    String sort = 'recent',
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _api.get(
      'hirer/applicants',
      query: {
        'status': status,
        if (minMatch != null) 'minMatch': minMatch,
        'sort': sort,
        'page': page,
        'limit': limit,
      },
    );
    final list = ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Applicant.fromJson)
        .toList();
    int total = list.length;
    if (raw is Map<String, dynamic> && raw['meta'] is Map<String, dynamic>) {
      final meta = raw['meta'] as Map<String, dynamic>;
      if (meta['total'] is num) total = (meta['total'] as num).toInt();
    }
    return (items: list, total: total);
  }

  Future<Applicant> getDetail(String id) async {
    final raw = await _api.get('hirer/applicants/$id');
    return Applicant.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<String> updateStatus({
    required String id,
    required String status,
    String? note,
    String? rejectionReason,
  }) async {
    final raw = await _api.put(
      'hirer/applicants/$id/status',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (rejectionReason != null && rejectionReason.isNotEmpty)
          'rejectionReason': rejectionReason,
      },
    );
    return (ApiClient.unwrapMap(raw)['status'] as String?) ?? status;
  }

  Future<void> updateNotes({required String id, required String notes}) async {
    await _api.put('hirer/applicants/$id/notes', body: {'hirerNotes': notes});
  }

  Future<({String jobId, String? jobTitle, Map<String, List<Applicant>> columns})>
      kanbanForJob(String jobId) async {
    final raw = await _api.get('hirer/jobs/$jobId/kanban');
    final data = ApiClient.unwrapMap(raw);
    final cols = (data['columns'] as Map<String, dynamic>?) ?? const {};
    final out = <String, List<Applicant>>{};
    for (final entry in cols.entries) {
      final list = (entry.value as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Applicant.fromJson)
              .toList() ??
          const <Applicant>[];
      out[entry.key] = list;
    }
    return (
      jobId: (data['jobId'] ?? '').toString(),
      jobTitle: data['jobTitle'] as String?,
      columns: out,
    );
  }

  Future<({int matched, int modified})> bulkUpdate({
    required List<String> ids,
    required String status,
    String? note,
  }) async {
    final raw = await _api.post('hirer/applicants/bulk-action', body: {
      'applicationIds': ids,
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final m = ApiClient.unwrapMap(raw);
    return (
      matched: (m['matched'] as int?) ?? 0,
      modified: (m['modified'] as int?) ?? 0,
    );
  }
}

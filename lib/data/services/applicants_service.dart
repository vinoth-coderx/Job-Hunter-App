import '../models/applicant_model.dart';
import 'api_client.dart';

class ApplicantsService {
  ApplicantsService._();
  static final ApplicantsService instance = ApplicantsService._();

  final ApiClient _api = ApiClient.instance;

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

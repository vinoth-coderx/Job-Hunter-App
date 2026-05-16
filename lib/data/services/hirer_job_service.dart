import '../models/hirer_job_model.dart';
import 'api_client.dart';

class HirerJobService {
  HirerJobService._();
  static final HirerJobService instance = HirerJobService._();

  final ApiClient _api = ApiClient.instance;

  Future<HirerJob> create(HirerJobInput input) async {
    final raw = await _api.post('hirer/jobs', body: input.toJson());
    return HirerJob.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<HirerJob> update(String id, HirerJobInput input) async {
    final body = input.toJson()..remove('saveAsDraft');
    final raw = await _api.put('hirer/jobs/$id', body: body);
    return HirerJob.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<({List<HirerJob> jobs, int total})> listMine({
    String status = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _api.get(
      'hirer/jobs',
      query: {'status': status, 'page': page, 'limit': limit},
    );
    final list = ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(HirerJob.fromJson)
        .toList();
    int total = list.length;
    if (raw is Map<String, dynamic>) {
      final meta = raw['meta'];
      if (meta is Map<String, dynamic> && meta['total'] is num) {
        total = (meta['total'] as num).toInt();
      }
    }
    return (jobs: list, total: total);
  }

  Future<HirerJob> getOne(String id) async {
    final raw = await _api.get('hirer/jobs/$id');
    return HirerJob.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<String> updateStatus(String id, String status) async {
    final raw = await _api.put('hirer/jobs/$id/status', body: {'status': status});
    return (ApiClient.unwrapMap(raw)['status'] as String?) ?? status;
  }

  Future<void> delete(String id) async {
    await _api.delete('hirer/jobs/$id');
  }

  Future<Map<String, dynamic>> analytics(String id) async {
    final raw = await _api.get('hirer/jobs/$id/analytics');
    return ApiClient.unwrapMap(raw);
  }

  /// Hirer-side appeal against an auto/admin moderation rejection. Returns
  /// the new appeal status from the backend (always 'pending' on success,
  /// since the admin reviews asynchronously).
  Future<String> appealModeration({
    required String jobId,
    required String reason,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/$jobId/moderation/appeal',
      body: {'reason': reason},
    );
    final data = ApiClient.unwrapMap(raw);
    return (data['appealStatus'] as String?) ?? 'pending';
  }

  /// AI polish for the JD draft. Returns the rewritten body + a short
  /// list of changes applied. Cached server-side (24h) by hash(title +
  /// description), so re-clicking on an unchanged draft is free.
  Future<({String polished, List<String> changes, bool cached, bool usedAi})>
      polishJd({
    required String title,
    required String description,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/polish',
      body: {'title': title, 'description': description},
    );
    final data = ApiClient.unwrapMap(raw);
    return (
      polished: (data['polished'] ?? description).toString(),
      changes: (data['changes'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[],
      cached: data['cached'] as bool? ?? false,
      usedAi: data['usedAi'] as bool? ?? false,
    );
  }

  /// AI screening-question generator. Returns 3-5 ready-to-edit questions
  /// in `IScreeningQuestion` shape so the post-job editor can drop them
  /// straight into its working list. Cached server-side by (title +
  /// skills + description prefix), so re-clicking on an unchanged draft
  /// is free of quota.
  Future<({List<Map<String, dynamic>> questions, bool usedAi, bool cached})>
      generateScreeningQuestions({
    required String title,
    required String description,
    required List<String> skills,
  }) async {
    final raw = await _api.post(
      'hirer/jobs/screening-questions',
      body: {
        'title': title,
        'description': description,
        'skills': skills,
      },
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['questions'] as List?) ?? const [];
    final questions = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    return (
      questions: questions,
      usedAi: data['usedAi'] as bool? ?? false,
      cached: data['cached'] as bool? ?? false,
    );
  }
}

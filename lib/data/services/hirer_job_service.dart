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
}

import '../models/alert_model.dart';
import 'api_client.dart';

/// Backend-persisted alerts under `/api/v1/alerts`.
class AlertService {
  final ApiClient _api = ApiClient.instance;

  Future<List<JobAlert>> list() async {
    final raw = await _api.get('alerts');
    return ApiClient.unwrapList(raw)
        .map((e) => JobAlert.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobAlert> create({
    String? label,
    required String query,
    List<String> filters = const [],
    String? location,
    String? sort,
    bool active = true,
  }) async {
    final raw = await _api.post('alerts', body: {
      if (label != null && label.isNotEmpty) 'label': label,
      'query': query,
      'filters': filters,
      if (location != null && location.isNotEmpty) 'location': location,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      'active': active,
    });
    return JobAlert.fromApiJson(ApiClient.unwrapMap(raw));
  }

  Future<JobAlert> update(
    String id, {
    String? label,
    String? query,
    List<String>? filters,
    String? location,
    String? sort,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label,
      if (query != null) 'query': query,
      if (filters != null) 'filters': filters,
      if (location != null) 'location': location,
      if (sort != null) 'sort': sort,
      if (active != null) 'active': active,
    };
    final raw = await _api.patch('alerts/$id', body: body);
    return JobAlert.fromApiJson(ApiClient.unwrapMap(raw));
  }

  Future<void> remove(String id) async {
    await _api.delete('alerts/$id');
  }
}

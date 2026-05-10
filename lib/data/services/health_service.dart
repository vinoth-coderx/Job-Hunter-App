import 'api_client.dart';

/// Health probe endpoints under `/api/v1/health`. Public — no auth needed.
class HealthService {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> basic() async {
    final raw = await _api.get('health', auth: false);
    return ApiClient.unwrapMap(raw);
  }

  Future<Map<String, dynamic>> liveness() async {
    final raw = await _api.get('health/live', auth: false);
    return ApiClient.unwrapMap(raw);
  }

  Future<Map<String, dynamic>> readiness() async {
    final raw = await _api.get('health/ready', auth: false);
    return ApiClient.unwrapMap(raw);
  }

  Future<Map<String, dynamic>> deep() async {
    final raw = await _api.get('health/deep', auth: false);
    return ApiClient.unwrapMap(raw);
  }
}

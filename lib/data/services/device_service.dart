import 'api_client.dart';

/// Push device registration under `/api/v1/devices`. Only meaningful
/// once the app has an FCM token to register.
class DeviceService {
  final ApiClient _api = ApiClient.instance;

  Future<void> registerToken({
    required String token,
    required String platform, // 'ios' | 'android' | 'web'
    String? appVersion,
  }) async {
    await _api.post('devices/token', body: {
      'token': token,
      'platform': platform,
      if (appVersion != null && appVersion.isNotEmpty) 'appVersion': appVersion,
    });
  }

  Future<void> unregisterToken(String token) async {
    await _api.delete('devices/token/$token');
  }
}

import 'api_client.dart';

class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> status() async {
    final res = await _api.get('/hirer/verification/status');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> submitGst(String gstNumber) async {
    await _api.post('/hirer/verification/gst', body: {'gstNumber': gstNumber});
  }

  Future<void> submitDomainEmail(String email) async {
    await _api.post('/hirer/verification/domain-email', body: {'email': email});
  }

  Future<void> confirmDomainEmail(String email, String code) async {
    await _api.post(
      '/hirer/verification/domain-email/confirm',
      body: {'email': email, 'code': code},
    );
  }

  Future<Map<String, dynamic>> submitWebsite(String website) async {
    final res = await _api.post(
      '/hirer/verification/website',
      body: {'website': website},
    );
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> submitLinkedin(String url) async {
    await _api.post(
      '/hirer/verification/linkedin',
      body: {'linkedinUrl': url},
    );
  }
}

import 'api_client.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> create({
    required String subjectType, // 'job' | 'recruiter' | 'message' | 'company' | 'review'
    required String subjectId,
    required String reason,
    String? description,
    List<String>? evidenceUrls,
  }) async {
    final res = await _api.post('/reports', body: {
      'subjectType': subjectType,
      'subjectId': subjectId,
      'reason': reason,
      if (description != null) 'description': description,
      if (evidenceUrls != null) 'evidenceUrls': evidenceUrls,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> mine() async {
    final res = await _api.get('/reports/mine');
    return List<Map<String, dynamic>>.from(
      (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
}

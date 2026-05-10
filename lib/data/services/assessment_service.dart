import '../models/assessment_model.dart';
import 'api_client.dart';

class AssessmentService {
  AssessmentService._();
  static final AssessmentService instance = AssessmentService._();

  final ApiClient _api = ApiClient.instance;

  Future<AssessmentSession> start({
    required String skill,
    String level = 'intermediate',
    int? count,
  }) async {
    final raw = await _api.post('skill-assessments/start', body: {
      'skill': skill,
      'level': level,
      if (count != null) 'count': count,
    });
    return AssessmentSession.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AssessmentResult> submit({
    required String id,
    required List<({int questionIndex, int selectedIndex})> answers,
    required int timeTakenSeconds,
  }) async {
    final raw = await _api.post('skill-assessments/$id/submit', body: {
      'answers': answers
          .map((a) => {
                'questionIndex': a.questionIndex,
                'selectedIndex': a.selectedIndex,
              })
          .toList(),
      'timeTakenSeconds': timeTakenSeconds,
    });
    return AssessmentResult.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<List<AssessmentSummary>> listMine() async {
    final raw = await _api.get('skill-assessments');
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(AssessmentSummary.fromJson)
        .toList();
  }
}

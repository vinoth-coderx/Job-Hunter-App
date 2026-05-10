import '../models/profile_optimizer_model.dart';
import '../models/skill_gap_model.dart';
import 'api_client.dart';

class AiCoverLetterResult {
  final String letter;
  final bool usedAi;
  const AiCoverLetterResult({required this.letter, required this.usedAi});
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final ApiClient _api = ApiClient.instance;

  Future<AiCoverLetterResult> generateCoverLetter({
    required String jobId,
    String tone = 'professional',
    String? baseTemplate,
  }) async {
    final raw = await _api.post('ai/cover-letter', body: {
      'jobId': jobId,
      'tone': tone,
      if (baseTemplate != null && baseTemplate.isNotEmpty)
        'baseTemplate': baseTemplate,
    });
    final data = ApiClient.unwrapMap(raw);
    return AiCoverLetterResult(
      letter: (data['letter'] ?? '').toString(),
      usedAi: data['usedAi'] as bool? ?? false,
    );
  }

  Future<ProfileOptimizationResult> profileOptimizer() async {
    final raw = await _api.get('ai/profile-optimizer');
    return ProfileOptimizationResult.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<SkillGapResult> skillGap({
    required String role,
    String? city,
  }) async {
    final raw = await _api.post('ai/skill-gap', body: {
      'role': role,
      if (city != null && city.isNotEmpty) 'city': city,
    });
    return SkillGapResult.fromJson(ApiClient.unwrapMap(raw));
  }
}

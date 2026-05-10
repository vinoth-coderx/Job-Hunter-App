import '../models/ai_combined_models.dart';
import '../models/ai_field_suggestion.dart';
import '../models/ai_quota_model.dart';
import '../models/profile_optimizer_model.dart';
import '../models/skill_gap_model.dart';
import 'api_client.dart';

class AiCoverLetterResult {
  final String letter;
  final bool usedAi;
  const AiCoverLetterResult({required this.letter, required this.usedAi});
}

/// Wraps any combined-endpoint response that returns both `data` and
/// `quota`. Lets callers update the quota provider on every AI call
/// without an extra round-trip to /ai/quota.
class AiResponse<T> {
  final T? data;
  final AiQuota? quota;
  const AiResponse({this.data, this.quota});
}

/// Thrown when the backend returns 429 with a quota payload. Carries the
/// quota snapshot so the UI can render the countdown banner immediately.
class AiQuotaExceededException implements Exception {
  final String reason; // 'user' | 'global'
  final AiQuota quota;
  final String message;
  const AiQuotaExceededException({
    required this.reason,
    required this.quota,
    required this.message,
  });

  @override
  String toString() => message;
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final ApiClient _api = ApiClient.instance;

  AiQuota? _quotaFromResponse(Map<String, dynamic> raw) {
    final q = raw['quota'];
    if (q is Map<String, dynamic>) return AiQuota.fromJson(q);
    if (q is Map) return AiQuota.fromJson(q.cast<String, dynamic>());
    return null;
  }

  /// Wrap a POST that may throw a quota error. Translates the backend
  /// 429 payload into AiQuotaExceededException so callers can branch
  /// on quota separately from generic errors.
  Future<Map<String, dynamic>> _aiPost(String path, Map<String, dynamic> body) async {
    try {
      final raw = await _api.post(path, body: body);
      return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (e) {
      _maybeThrowQuota(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _aiGet(String path, {Map<String, String>? query}) async {
    try {
      final raw = await _api.get(path, query: query);
      return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (e) {
      _maybeThrowQuota(e);
      rethrow;
    }
  }

  /// Inspect any error for a backend 429 quota payload. ApiClient typically
  /// surfaces error responses as exceptions whose toString() contains the
  /// JSON body — we look for the quota marker and rethrow as a typed error.
  void _maybeThrowQuota(Object err) {
    final s = err.toString();
    if (!s.contains('"quota"')) return;
    // Best-effort extraction; if anything fails we just leave the original.
    final reasonMatch = RegExp(r'"reason"\s*:\s*"(user|global)"').firstMatch(s);
    final reason = reasonMatch?.group(1) ?? 'user';
    final usedM = RegExp(r'"userUsed"\s*:\s*(\d+)').firstMatch(s);
    final limitM = RegExp(r'"userLimit"\s*:\s*(\d+)').firstMatch(s);
    final remM = RegExp(r'"userRemaining"\s*:\s*(\d+)').firstMatch(s);
    final gUsedM = RegExp(r'"globalUsed"\s*:\s*(\d+)').firstMatch(s);
    final gLimitM = RegExp(r'"globalLimit"\s*:\s*(\d+)').firstMatch(s);
    final gRemM = RegExp(r'"globalRemaining"\s*:\s*(\d+)').firstMatch(s);
    final resetIsoM = RegExp(r'"resetsAtIso"\s*:\s*"([^"]+)"').firstMatch(s);
    final resetSecM = RegExp(r'"resetsInSec"\s*:\s*(\d+)').firstMatch(s);
    final quota = AiQuota(
      userUsed: int.tryParse(usedM?.group(1) ?? '') ?? 0,
      userLimit: int.tryParse(limitM?.group(1) ?? '') ?? 30,
      userRemaining: int.tryParse(remM?.group(1) ?? '') ?? 0,
      globalUsed: int.tryParse(gUsedM?.group(1) ?? '') ?? 0,
      globalLimit: int.tryParse(gLimitM?.group(1) ?? '') ?? 400,
      globalRemaining: int.tryParse(gRemM?.group(1) ?? '') ?? 0,
      resetsAt: DateTime.tryParse(resetIsoM?.group(1) ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      resetsInSec: int.tryParse(resetSecM?.group(1) ?? '') ?? 0,
    );
    throw AiQuotaExceededException(
      reason: reason,
      quota: quota,
      message: reason == 'global'
          ? 'Daily AI limit reached. Subscribe to continue.'
          : 'Daily AI limit reached. Subscribe to continue.',
    );
  }

  // ── Existing endpoints ─────────────────────────────────────────

  /// Generates an AI cover letter. Open to all signed-in users — daily
  /// AI quota gates the free tier (cache hits don't count). Throws
  /// [AiQuotaExceededException] when the user is out of quota.
  Future<AiResponse<AiCoverLetterResult>> generateCoverLetter({
    required String jobId,
    String tone = 'professional',
    String? baseTemplate,
  }) async {
    final raw = await _aiPost('ai/cover-letter', {
      'jobId': jobId,
      'tone': tone,
      if (baseTemplate != null && baseTemplate.isNotEmpty)
        'baseTemplate': baseTemplate,
    });
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiCoverLetterResult(
            letter: (dataNode['letter'] ?? '').toString(),
            usedAi: dataNode['usedAi'] as bool? ?? false,
          )
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<ProfileOptimizationResult> profileOptimizer({bool refresh = false}) async {
    final raw = await _api.get(
      'ai/profile-optimizer',
      query: refresh ? {'refresh': '1'} : null,
    );
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

  // ── New combined / quota endpoints ─────────────────────────────

  Future<AiQuota> quotaStatus() async {
    final raw = await _api.get('ai/quota');
    return AiQuota.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AiResponse<AiResumeOnboarding>> resumeOnboard() async {
    final raw = await _aiPost('users/resume/onboard', const {});
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiResumeOnboarding.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<AiResponse<AiJobInsight>> jobInsight({required String jobId}) async {
    final raw = await _aiPost('ai/job-insight', {'jobId': jobId});
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiJobInsight.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<AiResponse<AiForYou>> forYou({bool refresh = false}) async {
    final raw = await _aiGet(
      'ai/for-you',
      query: refresh ? {'refresh': '1'} : null,
    );
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiForYou.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<AiResponse<AiChatResponse>> chatSend(String message) async {
    final raw = await _aiPost('ai/chat', {'message': message});
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiChatResponse.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<List<AiChatTurn>> chatHistory() async {
    final raw = await _api.get('ai/chat');
    final data = ApiClient.unwrapMap(raw);
    final list = (data['history'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => AiChatTurn.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> chatClear() async {
    await _api.delete('ai/chat');
  }

  /// Ask the backend to generate a concrete value for one profile field.
  /// Used by Profile Coach's "Generate" button when a suggestion arrived
  /// without a pre-populated `suggestedValue`. Counts as one quota slot.
  Future<AiResponse<AiFieldSuggestion>> profileFieldSuggest({
    required String field,
  }) async {
    final raw = await _aiPost('ai/profile-field-suggest', {'field': field});
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiFieldSuggestion.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  Future<AiResponse<AiGeneratedJd>> generateJd({
    required String role,
    int? experienceMinYears,
    int? experienceMaxYears,
    String? location,
    String? remoteType,
    String? jobType,
    List<String>? keywords,
    String? toneHint,
  }) async {
    final raw = await _aiPost('hirer/jobs/generate', {
      'role': role,
      if (experienceMinYears != null) 'experienceMinYears': experienceMinYears,
      if (experienceMaxYears != null) 'experienceMaxYears': experienceMaxYears,
      if (location != null && location.isNotEmpty) 'location': location,
      if (remoteType != null) 'remoteType': remoteType,
      if (jobType != null) 'jobType': jobType,
      if (keywords != null && keywords.isNotEmpty) 'keywords': keywords,
      if (toneHint != null) 'toneHint': toneHint,
    });
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AiGeneratedJd.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'storage_service.dart';
import '../models/ai_combined_models.dart';
import '../models/ai_field_suggestion.dart';
import '../models/ai_quota_model.dart';
import '../models/ats_analysis_model.dart';
import '../models/profile_optimizer_model.dart';
import '../models/resume_rewrite_model.dart';
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

/// Sealed-ish hierarchy for events emitted by `AiService.chatStream`.
/// Concrete classes — Dart 3 `sealed` would be cleaner but the wider
/// codebase still leans on simple class hierarchies.
abstract class StreamChatEvent {
  const StreamChatEvent();
}

/// Incremental text delta. Append `delta` to the in-flight bubble.
class StreamChatChunk extends StreamChatEvent {
  final String delta;
  const StreamChatChunk(this.delta);
}

/// Final event — the model finished producing the reply. `turnId` is
/// the stable identifier for thumbs feedback.
class StreamChatDone extends StreamChatEvent {
  final String reply;
  final String turnId;
  const StreamChatDone({required this.reply, required this.turnId});
}

/// Initial quota snapshot pushed by the server before the first chunk.
class StreamChatQuota extends StreamChatEvent {
  final AiQuota quota;
  const StreamChatQuota(this.quota);
}

/// Mid-stream failure. The bubble keeps whatever deltas already arrived
/// and the UI can surface a retry banner without tearing down state.
class StreamChatError extends StreamChatEvent {
  final String message;
  const StreamChatError(this.message);
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

  /// Server-Sent Events streaming chat. Yields incremental deltas as
  /// the model produces them, then a final event with the assembled
  /// reply + a stable turn id so the chat UI can attach feedback.
  ///
  /// Quota errors land as [AiQuotaExceededException] BEFORE the stream
  /// opens (the backend rejects with 429 + JSON body). Mid-stream
  /// failures yield a [StreamChatError] event so the UI can render
  /// a retry banner without tearing down the bubble.
  Stream<StreamChatEvent> chatStream(String message) async* {
    final base = _api.baseUrl;
    final cleanBase = base.endsWith('/') ? base : '$base/';
    final uri = Uri.parse('${cleanBase}ai/chat/stream');
    final token = StorageService.getAccessToken() ?? '';

    final req = http.Request('POST', uri)
      ..headers['Accept'] = 'text/event-stream'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Cache-Control'] = 'no-cache';
    if (token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    req.body = jsonEncode({'message': message});

    final client = http.Client();
    try {
      final res = await client.send(req);
      if (res.statusCode == 429) {
        // Quota exhausted — drain the body to extract the snapshot
        // and rethrow as the typed exception the rest of the chat
        // surface already understands.
        final body = await res.stream.bytesToString();
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['quota'] is Map) {
            final q = parsed['quota'] as Map;
            throw AiQuotaExceededException(
              reason: (parsed['reason'] ?? 'user').toString(),
              quota: AiQuota.fromJson(q.cast<String, dynamic>()),
              message: (parsed['message'] ?? 'AI quota exhausted').toString(),
            );
          }
        } catch (_) {
          // Fall through to generic
        }
        throw Exception('AI quota exhausted (429)');
      }
      if (res.statusCode != 200) {
        final body = await res.stream.bytesToString();
        throw Exception('Stream failed: ${res.statusCode} $body');
      }

      // SSE framing: events are separated by a blank line. Each event
      // can have an `event:` line and one or more `data:` lines. Here
      // we expect one `data:` per event so the parser is line-by-line.
      final lines = res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      String? evt;
      String dataBuf = '';

      await for (final line in lines) {
        if (line.isEmpty) {
          if (dataBuf.isNotEmpty && evt != null) {
            yield* _parseStreamEvent(evt, dataBuf);
          }
          evt = null;
          dataBuf = '';
          continue;
        }
        if (line.startsWith('event:')) {
          evt = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataBuf = line.substring(5).trim();
        }
      }
      // Flush trailing event if the stream ended without a final blank.
      if (dataBuf.isNotEmpty && evt != null) {
        yield* _parseStreamEvent(evt, dataBuf);
      }
    } finally {
      client.close();
    }
  }

  Stream<StreamChatEvent> _parseStreamEvent(String evt, String data) async* {
    Map<String, dynamic>? json;
    try {
      final parsed = jsonDecode(data);
      if (parsed is Map<String, dynamic>) json = parsed;
    } catch (_) {
      return;
    }
    if (json == null) return;
    switch (evt) {
      case 'chunk':
        final delta = (json['delta'] ?? '').toString();
        if (delta.isNotEmpty) yield StreamChatChunk(delta);
        break;
      case 'done':
        yield StreamChatDone(
          reply: (json['reply'] ?? '').toString(),
          turnId: (json['turnId'] ?? '').toString(),
        );
        break;
      case 'quota':
        yield StreamChatQuota(AiQuota.fromJson(json));
        break;
      case 'error':
        yield StreamChatError((json['message'] ?? 'Stream error').toString());
        break;
    }
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

  /// ATS resume score. `jobId` null = generic ATS pass; otherwise scored
  /// against that job's keyword set. Costs 1 quota slot for a fresh
  /// analysis; cached repeats are free. Throws [AiQuotaExceededException]
  /// when out of quota.
  Future<AiResponse<AtsAnalysisResult>> atsScore({
    String? jobId,
    bool refresh = false,
  }) async {
    final raw = await _aiPost('ai/ats-score', {
      if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
      if (refresh) 'refresh': true,
    });
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? AtsAnalysisResult.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  /// Rewrite a single resume bullet / summary / achievement line via Groq.
  /// Returns the primary rewrite plus 0-3 alternative phrasings.
  /// Throws [AiQuotaExceededException] when out of quota; cache hits are
  /// free of quota so the same input never burns a slot twice.
  Future<AiResponse<ResumeRewriteResult>> resumeRewrite({
    required String kind, // 'bullet' | 'summary' | 'achievement'
    required String text,
    String? role,
    String? tone,
  }) async {
    final raw = await _aiPost('ai/resume/rewrite', {
      'kind': kind,
      'text': text,
      if (role != null && role.isNotEmpty) 'role': role,
      if (tone != null && tone.isNotEmpty) 'tone': tone,
    });
    final dataNode = raw['data'];
    final data = (dataNode is Map<String, dynamic>)
        ? ResumeRewriteResult.fromJson(dataNode)
        : null;
    return AiResponse(data: data, quota: _quotaFromResponse(raw));
  }

  /// Per-user AI usage history. Returns the most recent rows (default
  /// 50, max 200) for the calling user. Powers the Flutter "my AI
  /// activity" page so seekers can see what they've consumed without
  /// digging through the admin dashboard.
  Future<List<({
    String feature,
    String provider,
    int totalTokens,
    double estimatedCostUsd,
    bool cacheHit,
    DateTime createdAt,
  })>> usageHistory({int limit = 50}) async {
    final raw = await _api.get(
      'ai/usage/history',
      query: {'limit': '$limit'},
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['items'] as List?) ?? const [];
    return list.whereType<Map>().map((e) {
      final m = e.cast<String, dynamic>();
      return (
        feature: (m['feature'] ?? 'unknown').toString(),
        provider: (m['provider'] ?? 'unknown').toString(),
        totalTokens: (m['totalTokens'] as num?)?.toInt() ?? 0,
        estimatedCostUsd:
            (m['estimatedCostUsd'] as num?)?.toDouble() ?? 0.0,
        cacheHit: m['cacheHit'] as bool? ?? false,
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
    }).toList();
  }

  /// Persist a thumbs rating on an AI output. Generic across features
  /// — pass the producing surface as `feature` and a stable identifier
  /// (chat turn id, applicationId, jobId, etc.) as `refId`. Latest
  /// rating wins on the backend (upsert). Best-effort: failures here
  /// are intentionally swallowed so a flaky network never strands the
  /// user with a half-rated card.
  Future<void> sendFeedback({
    required String feature,
    required String refId,
    required int rating, // -1 | 0 | 1
    String? note,
  }) async {
    try {
      await _api.post('ai/feedback', body: {
        'feature': feature,
        'refId': refId,
        'rating': rating,
        if (note != null && note.isNotEmpty) 'note': note,
      });
    } catch (_) {
      // Swallow — feedback is best-effort. The optimistic UI flips
      // back if the user re-taps, no server reconciliation needed.
    }
  }

  /// Extract a normalised list of skills from arbitrary text (e.g. a JD
  /// the seeker pasted in). Backend caches 7d server-side and the call
  /// is weight 0, so repeated invocations on the same text never debit
  /// quota.
  Future<({List<String> skills, bool usedAi, bool cached})> extractSkills(
    String text,
  ) async {
    final raw = await _aiPost('ai/skills/extract', {'text': text});
    final node = raw['data'];
    if (node is! Map<String, dynamic>) {
      return (skills: const <String>[], usedAi: false, cached: false);
    }
    final skills = (node['skills'] as List?)
            ?.map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    return (
      skills: skills,
      usedAi: node['usedAi'] as bool? ?? false,
      cached: node['cached'] as bool? ?? false,
    );
  }

  Future<List<AtsHistoryEntry>> atsHistory({int limit = 10}) async {
    final raw = await _aiGet(
      'ai/ats-score/history',
      query: {'limit': '$limit'},
    );
    final data = ApiClient.unwrapMap(raw);
    final list = (data['history'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => AtsHistoryEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
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

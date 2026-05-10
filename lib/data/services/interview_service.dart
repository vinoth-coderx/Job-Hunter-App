import '../models/interview_model.dart';
import 'api_client.dart';

class InterviewService {
  InterviewService._();
  static final InterviewService instance = InterviewService._();

  final ApiClient _api = ApiClient.instance;

  // ── Hirer ────────────────────────────────────────────────────────

  Future<Interview> schedule({
    required String applicationId,
    required String round,
    required String interviewType,
    required DateTime scheduledAt,
    int durationMinutes = 45,
    String? meetingLink,
    String? meetingPlatform,
    String? location,
    String? notesToCandidate,
  }) async {
    final raw = await _api.post('interviews/hirer', body: {
      'applicationId': applicationId,
      'round': round,
      'interviewType': interviewType,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      if (meetingLink != null && meetingLink.isNotEmpty) 'meetingLink': meetingLink,
      if (meetingPlatform != null && meetingPlatform.isNotEmpty)
        'meetingPlatform': meetingPlatform,
      if (location != null && location.isNotEmpty) 'location': location,
      if (notesToCandidate != null && notesToCandidate.isNotEmpty)
        'notesToCandidate': notesToCandidate,
    });
    return Interview.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<List<Interview>> listForHirer({String? status}) async {
    final raw = await _api.get('interviews/hirer', query: {
      if (status != null) 'status': status,
    });
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Interview.fromJson)
        .toList();
  }

  Future<Interview> update({
    required String id,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? meetingLink,
    String? location,
    String? status,
  }) async {
    final raw = await _api.put('interviews/hirer/$id', body: {
      if (scheduledAt != null)
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (meetingLink != null) 'meetingLink': meetingLink,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
    });
    return Interview.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<void> cancel(String id) =>
      _api.delete('interviews/hirer/$id');

  // ── Seeker ───────────────────────────────────────────────────────

  Future<List<Interview>> listForSeeker() async {
    final raw = await _api.get('interviews/seeker');
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Interview.fromJson)
        .toList();
  }

  Future<void> confirm(String id) =>
      _api.put('interviews/seeker/$id/confirm');
}

import '../models/application_model.dart';
import '../models/job_model.dart';
import 'api_client.dart';

/// Application tracker endpoints under `/api/v1/applied`.
class AppliedService {
  final ApiClient _api = ApiClient.instance;

  Future<JobApplication> apply({
    required String jobId,
    String? notes,
  }) async {
    final raw = await _api.post('applied', body: {
      'jobId': jobId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final data = ApiClient.unwrapMap(raw);
    return JobApplication.fromApiJson(data);
  }

  /// Native one-click apply for in-app job postings.
  /// Differs from [apply] by requiring a resume on the seeker profile +
  /// answering any required screening questions on the job.
  Future<JobApplication> quickApply({
    required String jobId,
    String? quickNote,
    List<({String question, String answer})>? screeningAnswers,
  }) async {
    final raw = await _api.post('applied/quick-apply', body: {
      'jobId': jobId,
      if (quickNote != null && quickNote.isNotEmpty) 'quickNote': quickNote,
      if (screeningAnswers != null && screeningAnswers.isNotEmpty)
        'screeningAnswers': screeningAnswers
            .map((a) => {'question': a.question, 'answer': a.answer})
            .toList(),
    });
    final data = ApiClient.unwrapMap(raw);
    return JobApplication.fromApiJson(data);
  }

  Future<List<JobApplication>> list({
    ApplicationStatus? status,
    int page = 1,
    int limit = 50,
  }) async {
    final raw = await _api.get('applied', query: {
      if (status != null) 'status': _statusToApi(status),
      'page': page,
      'limit': limit,
    });
    return ApiClient.unwrapList(raw)
        .map((e) => JobApplication.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> stats() async {
    final raw = await _api.get('applied/stats');
    return ApiClient.unwrapMap(raw);
  }

  Future<JobApplication> update(
    String id, {
    ApplicationStatus? status,
    String? notes,
    DateTime? followUpDate,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = _statusToApi(status);
    if (notes != null) body['notes'] = notes;
    if (followUpDate != null) {
      body['followUpDate'] = followUpDate.toUtc().toIso8601String();
    }
    final raw = await _api.patch('applied/$id', body: body);
    final data = ApiClient.unwrapMap(raw);
    return JobApplication.fromApiJson(data);
  }

  Future<void> remove(String id) async {
    await _api.delete('applied/$id');
  }

  static String _statusToApi(ApplicationStatus s) {
    switch (s) {
      case ApplicationStatus.applied:
        return 'applied';
      case ApplicationStatus.viewed:
        return 'viewed';
      case ApplicationStatus.shortlisted:
        return 'shortlisted';
      case ApplicationStatus.interview:
        return 'interview';
      case ApplicationStatus.offered:
        return 'offer';
      case ApplicationStatus.rejected:
        return 'rejected';
      case ApplicationStatus.withdrawn:
        return 'withdrawn';
    }
  }
}

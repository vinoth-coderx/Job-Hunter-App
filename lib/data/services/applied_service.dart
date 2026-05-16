import '../models/application_model.dart';
import '../models/job_model.dart';
import 'api_client.dart';

/// Wraps the response from an apply call so callers can sync the seeker's
/// coin wallet from the same round-trip. `coinsAwarded` is 0 when the
/// daily cap (or duplicate idempotency key) suppressed the grant —
/// `coinsBalance` is still the authoritative current balance.
class ApplyResult {
  final JobApplication application;
  final int coinsAwarded;
  final int coinsBalance;
  const ApplyResult({
    required this.application,
    required this.coinsAwarded,
    required this.coinsBalance,
  });
}

/// Application tracker endpoints under `/api/v1/applied`.
class AppliedService {
  final ApiClient _api = ApiClient.instance;

  ApplyResult _toApplyResult(dynamic raw) {
    final root = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : ApiClient.unwrapMap(raw);
    return ApplyResult(
      application: JobApplication.fromApiJson(data),
      coinsAwarded: (root['coinsAwarded'] as num?)?.toInt() ?? 0,
      coinsBalance: (root['coinsBalance'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ApplyResult> apply({
    required String jobId,
    String? notes,
  }) async {
    final raw = await _api.post('applied', body: {
      'jobId': jobId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return _toApplyResult(raw);
  }

  /// Native one-click apply for in-app job postings.
  /// Differs from [apply] by requiring a resume on the seeker profile +
  /// answering any required screening questions on the job.
  Future<ApplyResult> quickApply({
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
    return _toApplyResult(raw);
  }

  /// Lists the seeker's applications.
  ///
  /// [type] filters the underlying records:
  ///   - `'native'`   → in-app Easy Apply only (one_click / custom_form /
  ///                    auto_apply). This is what the "My Applications"
  ///                    tab uses so external-redirect applies don't
  ///                    clutter the tracker.
  ///   - `'external'` → applications recorded when the seeker tapped the
  ///                    external apply link (LinkedIn / company site).
  ///   - `null`       → both (legacy callers).
  Future<List<JobApplication>> list({
    ApplicationStatus? status,
    String? type,
    int page = 1,
    int limit = 50,
  }) async {
    final raw = await _api.get('applied', query: {
      if (status != null) 'status': _statusToApi(status),
      if (type != null) 'type': type,
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

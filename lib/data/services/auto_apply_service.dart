import '../models/auto_apply_log_model.dart';
import '../models/auto_apply_settings_model.dart';
import 'api_client.dart';

class AutoApplyService {
  AutoApplyService._();
  static final AutoApplyService instance = AutoApplyService._();

  final ApiClient _api = ApiClient.instance;

  Future<AutoApplySettings> getSettings() async {
    final raw = await _api.get('auto-apply/settings');
    return AutoApplySettings.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AutoApplySettings> updateSettings({
    bool? isEnabled,
    String? runTime,
    List<String>? runDays,
    int? dailyLimit,
    AutoApplyPreferences? preferences,
    AutoApplyMatchingRules? matchingRules,
    bool? reviewMode,
    AutoApplyAiCoverLetter? aiCoverLetter,
  }) async {
    final body = <String, dynamic>{
      if (isEnabled != null) 'isEnabled': isEnabled,
      if (runTime != null) 'runTime': runTime,
      if (runDays != null) 'runDays': runDays,
      if (dailyLimit != null) 'dailyLimit': dailyLimit,
      if (preferences != null) 'preferences': preferences.toJson(),
      if (matchingRules != null) 'matchingRules': matchingRules.toJson(),
      if (reviewMode != null) 'reviewMode': reviewMode,
      if (aiCoverLetter != null) 'aiCoverLetter': aiCoverLetter.toJson(),
    };
    final raw = await _api.put('auto-apply/settings', body: body);
    return AutoApplySettings.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AutoApplySettings> pause({int? days, String? reason}) async {
    final raw = await _api.post('auto-apply/pause', body: {
      if (days != null) 'days': days,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return AutoApplySettings.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AutoApplySettings> resume() async {
    final raw = await _api.post('auto-apply/resume');
    return AutoApplySettings.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<Map<String, dynamic>> runNow() async {
    final raw = await _api.post('auto-apply/run-now');
    return ApiClient.unwrapMap(raw);
  }

  /// Returns null when the user has no review-mode batch awaiting approval.
  Future<AutoApplyPreview?> getPreview() async {
    final raw = await _api.get('auto-apply/preview');
    final data = ApiClient.unwrap<dynamic>(raw);
    if (data == null) return null;
    return AutoApplyPreview.fromJson(data as Map<String, dynamic>);
  }

  Future<({int applied, int failed, int skipped})> approveJobs({
    required String logId,
    required List<String> jobIds,
  }) async {
    final raw = await _api.post('auto-apply/approve', body: {
      'logId': logId,
      'jobIds': jobIds,
    });
    final m = ApiClient.unwrapMap(raw);
    return (
      applied: (m['applied'] as int?) ?? 0,
      failed: (m['failed'] as int?) ?? 0,
      skipped: (m['skipped'] as int?) ?? 0,
    );
  }

  Future<List<AutoApplyLog>> listLogs({int page = 1, int limit = 20}) async {
    final raw = await _api.get('auto-apply/logs',
        query: {'page': page, 'limit': limit});
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(AutoApplyLog.fromJson)
        .toList();
  }

  Future<AutoApplyLog?> todaySummary() async {
    final raw = await _api.get('auto-apply/logs/today');
    final data = ApiClient.unwrap<dynamic>(raw);
    if (data == null) return null;
    return AutoApplyLog.fromJson(data as Map<String, dynamic>);
  }
}

class AutoApplyPreviewCandidate {
  final String jobId;
  final String companyName;
  final String jobTitle;
  final int matchScore;
  final String source;
  final String? location;
  final String? jobType;
  final String? remoteType;
  final List<String> skills;

  const AutoApplyPreviewCandidate({
    required this.jobId,
    required this.companyName,
    required this.jobTitle,
    required this.matchScore,
    required this.source,
    this.location,
    this.jobType,
    this.remoteType,
    this.skills = const [],
  });

  factory AutoApplyPreviewCandidate.fromJson(Map<String, dynamic> j) {
    final job = j['job'];
    final jobMap = job is Map<String, dynamic> ? job : <String, dynamic>{};
    return AutoApplyPreviewCandidate(
      jobId: (j['jobId'] ?? '').toString(),
      companyName: (j['companyName'] ?? '').toString(),
      jobTitle: (j['jobTitle'] ?? '').toString(),
      matchScore: (j['matchScore'] as num?)?.toInt() ?? 0,
      source: (j['source'] ?? 'native').toString(),
      location: jobMap['location'] as String?,
      jobType: jobMap['jobType'] as String?,
      remoteType: jobMap['remoteType'] as String?,
      skills: (jobMap['skills'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class AutoApplyPreview {
  final String logId;
  final DateTime? runDate;
  final int jobsScanned;
  final int jobsMatched;
  final List<AutoApplyPreviewCandidate> candidates;

  const AutoApplyPreview({
    required this.logId,
    this.runDate,
    required this.jobsScanned,
    required this.jobsMatched,
    required this.candidates,
  });

  factory AutoApplyPreview.fromJson(Map<String, dynamic> j) => AutoApplyPreview(
        logId: (j['logId'] ?? '').toString(),
        runDate: j['runDate'] == null
            ? null
            : DateTime.tryParse(j['runDate'].toString()),
        jobsScanned: (j['jobsScanned'] as num?)?.toInt() ?? 0,
        jobsMatched: (j['jobsMatched'] as num?)?.toInt() ?? 0,
        candidates: (j['candidates'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AutoApplyPreviewCandidate.fromJson)
                .toList() ??
            const [],
      );
}

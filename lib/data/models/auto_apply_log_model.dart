class AutoApplyLogEntry {
  final String jobId;
  final String? applicationId;
  final String companyName;
  final String jobTitle;
  final int matchScore;
  final String source;
  final DateTime? appliedAt;
  final bool coverLetterUsed;
  final String status;

  const AutoApplyLogEntry({
    required this.jobId,
    this.applicationId,
    required this.companyName,
    required this.jobTitle,
    required this.matchScore,
    required this.source,
    this.appliedAt,
    this.coverLetterUsed = false,
    required this.status,
  });

  factory AutoApplyLogEntry.fromJson(Map<String, dynamic> j) =>
      AutoApplyLogEntry(
        jobId: (j['job'] ?? '').toString(),
        applicationId: j['application']?.toString(),
        companyName: (j['companyName'] ?? '').toString(),
        jobTitle: (j['jobTitle'] ?? '').toString(),
        matchScore: (j['matchScore'] as num?)?.toInt() ?? 0,
        source: (j['source'] ?? 'native').toString(),
        appliedAt: j['appliedAt'] == null
            ? null
            : DateTime.tryParse(j['appliedAt'].toString()),
        coverLetterUsed: j['coverLetterUsed'] as bool? ?? false,
        status: (j['status'] ?? 'applied').toString(),
      );
}

class AutoApplySkippedEntry {
  final String jobId;
  final String reason;
  final int? matchScore;
  const AutoApplySkippedEntry({
    required this.jobId,
    required this.reason,
    this.matchScore,
  });
  factory AutoApplySkippedEntry.fromJson(Map<String, dynamic> j) =>
      AutoApplySkippedEntry(
        jobId: (j['job'] ?? '').toString(),
        reason: (j['reason'] ?? '').toString(),
        matchScore: (j['matchScore'] as num?)?.toInt(),
      );
}

class AutoApplyLog {
  final String id;
  final DateTime runDate;
  final int jobsScanned;
  final int jobsMatched;
  final int jobsApplied;
  final int jobsSkipped;
  final List<AutoApplyLogEntry> appliedJobs;
  final List<AutoApplySkippedEntry> skippedJobs;
  final bool awaitingApproval;
  final bool triggeredManually;

  const AutoApplyLog({
    required this.id,
    required this.runDate,
    required this.jobsScanned,
    required this.jobsMatched,
    required this.jobsApplied,
    required this.jobsSkipped,
    required this.appliedJobs,
    required this.skippedJobs,
    required this.awaitingApproval,
    required this.triggeredManually,
  });

  factory AutoApplyLog.fromJson(Map<String, dynamic> j) => AutoApplyLog(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        runDate: DateTime.tryParse(j['runDate']?.toString() ?? '') ??
            DateTime.now(),
        jobsScanned: (j['jobsScanned'] as num?)?.toInt() ?? 0,
        jobsMatched: (j['jobsMatched'] as num?)?.toInt() ?? 0,
        jobsApplied: (j['jobsApplied'] as num?)?.toInt() ?? 0,
        jobsSkipped: (j['jobsSkipped'] as num?)?.toInt() ?? 0,
        appliedJobs: (j['appliedJobs'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AutoApplyLogEntry.fromJson)
                .toList() ??
            const [],
        skippedJobs: (j['skippedJobs'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AutoApplySkippedEntry.fromJson)
                .toList() ??
            const [],
        awaitingApproval: j['awaitingApproval'] as bool? ?? false,
        triggeredManually: j['triggeredManually'] as bool? ?? false,
      );
}

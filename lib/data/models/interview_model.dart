class Interview {
  final String id;
  final String applicationId;
  final String jobId;
  final String? jobTitle;
  final String? companyName;
  final String round;
  final String interviewType;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String timezone;
  final String? meetingLink;
  final String? meetingPlatform;
  final String? location;
  final String? notesToCandidate;
  final String status;
  final bool candidateConfirmed;

  const Interview({
    required this.id,
    required this.applicationId,
    required this.jobId,
    this.jobTitle,
    this.companyName,
    required this.round,
    required this.interviewType,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.timezone,
    this.meetingLink,
    this.meetingPlatform,
    this.location,
    this.notesToCandidate,
    required this.status,
    required this.candidateConfirmed,
  });

  factory Interview.fromJson(Map<String, dynamic> j) {
    final job = j['job'];
    final hirerProfile = j['hirerProfile'];
    String? jobTitle;
    String? companyName;
    if (job is Map<String, dynamic>) {
      jobTitle = job['title'] as String?;
      companyName = job['company'] as String?;
    }
    if (hirerProfile is Map<String, dynamic>) {
      companyName ??= hirerProfile['companyName'] as String?;
    }
    return Interview(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      applicationId: (j['application'] ?? '').toString(),
      jobId: job is Map<String, dynamic>
          ? (job['_id']?.toString() ?? '')
          : (j['job']?.toString() ?? ''),
      jobTitle: jobTitle,
      companyName: companyName,
      round: (j['round'] ?? 'hr').toString(),
      interviewType: (j['interviewType'] ?? 'video').toString(),
      scheduledAt: DateTime.tryParse(j['scheduledAt']?.toString() ?? '') ??
          DateTime.now(),
      durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 45,
      timezone: (j['timezone'] ?? 'Asia/Kolkata').toString(),
      meetingLink: j['meetingLink'] as String?,
      meetingPlatform: j['meetingPlatform'] as String?,
      location: j['location'] as String?,
      notesToCandidate: j['notesToCandidate'] as String?,
      status: (j['status'] ?? 'scheduled').toString(),
      candidateConfirmed: j['candidateConfirmed'] as bool? ?? false,
    );
  }
}

import 'job_model.dart';

/// How the application was submitted. Mirrors the backend `applyType` enum
/// so the seeker UI can show "AI applied for you" vs a manual apply.
enum ApplyType { oneClick, customForm, autoApply, externalManual }

class JobApplication {
  final String id;
  final Job job;
  final ApplicationStatus status;
  final ApplyType applyType;
  final DateTime appliedAt;
  final String notes;
  final DateTime? followUpDate;

  const JobApplication({
    required this.id,
    required this.job,
    required this.status,
    this.applyType = ApplyType.oneClick,
    required this.appliedAt,
    this.notes = '',
    this.followUpDate,
  });

  /// True when AI auto-apply submitted this application on the user's
  /// behalf — drives the dedicated "AI" ribbon on the application card.
  bool get isAiApplied => applyType == ApplyType.autoApply;

  String get statusLabel {
    switch (status) {
      case ApplicationStatus.applied:
        return 'Applied';
      case ApplicationStatus.viewed:
        return 'Viewed';
      case ApplicationStatus.shortlisted:
        return 'Shortlisted';
      case ApplicationStatus.interview:
        return 'Interview';
      case ApplicationStatus.offered:
        return 'Offered';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  JobApplication copyWith({
    ApplicationStatus? status,
    ApplyType? applyType,
    String? notes,
    DateTime? followUpDate,
  }) =>
      JobApplication(
        id: id,
        job: job,
        status: status ?? this.status,
        applyType: applyType ?? this.applyType,
        appliedAt: appliedAt,
        notes: notes ?? this.notes,
        followUpDate: followUpDate ?? this.followUpDate,
      );

  static ApplicationStatus parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'viewed':
        return ApplicationStatus.viewed;
      case 'shortlisted':
        return ApplicationStatus.shortlisted;
      case 'interview':
        return ApplicationStatus.interview;
      case 'offer':
      case 'offered':
        return ApplicationStatus.offered;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'withdrawn':
        return ApplicationStatus.withdrawn;
      default:
        return ApplicationStatus.applied;
    }
  }

  static ApplyType parseApplyType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'auto_apply':
        return ApplyType.autoApply;
      case 'custom_form':
        return ApplyType.customForm;
      case 'external_manual':
        return ApplyType.externalManual;
      default:
        return ApplyType.oneClick;
    }
  }

  factory JobApplication.fromApiJson(Map<String, dynamic> raw) {
    final id = (raw['_id'] ?? raw['id'] ?? '').toString();
    final jobJson = raw['job'];
    Job parsedJob;
    if (jobJson is Map<String, dynamic>) {
      parsedJob = Job.fromApiJson(jobJson);
    } else if (jobJson is String) {
      parsedJob = Job(
        id: jobJson,
        title: '',
        company: '',
        companyLogo: '',
        location: '',
        salary: '',
        description: '',
      );
    } else {
      parsedJob = Job.fromApiJson(raw);
    }
    final appliedAtRaw = raw['appliedAt'] ?? raw['createdAt'];
    final appliedAt = appliedAtRaw is String
        ? DateTime.tryParse(appliedAtRaw) ?? DateTime.now()
        : DateTime.now();
    final followUpRaw = raw['followUpDate'];
    final followUp = followUpRaw is String
        ? DateTime.tryParse(followUpRaw)
        : null;
    return JobApplication(
      id: id,
      job: parsedJob,
      status: parseStatus(raw['status'] as String?),
      applyType: parseApplyType(raw['applyType'] as String?),
      appliedAt: appliedAt,
      notes: (raw['notes'] ?? '').toString(),
      followUpDate: followUp,
    );
  }
}

/// Hirer-side view of a Job. Includes extra fields the seeker UI doesn't
/// surface (status, applicationsCount, etc).
class HirerJob {
  final String id;
  final String title;
  final String? department;
  final String description;
  final List<String> responsibilities;
  final String location;
  final String jobType;
  final String remoteType;
  final int openingsCount;
  final int? experienceMinYears;
  final int? experienceMaxYears;
  final String? education;
  final List<String> skills;
  final List<String> niceToHaveSkills;
  final bool isSalaryVisible;
  final int? salaryMin;
  final int? salaryMax;
  final String? currency;
  final List<String> perks;
  final String applyType;
  final List<String> requiredDocuments;
  final List<ScreeningQuestion> screeningQuestions;
  final DateTime? applicationDeadline;
  final String status;
  final int viewsCount;
  final int applicationsCount;
  final int shortlistedCount;
  final DateTime? publishedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  /// Mirror of `Job.moderation.status` — 'pending' | 'approved' |
  /// 'rejected' | 'queued'. Lets the manage-jobs row surface an
  /// "Appeal" affordance when the AI moderation rejected the post.
  final String? moderationStatus;

  const HirerJob({
    required this.id,
    required this.title,
    this.department,
    required this.description,
    this.responsibilities = const [],
    required this.location,
    required this.jobType,
    required this.remoteType,
    this.openingsCount = 1,
    this.experienceMinYears,
    this.experienceMaxYears,
    this.education,
    this.skills = const [],
    this.niceToHaveSkills = const [],
    this.isSalaryVisible = true,
    this.salaryMin,
    this.salaryMax,
    this.currency,
    this.perks = const [],
    this.applyType = 'easy_apply',
    this.requiredDocuments = const [],
    this.screeningQuestions = const [],
    this.applicationDeadline,
    required this.status,
    this.viewsCount = 0,
    this.applicationsCount = 0,
    this.shortlistedCount = 0,
    this.publishedAt,
    this.closedAt,
    required this.createdAt,
    this.moderationStatus,
  });

  factory HirerJob.fromJson(Map<String, dynamic> j) {
    DateTime? d(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return HirerJob(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      department: j['department'] as String?,
      description: (j['description'] ?? '').toString(),
      responsibilities:
          (j['responsibilities'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      location: (j['location'] ?? '').toString(),
      jobType: (j['jobType'] ?? '').toString(),
      remoteType: (j['remoteType'] ?? '').toString(),
      openingsCount: (j['openingsCount'] as int?) ?? 1,
      experienceMinYears: (j['experienceMinYears'] as num?)?.toInt(),
      experienceMaxYears: (j['experienceMaxYears'] as num?)?.toInt(),
      education: j['education'] as String?,
      skills:
          (j['skills'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      niceToHaveSkills:
          (j['niceToHaveSkills'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      isSalaryVisible: j['isSalaryVisible'] as bool? ?? true,
      salaryMin: (j['salaryMin'] as num?)?.toInt(),
      salaryMax: (j['salaryMax'] as num?)?.toInt(),
      currency: j['currency'] as String?,
      perks:
          (j['perks'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      applyType: (j['applyType'] ?? 'easy_apply').toString(),
      requiredDocuments: (j['requiredDocuments'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      screeningQuestions: (j['screeningQuestions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScreeningQuestion.fromJson)
              .toList() ??
          const [],
      applicationDeadline: d(j['applicationDeadline']),
      status: (j['status'] ?? 'active').toString(),
      viewsCount: (j['viewsCount'] as int?) ?? 0,
      applicationsCount: (j['applicationsCount'] as int?) ?? 0,
      shortlistedCount: (j['shortlistedCount'] as int?) ?? 0,
      publishedAt: d(j['publishedAt']),
      closedAt: d(j['closedAt']),
      createdAt: d(j['createdAt']) ?? DateTime.now(),
      moderationStatus: j['moderation'] is Map<String, dynamic>
          ? (j['moderation'] as Map<String, dynamic>)['status'] as String?
          : null,
    );
  }
}

class ScreeningQuestion {
  final String question;
  final String type; // 'text' | 'mcq' | 'yes_no'
  final List<String> options;
  final bool isRequired;

  const ScreeningQuestion({
    required this.question,
    required this.type,
    this.options = const [],
    this.isRequired = false,
  });

  factory ScreeningQuestion.fromJson(Map<String, dynamic> j) =>
      ScreeningQuestion(
        question: (j['question'] ?? '').toString(),
        type: (j['type'] ?? 'text').toString(),
        options:
            (j['options'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        isRequired: j['isRequired'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'type': type,
        if (options.isNotEmpty) 'options': options,
        'isRequired': isRequired,
      };
}

/// Payload used to create or update a native job.
class HirerJobInput {
  final String title;
  final String? department;
  final String description;
  final List<String> responsibilities;
  final String location;
  final String jobType;
  final String remoteType;
  final int openingsCount;
  final int? experienceMinYears;
  final int? experienceMaxYears;
  final String? education;
  final List<String> skills;
  final List<String> niceToHaveSkills;
  final bool isSalaryVisible;
  final int? salaryMin;
  final int? salaryMax;
  final String currency;
  final List<String> perks;
  final String applyType;
  final List<String> requiredDocuments;
  final List<ScreeningQuestion> screeningQuestions;
  final DateTime? applicationDeadline;
  final bool saveAsDraft;

  const HirerJobInput({
    required this.title,
    this.department,
    required this.description,
    this.responsibilities = const [],
    required this.location,
    required this.jobType,
    required this.remoteType,
    this.openingsCount = 1,
    this.experienceMinYears,
    this.experienceMaxYears,
    this.education,
    this.skills = const [],
    this.niceToHaveSkills = const [],
    this.isSalaryVisible = true,
    this.salaryMin,
    this.salaryMax,
    this.currency = 'INR',
    this.perks = const [],
    this.applyType = 'easy_apply',
    this.requiredDocuments = const ['resume'],
    this.screeningQuestions = const [],
    this.applicationDeadline,
    this.saveAsDraft = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (department != null && department!.isNotEmpty) 'department': department,
        'description': description,
        if (responsibilities.isNotEmpty) 'responsibilities': responsibilities,
        'location': location,
        'jobType': jobType,
        'remoteType': remoteType,
        'openingsCount': openingsCount,
        if (experienceMinYears != null) 'experienceMinYears': experienceMinYears,
        if (experienceMaxYears != null) 'experienceMaxYears': experienceMaxYears,
        if (education != null && education!.isNotEmpty) 'education': education,
        'skills': skills,
        if (niceToHaveSkills.isNotEmpty) 'niceToHaveSkills': niceToHaveSkills,
        'isSalaryVisible': isSalaryVisible,
        if (salaryMin != null) 'salaryMin': salaryMin,
        if (salaryMax != null) 'salaryMax': salaryMax,
        'currency': currency,
        if (perks.isNotEmpty) 'perks': perks,
        'applyType': applyType,
        if (requiredDocuments.isNotEmpty)
          'requiredDocuments': requiredDocuments,
        if (screeningQuestions.isNotEmpty)
          'screeningQuestions':
              screeningQuestions.map((q) => q.toJson()).toList(),
        if (applicationDeadline != null)
          'applicationDeadline': applicationDeadline!.toIso8601String(),
        'saveAsDraft': saveAsDraft,
      };
}

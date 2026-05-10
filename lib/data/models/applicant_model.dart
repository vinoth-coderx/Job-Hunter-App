/// Hirer-side view of an Application + its applicant.
class Applicant {
  final String applicationId;
  final String jobId;
  final String status;
  final double? matchScore;
  final DateTime? appliedAt;
  final String applyType;
  final String source;
  final String? quickNote;
  final String? resumeUrlSnapshot;
  final List<ScreeningAnswer> screeningAnswers;
  final String? hirerNotes;
  final String? rejectionReason;
  final List<StatusHistoryEntry> statusHistory;
  final ApplicantSeeker? seeker;
  final ApplicantJobSnapshot? jobSnapshot;

  const Applicant({
    required this.applicationId,
    required this.jobId,
    required this.status,
    this.matchScore,
    this.appliedAt,
    required this.applyType,
    required this.source,
    this.quickNote,
    this.resumeUrlSnapshot,
    this.screeningAnswers = const [],
    this.hirerNotes,
    this.rejectionReason,
    this.statusHistory = const [],
    this.seeker,
    this.jobSnapshot,
  });

  factory Applicant.fromJson(Map<String, dynamic> j) => Applicant(
        applicationId: (j['applicationId'] ?? '').toString(),
        jobId: (j['jobId'] ?? '').toString(),
        status: (j['status'] ?? 'applied').toString(),
        matchScore: (j['matchScore'] as num?)?.toDouble(),
        appliedAt: j['appliedAt'] == null
            ? null
            : DateTime.tryParse(j['appliedAt'].toString()),
        applyType: (j['applyType'] ?? 'one_click').toString(),
        source: (j['source'] ?? 'native').toString(),
        quickNote: j['quickNote'] as String?,
        resumeUrlSnapshot: j['resumeUrlSnapshot'] as String?,
        screeningAnswers: (j['screeningAnswers'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ScreeningAnswer.fromJson)
                .toList() ??
            const [],
        hirerNotes: j['hirerNotes'] as String?,
        rejectionReason: j['rejectionReason'] as String?,
        statusHistory: (j['statusHistory'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(StatusHistoryEntry.fromJson)
                .toList() ??
            const [],
        seeker: j['seeker'] is Map<String, dynamic>
            ? ApplicantSeeker.fromJson(j['seeker'] as Map<String, dynamic>)
            : null,
        jobSnapshot: j['jobSnapshot'] is Map<String, dynamic>
            ? ApplicantJobSnapshot.fromJson(
                j['jobSnapshot'] as Map<String, dynamic>)
            : null,
      );
}

class ApplicantSeeker {
  final String id;
  final String email;
  final String fullName;
  final String? avatar;
  final String? headline;
  final String? phone;
  final List<String> skills;
  final int experienceYears;
  final List<String> preferredLocations;
  final String? resumeUrl;

  const ApplicantSeeker({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatar,
    this.headline,
    this.phone,
    this.skills = const [],
    this.experienceYears = 0,
    this.preferredLocations = const [],
    this.resumeUrl,
  });

  factory ApplicantSeeker.fromJson(Map<String, dynamic> j) => ApplicantSeeker(
        id: (j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        fullName: (j['fullName'] ?? '').toString(),
        avatar: j['avatar'] as String?,
        headline: j['headline'] as String?,
        phone: j['phone'] as String?,
        skills:
            (j['skills'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        experienceYears: (j['experienceYears'] as int?) ?? 0,
        preferredLocations: (j['preferredLocations'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        resumeUrl: j['resumeUrl'] as String?,
      );
}

class ApplicantJobSnapshot {
  final String title;
  final String company;
  final String location;
  const ApplicantJobSnapshot({
    required this.title,
    required this.company,
    required this.location,
  });
  factory ApplicantJobSnapshot.fromJson(Map<String, dynamic> j) =>
      ApplicantJobSnapshot(
        title: (j['title'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        location: (j['location'] ?? '').toString(),
      );
}

class ScreeningAnswer {
  final String question;
  final String answer;
  const ScreeningAnswer({required this.question, required this.answer});
  factory ScreeningAnswer.fromJson(Map<String, dynamic> j) => ScreeningAnswer(
        question: (j['question'] ?? '').toString(),
        answer: (j['answer'] ?? '').toString(),
      );
}

class StatusHistoryEntry {
  final String status;
  final DateTime? changedAt;
  final String? note;
  const StatusHistoryEntry({
    required this.status,
    this.changedAt,
    this.note,
  });
  factory StatusHistoryEntry.fromJson(Map<String, dynamic> j) =>
      StatusHistoryEntry(
        status: (j['status'] ?? '').toString(),
        changedAt: j['changedAt'] == null
            ? null
            : DateTime.tryParse(j['changedAt'].toString()),
        note: j['note'] as String?,
      );
}

/// AI-suggested candidate from the hirer's PAST applicant pool. These
/// are users who applied to one of the hirer's other jobs but not to
/// THIS job — surfaced so the hirer can proactively reach out. Mirrors
/// the decorated payload from `suggestJobCandidates` (the AI score plus
/// the user's profile fields the UI needs).
class SuggestedCandidate {
  final String userId;
  final int score;
  final int rank;
  final String summary;
  final List<String> strengths;
  final List<String> concerns;
  final String fullName;
  final String? headline;
  final String? avatar;
  final int? experienceYears;
  final List<String> topSkills;
  final DateTime? lastSeenAt;

  const SuggestedCandidate({
    required this.userId,
    required this.score,
    required this.rank,
    required this.summary,
    required this.strengths,
    required this.concerns,
    required this.fullName,
    this.headline,
    this.avatar,
    this.experienceYears,
    this.topSkills = const [],
    this.lastSeenAt,
  });

  factory SuggestedCandidate.fromJson(Map<String, dynamic> j) =>
      SuggestedCandidate(
        userId: (j['userId'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '').toString(),
        strengths: (j['strengths'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        concerns: (j['concerns'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        fullName: (j['fullName'] ?? 'Candidate').toString(),
        headline: j['headline'] as String?,
        avatar: j['avatar'] as String?,
        experienceYears: (j['experienceYears'] as num?)?.toInt(),
        topSkills: (j['topSkills'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        lastSeenAt: j['lastSeenAt'] == null
            ? null
            : DateTime.tryParse(j['lastSeenAt'].toString()),
      );

  String get band {
    if (score >= 90) return 'Exceptional';
    if (score >= 75) return 'Strong';
    if (score >= 60) return 'Marginal';
    return 'Weak';
  }
}

/// One row of the AI-ranked applicant list. Mirrors
/// `services/ai/applicantRanker.service.ts:RankedApplicant`. Keyed by
/// `applicationId` so the hirer UI can merge it into the existing
/// `Applicant` cards without re-fetching the list.
class RankedApplicant {
  final String applicationId;
  final int aiScore;
  final int rank;
  final String summary;
  final List<String> strengths;
  final List<String> concerns;

  const RankedApplicant({
    required this.applicationId,
    required this.aiScore,
    required this.rank,
    required this.summary,
    required this.strengths,
    required this.concerns,
  });

  factory RankedApplicant.fromJson(Map<String, dynamic> j) => RankedApplicant(
        applicationId: (j['applicationId'] ?? '').toString(),
        aiScore: (j['aiScore'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '').toString(),
        strengths: (j['strengths'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        concerns: (j['concerns'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
      );

  /// Bucket label for the badge — same bands the backend prompt uses.
  String get band {
    if (aiScore >= 90) return 'Exceptional';
    if (aiScore >= 75) return 'Strong';
    if (aiScore >= 60) return 'Marginal';
    if (aiScore >= 40) return 'Weak';
    return 'Poor';
  }
}

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
  /// Privacy hints from the backend so the hirer UI can show "contact
  /// hidden until shortlisted" pills + disable the "download resume"
  /// button when the seeker turned downloads off.
  final ApplicantPrivacy? seekerPrivacy;
  /// Persisted AI ranking from the last "Rank with AI" run. Lets the
  /// detail screen surface strengths/concerns without requiring the
  /// hirer to re-rank from the list view.
  final ApplicantAiRanking? aiRanking;

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
    this.seekerPrivacy,
    this.aiRanking,
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
        seekerPrivacy: j['seekerPrivacy'] is Map<String, dynamic>
            ? ApplicantPrivacy.fromJson(
                j['seekerPrivacy'] as Map<String, dynamic>)
            : null,
        aiRanking: j['aiRanking'] is Map<String, dynamic>
            ? ApplicantAiRanking.fromJson(
                j['aiRanking'] as Map<String, dynamic>)
            : null,
      );
}

/// Snapshot of the most recent AI ranking persisted on the application.
/// Mirrors the backend `AppliedJob.aiRanking` subdoc — kept separate from
/// `RankedApplicant` (which is the list-view DTO) so the detail screen
/// doesn't need to reach into the hirer ranker's payload shape.
class ApplicantAiRanking {
  final int score;
  final int rank;
  final String summary;
  final List<String> strengths;
  final List<String> concerns;
  final DateTime? rankedAt;

  const ApplicantAiRanking({
    required this.score,
    required this.rank,
    required this.summary,
    required this.strengths,
    required this.concerns,
    required this.rankedAt,
  });

  factory ApplicantAiRanking.fromJson(Map<String, dynamic> j) =>
      ApplicantAiRanking(
        score: (j['score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        summary: (j['summary'] ?? '').toString(),
        strengths: (j['strengths'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        concerns: (j['concerns'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        rankedAt: j['rankedAt'] == null
            ? null
            : DateTime.tryParse(j['rankedAt'].toString()),
      );

  String get band {
    if (score >= 90) return 'Exceptional';
    if (score >= 75) return 'Strong';
    if (score >= 60) return 'Marginal';
    if (score >= 40) return 'Weak';
    return 'Poor';
  }
}

class ApplicantPrivacy {
  final bool contactRevealed;
  final bool hideContactUntilShortlisted;
  final bool allowResumeDownload;

  const ApplicantPrivacy({
    required this.contactRevealed,
    required this.hideContactUntilShortlisted,
    required this.allowResumeDownload,
  });

  factory ApplicantPrivacy.fromJson(Map<String, dynamic> j) => ApplicantPrivacy(
        contactRevealed: j['contactRevealed'] as bool? ?? true,
        hideContactUntilShortlisted:
            j['hideContactUntilShortlisted'] as bool? ?? false,
        allowResumeDownload: j['allowResumeDownload'] as bool? ?? true,
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

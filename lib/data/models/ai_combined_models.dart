// Models for the combined AI endpoints (resume onboarding, job insight,
// for-you recommendations, JD generator). Kept in one file so a single
// import covers the full surface and the related shapes stay together.

class AiMatchSummary {
  final String jobId;
  final String title;
  final String company;
  final int score;
  final String reasoning;
  final List<String> matchedSkills;
  final List<String> missingSkills;

  const AiMatchSummary({
    required this.jobId,
    required this.title,
    required this.company,
    required this.score,
    required this.reasoning,
    required this.matchedSkills,
    required this.missingSkills,
  });

  factory AiMatchSummary.fromJson(Map<String, dynamic> j) => AiMatchSummary(
        jobId: (j['jobId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        reasoning: (j['reasoning'] ?? '').toString(),
        matchedSkills: ((j['matchedSkills'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        missingSkills: ((j['missingSkills'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class AiResumeImprovement {
  final String area;
  final String suggestion;
  final String impact;

  const AiResumeImprovement({
    required this.area,
    required this.suggestion,
    required this.impact,
  });

  factory AiResumeImprovement.fromJson(Map<String, dynamic> j) =>
      AiResumeImprovement(
        area: (j['area'] ?? 'skills').toString(),
        suggestion: (j['suggestion'] ?? '').toString(),
        impact: (j['impact'] ?? '').toString(),
      );
}

class AiResumeOnboarding {
  final Map<String, dynamic> parsedResume;
  final List<AiMatchSummary> topMatches;
  final List<AiResumeImprovement> improvements;
  final String careerInsight;

  const AiResumeOnboarding({
    required this.parsedResume,
    required this.topMatches,
    required this.improvements,
    required this.careerInsight,
  });

  factory AiResumeOnboarding.fromJson(Map<String, dynamic> j) =>
      AiResumeOnboarding(
        parsedResume:
            (j['parsedResume'] as Map?)?.cast<String, dynamic>() ?? const {},
        topMatches: ((j['topMatches'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AiMatchSummary.fromJson(e.cast<String, dynamic>()))
            .toList(),
        improvements: ((j['improvements'] as List?) ?? const [])
            .whereType<Map>()
            .map(
                (e) => AiResumeImprovement.fromJson(e.cast<String, dynamic>()))
            .toList(),
        careerInsight: (j['careerInsight'] ?? '').toString(),
      );
}

class AiSkillGapItem {
  final String skill;
  final String priority; // 'high' | 'medium' | 'low'
  final String rampUp;

  const AiSkillGapItem({
    required this.skill,
    required this.priority,
    required this.rampUp,
  });

  factory AiSkillGapItem.fromJson(Map<String, dynamic> j) => AiSkillGapItem(
        skill: (j['skill'] ?? '').toString(),
        priority: (j['priority'] ?? 'medium').toString(),
        rampUp: (j['rampUp'] ?? '').toString(),
      );
}

class AiInterviewQuestion {
  final String question;
  final String whyAsked;
  const AiInterviewQuestion({required this.question, required this.whyAsked});

  factory AiInterviewQuestion.fromJson(Map<String, dynamic> j) =>
      AiInterviewQuestion(
        question: (j['question'] ?? '').toString(),
        whyAsked: (j['whyAsked'] ?? '').toString(),
      );
}

class AiJobInsight {
  final int score;
  final String reasoning;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String coverLetterOpening;
  final String coverLetterBody;
  final List<AiSkillGapItem> skillGapMissing;
  final String skillGapSummary;
  final List<AiInterviewQuestion> interviewPrep;

  const AiJobInsight({
    required this.score,
    required this.reasoning,
    required this.matchedSkills,
    required this.missingSkills,
    required this.coverLetterOpening,
    required this.coverLetterBody,
    required this.skillGapMissing,
    required this.skillGapSummary,
    required this.interviewPrep,
  });

  factory AiJobInsight.fromJson(Map<String, dynamic> j) {
    final ms = (j['matchScore'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cl = (j['coverLetter'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sg = (j['skillGap'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AiJobInsight(
      score: (ms['score'] as num?)?.toInt() ?? 0,
      reasoning: (ms['reasoning'] ?? '').toString(),
      matchedSkills: ((ms['matchedSkills'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      missingSkills: ((ms['missingSkills'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      coverLetterOpening: (cl['opening'] ?? '').toString(),
      coverLetterBody: (cl['body'] ?? '').toString(),
      skillGapMissing: ((sg['missing'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AiSkillGapItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      skillGapSummary: (sg['summary'] ?? '').toString(),
      interviewPrep: ((j['interviewPrep'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => AiInterviewQuestion.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class AiForYouPick {
  final String jobId;
  final String title;
  final String company;
  final String whyThisJob;
  final List<String> matchSignals;

  const AiForYouPick({
    required this.jobId,
    required this.title,
    required this.company,
    required this.whyThisJob,
    required this.matchSignals,
  });

  factory AiForYouPick.fromJson(Map<String, dynamic> j) => AiForYouPick(
        jobId: (j['jobId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        whyThisJob: (j['whyThisJob'] ?? '').toString(),
        matchSignals: ((j['matchSignals'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class AiForYou {
  final String insight;
  final List<AiForYouPick> picks;
  final DateTime cachedAt;
  final DateTime expiresAt;

  const AiForYou({
    required this.insight,
    required this.picks,
    required this.cachedAt,
    required this.expiresAt,
  });

  factory AiForYou.fromJson(Map<String, dynamic> j) => AiForYou(
        insight: (j['insight'] ?? '').toString(),
        picks: ((j['picks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AiForYouPick.fromJson(e.cast<String, dynamic>()))
            .toList(),
        cachedAt: DateTime.tryParse((j['cachedAt'] ?? '').toString()) ??
            DateTime.now(),
        expiresAt: DateTime.tryParse((j['expiresAt'] ?? '').toString()) ??
            DateTime.now().add(const Duration(minutes: 30)),
      );
}

class AiGeneratedJd {
  final String title;
  final String description;
  final List<String> responsibilities;
  final List<String> requiredSkills;
  final List<String> niceToHaveSkills;
  final List<String> perks;
  final List<Map<String, String>> screeningQuestions;

  const AiGeneratedJd({
    required this.title,
    required this.description,
    required this.responsibilities,
    required this.requiredSkills,
    required this.niceToHaveSkills,
    required this.perks,
    required this.screeningQuestions,
  });

  factory AiGeneratedJd.fromJson(Map<String, dynamic> j) => AiGeneratedJd(
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        responsibilities: ((j['responsibilities'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        requiredSkills: ((j['requiredSkills'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        niceToHaveSkills: ((j['niceToHaveSkills'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        perks: ((j['perks'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        screeningQuestions: ((j['screeningQuestions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => {
                  'question': (e['question'] ?? '').toString(),
                  'type': (e['type'] ?? 'text').toString(),
                })
            .toList(),
      );
}

class AiChatTurn {
  final String role; // 'user' | 'model'
  final String content;
  final int ts;

  const AiChatTurn({required this.role, required this.content, required this.ts});

  factory AiChatTurn.fromJson(Map<String, dynamic> j) => AiChatTurn(
        role: (j['role'] ?? 'user').toString(),
        content: (j['content'] ?? '').toString(),
        ts: (j['ts'] as num?)?.toInt() ?? 0,
      );

  bool get isUser => role == 'user';
}

class AiChatResponse {
  final String reply;
  final List<AiChatTurn> history;
  const AiChatResponse({required this.reply, required this.history});

  factory AiChatResponse.fromJson(Map<String, dynamic> j) => AiChatResponse(
        reply: (j['reply'] ?? '').toString(),
        history: ((j['history'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AiChatTurn.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

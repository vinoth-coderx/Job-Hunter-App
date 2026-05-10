class AssessmentQuestion {
  final String question;
  final List<String> options;
  const AssessmentQuestion({required this.question, required this.options});
  factory AssessmentQuestion.fromJson(Map<String, dynamic> j) =>
      AssessmentQuestion(
        question: (j['question'] ?? '').toString(),
        options:
            (j['options'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

class AssessmentSession {
  final String id;
  final String skill;
  final String level;
  final int passingScore;
  final List<AssessmentQuestion> questions;
  const AssessmentSession({
    required this.id,
    required this.skill,
    required this.level,
    required this.passingScore,
    required this.questions,
  });
  factory AssessmentSession.fromJson(Map<String, dynamic> j) =>
      AssessmentSession(
        id: (j['id'] ?? '').toString(),
        skill: (j['skill'] ?? '').toString(),
        level: (j['level'] ?? 'intermediate').toString(),
        passingScore: (j['passingScore'] as num?)?.toInt() ?? 70,
        questions: (j['questions'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AssessmentQuestion.fromJson)
                .toList() ??
            const [],
      );
}

class AssessmentReviewItem {
  final String question;
  final List<String> options;
  final int correctIndex;
  final int? selectedIndex;
  final bool isCorrect;
  final String? explanation;
  const AssessmentReviewItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
    required this.isCorrect,
    this.explanation,
  });
  factory AssessmentReviewItem.fromJson(Map<String, dynamic> j) =>
      AssessmentReviewItem(
        question: (j['question'] ?? '').toString(),
        options:
            (j['options'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? -1,
        selectedIndex: (j['selectedIndex'] as num?)?.toInt(),
        isCorrect: j['isCorrect'] as bool? ?? false,
        explanation: j['explanation'] as String?,
      );
}

class AssessmentResult {
  final String id;
  final String skill;
  final int scorePercent;
  final int correctAnswers;
  final int total;
  final bool isPassed;
  final bool badgeAwarded;
  final List<AssessmentReviewItem> review;
  const AssessmentResult({
    required this.id,
    required this.skill,
    required this.scorePercent,
    required this.correctAnswers,
    required this.total,
    required this.isPassed,
    required this.badgeAwarded,
    required this.review,
  });
  factory AssessmentResult.fromJson(Map<String, dynamic> j) =>
      AssessmentResult(
        id: (j['id'] ?? '').toString(),
        skill: (j['skill'] ?? '').toString(),
        scorePercent: (j['scorePercent'] as num?)?.toInt() ?? 0,
        correctAnswers: (j['correctAnswers'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        isPassed: j['isPassed'] as bool? ?? false,
        badgeAwarded: j['badgeAwarded'] as bool? ?? false,
        review: (j['review'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AssessmentReviewItem.fromJson)
                .toList() ??
            const [],
      );
}

class AssessmentSummary {
  final String id;
  final String skill;
  final String level;
  final int scorePercent;
  final bool isPassed;
  final bool badgeAwarded;
  final DateTime? completedAt;
  const AssessmentSummary({
    required this.id,
    required this.skill,
    required this.level,
    required this.scorePercent,
    required this.isPassed,
    required this.badgeAwarded,
    this.completedAt,
  });
  factory AssessmentSummary.fromJson(Map<String, dynamic> j) =>
      AssessmentSummary(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        skill: (j['skill'] ?? '').toString(),
        level: (j['level'] ?? 'intermediate').toString(),
        scorePercent: (j['scorePercent'] as num?)?.toInt() ?? 0,
        isPassed: j['isPassed'] as bool? ?? false,
        badgeAwarded: j['badgeAwarded'] as bool? ?? false,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.tryParse(j['completedAt'].toString()),
      );
}

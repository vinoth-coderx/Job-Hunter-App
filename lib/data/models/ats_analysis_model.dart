/// Mirror of `services/ai/atsScorer.service.ts:AtsAnalysisResult` and the
/// `formattingIssues` row shape on the same file.
class AtsFormattingIssue {
  final String category; // formatting | keywords | experience | skills | contact | other
  final String severity; // high | medium | low
  final String message;
  const AtsFormattingIssue({
    required this.category,
    required this.severity,
    required this.message,
  });

  factory AtsFormattingIssue.fromJson(Map<String, dynamic> j) =>
      AtsFormattingIssue(
        category: (j['category'] ?? 'other').toString(),
        severity: (j['severity'] ?? 'medium').toString(),
        message: (j['message'] ?? '').toString(),
      );
}

class AtsAnalysisResult {
  final int score;
  final List<String> matchedSkills;
  final List<String> missingKeywords;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> suggestions;
  final List<AtsFormattingIssue> formattingIssues;
  final bool usedAi;
  final bool cached;
  final DateTime generatedAt;

  const AtsAnalysisResult({
    required this.score,
    required this.matchedSkills,
    required this.missingKeywords,
    required this.strengths,
    required this.weaknesses,
    required this.suggestions,
    required this.formattingIssues,
    required this.usedAi,
    required this.cached,
    required this.generatedAt,
  });

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  factory AtsAnalysisResult.fromJson(Map<String, dynamic> j) =>
      AtsAnalysisResult(
        score: (j['score'] as num?)?.toInt() ?? 0,
        matchedSkills: _stringList(j['matchedSkills']),
        missingKeywords: _stringList(j['missingKeywords']),
        strengths: _stringList(j['strengths']),
        weaknesses: _stringList(j['weaknesses']),
        suggestions: _stringList(j['suggestions']),
        formattingIssues: (j['formattingIssues'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    AtsFormattingIssue.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        usedAi: j['usedAi'] as bool? ?? false,
        cached: j['cached'] as bool? ?? false,
        generatedAt: DateTime.tryParse((j['generatedAt'] ?? '').toString()) ??
            DateTime.now(),
      );

  /// Bucket label for the donut centre — keeps the UI synced with the
  /// backend prompt's score-band guidance (90+ excellent, 70+ strong,
  /// 50+ needs work, <50 significant gaps).
  String get band {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Strong';
    if (score >= 50) return 'Needs work';
    return 'Significant gaps';
  }
}

class AtsHistoryEntry {
  final String id;
  final int score;
  final String? jobId;
  final bool usedAi;
  final DateTime createdAt;
  const AtsHistoryEntry({
    required this.id,
    required this.score,
    required this.jobId,
    required this.usedAi,
    required this.createdAt,
  });

  factory AtsHistoryEntry.fromJson(Map<String, dynamic> j) => AtsHistoryEntry(
        id: (j['id'] ?? '').toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        jobId: j['jobId'] as String?,
        usedAi: j['usedAi'] as bool? ?? false,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}

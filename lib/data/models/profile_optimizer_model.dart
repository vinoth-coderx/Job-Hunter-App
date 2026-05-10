enum SuggestionPriority { high, medium, low }

class ProfileSuggestion {
  final String field;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final List<String>? suggestedValues;
  final String? suggestedText;

  const ProfileSuggestion({
    required this.field,
    required this.priority,
    required this.title,
    required this.description,
    this.suggestedValues,
    this.suggestedText,
  });

  factory ProfileSuggestion.fromJson(Map<String, dynamic> j) {
    final raw = j['suggestedValue'];
    List<String>? values;
    String? text;
    if (raw is List) {
      values = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      text = raw;
    }
    return ProfileSuggestion(
      field: (j['field'] ?? 'general').toString(),
      priority: switch ((j['priority'] ?? 'medium').toString()) {
        'high' => SuggestionPriority.high,
        'low' => SuggestionPriority.low,
        _ => SuggestionPriority.medium,
      },
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      suggestedValues: values,
      suggestedText: text,
    );
  }
}

class ProfileOptimizationResult {
  final int completenessScore;
  final List<ProfileSuggestion> suggestions;
  final bool usedAi;
  final DateTime? generatedAt;

  const ProfileOptimizationResult({
    required this.completenessScore,
    required this.suggestions,
    required this.usedAi,
    this.generatedAt,
  });

  factory ProfileOptimizationResult.fromJson(Map<String, dynamic> j) =>
      ProfileOptimizationResult(
        completenessScore: (j['completenessScore'] as num?)?.toInt() ?? 0,
        suggestions: (j['suggestions'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ProfileSuggestion.fromJson)
                .toList() ??
            const [],
        usedAi: j['usedAi'] as bool? ?? false,
        generatedAt: j['generatedAt'] == null
            ? null
            : DateTime.tryParse(j['generatedAt'].toString()),
      );
}

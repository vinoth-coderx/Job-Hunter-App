class AutoApplyPreferences {
  final List<String> targetRoles;
  final List<String> locations;
  final bool isOpenToRemote;
  final List<String> jobTypes;
  final int? minSalary;
  final List<String> experienceLevels;
  final List<String> sources; // 'native' | 'external'
  final List<String> companySizes;

  const AutoApplyPreferences({
    this.targetRoles = const [],
    this.locations = const [],
    this.isOpenToRemote = true,
    this.jobTypes = const [],
    this.minSalary,
    this.experienceLevels = const [],
    this.sources = const ['native'],
    this.companySizes = const [],
  });

  factory AutoApplyPreferences.fromJson(Map<String, dynamic> j) =>
      AutoApplyPreferences(
        targetRoles: (j['targetRoles'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        locations: (j['locations'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isOpenToRemote: j['isOpenToRemote'] as bool? ?? true,
        jobTypes: (j['jobTypes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        minSalary: (j['minSalary'] as num?)?.toInt(),
        experienceLevels: (j['experienceLevels'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        sources: (j['sources'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['native'],
        companySizes: (j['companySizes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'targetRoles': targetRoles,
        'locations': locations,
        'isOpenToRemote': isOpenToRemote,
        'jobTypes': jobTypes,
        if (minSalary != null) 'minSalary': minSalary,
        'experienceLevels': experienceLevels,
        'sources': sources,
        'companySizes': companySizes,
      };

  AutoApplyPreferences copyWith({
    List<String>? targetRoles,
    List<String>? locations,
    bool? isOpenToRemote,
    List<String>? jobTypes,
    int? minSalary,
    List<String>? experienceLevels,
    List<String>? sources,
    List<String>? companySizes,
  }) =>
      AutoApplyPreferences(
        targetRoles: targetRoles ?? this.targetRoles,
        locations: locations ?? this.locations,
        isOpenToRemote: isOpenToRemote ?? this.isOpenToRemote,
        jobTypes: jobTypes ?? this.jobTypes,
        minSalary: minSalary ?? this.minSalary,
        experienceLevels: experienceLevels ?? this.experienceLevels,
        sources: sources ?? this.sources,
        companySizes: companySizes ?? this.companySizes,
      );
}

class AutoApplyMatchingRules {
  final int minMatchPercentage;
  final int minSkillsMatchCount;
  final List<String> mustIncludeKeywords;
  final List<String> excludeKeywords;
  final List<String> blacklistedCompanies;
  final int reapplyCooldownDays; // 30 | 60 | 90

  const AutoApplyMatchingRules({
    this.minMatchPercentage = 70,
    this.minSkillsMatchCount = 2,
    this.mustIncludeKeywords = const [],
    this.excludeKeywords = const [],
    this.blacklistedCompanies = const [],
    this.reapplyCooldownDays = 60,
  });

  factory AutoApplyMatchingRules.fromJson(Map<String, dynamic> j) =>
      AutoApplyMatchingRules(
        minMatchPercentage: (j['minMatchPercentage'] as num?)?.toInt() ?? 70,
        minSkillsMatchCount:
            (j['minSkillsMatchCount'] as num?)?.toInt() ?? 2,
        mustIncludeKeywords: (j['mustIncludeKeywords'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        excludeKeywords: (j['excludeKeywords'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        blacklistedCompanies: (j['blacklistedCompanies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        reapplyCooldownDays:
            (j['reapplyCooldownDays'] as num?)?.toInt() ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'minMatchPercentage': minMatchPercentage,
        'minSkillsMatchCount': minSkillsMatchCount,
        'mustIncludeKeywords': mustIncludeKeywords,
        'excludeKeywords': excludeKeywords,
        'blacklistedCompanies': blacklistedCompanies,
        'reapplyCooldownDays': reapplyCooldownDays,
      };

  AutoApplyMatchingRules copyWith({
    int? minMatchPercentage,
    int? minSkillsMatchCount,
    List<String>? mustIncludeKeywords,
    List<String>? excludeKeywords,
    List<String>? blacklistedCompanies,
    int? reapplyCooldownDays,
  }) =>
      AutoApplyMatchingRules(
        minMatchPercentage: minMatchPercentage ?? this.minMatchPercentage,
        minSkillsMatchCount: minSkillsMatchCount ?? this.minSkillsMatchCount,
        mustIncludeKeywords: mustIncludeKeywords ?? this.mustIncludeKeywords,
        excludeKeywords: excludeKeywords ?? this.excludeKeywords,
        blacklistedCompanies:
            blacklistedCompanies ?? this.blacklistedCompanies,
        reapplyCooldownDays: reapplyCooldownDays ?? this.reapplyCooldownDays,
      );
}

class AutoApplyAiCoverLetter {
  final bool enabled;
  final String tone; // 'professional' | 'friendly' | 'technical'
  final String? baseTemplate;

  const AutoApplyAiCoverLetter({
    this.enabled = false,
    this.tone = 'professional',
    this.baseTemplate,
  });

  factory AutoApplyAiCoverLetter.fromJson(Map<String, dynamic> j) =>
      AutoApplyAiCoverLetter(
        enabled: j['enabled'] as bool? ?? false,
        tone: (j['tone'] ?? 'professional').toString(),
        baseTemplate: j['baseTemplate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'tone': tone,
        if (baseTemplate != null && baseTemplate!.isNotEmpty)
          'baseTemplate': baseTemplate,
      };
}

/// Snapshot of the auto-apply free trial. Mirrors the backend
/// limits.ts TrialState — keep field names in sync.
class AutoApplyTrial {
  /// True while the trial is live (within 7 days of activation).
  final bool active;

  /// True iff the user has previously activated the trial. Once true,
  /// it never flips back — the trial is one-shot.
  final bool used;

  /// When the trial expires. Null when never activated; non-null
  /// otherwise even after expiry, so the UI can say "trial ended on X".
  final DateTime? endsAt;

  final int durationDays;

  const AutoApplyTrial({
    required this.active,
    required this.used,
    required this.endsAt,
    required this.durationDays,
  });

  static const empty = AutoApplyTrial(
    active: false,
    used: false,
    endsAt: null,
    durationDays: 7,
  );

  factory AutoApplyTrial.fromJson(Map<String, dynamic> j) => AutoApplyTrial(
        active: j['active'] as bool? ?? false,
        used: j['used'] as bool? ?? false,
        endsAt: j['endsAt'] == null
            ? null
            : DateTime.tryParse(j['endsAt'].toString()),
        durationDays: (j['durationDays'] as num?)?.toInt() ?? 7,
      );
}

class AutoApplySettings {
  final String id;
  final bool isEnabled;
  final bool isPaused;
  final DateTime? pauseUntil;
  final String? pauseReason;
  final String runTime;
  final List<String> runDays;
  final int dailyLimit;
  final AutoApplyPreferences preferences;
  final AutoApplyMatchingRules matchingRules;
  final bool reviewMode;
  final AutoApplyAiCoverLetter aiCoverLetter;
  final int totalAutoApplied;
  final DateTime? lastRunAt;
  final String tier; // free|weekly|monthly|yearly
  final int planCap;
  final bool eligible;
  final AutoApplyTrial trial;

  const AutoApplySettings({
    required this.id,
    required this.isEnabled,
    required this.isPaused,
    this.pauseUntil,
    this.pauseReason,
    required this.runTime,
    required this.runDays,
    required this.dailyLimit,
    required this.preferences,
    required this.matchingRules,
    required this.reviewMode,
    required this.aiCoverLetter,
    required this.totalAutoApplied,
    this.lastRunAt,
    required this.tier,
    required this.planCap,
    required this.eligible,
    this.trial = AutoApplyTrial.empty,
  });

  factory AutoApplySettings.fromJson(Map<String, dynamic> j) =>
      AutoApplySettings(
        id: (j['id'] ?? '').toString(),
        isEnabled: j['isEnabled'] as bool? ?? false,
        isPaused: j['isPaused'] as bool? ?? false,
        pauseUntil: j['pauseUntil'] == null
            ? null
            : DateTime.tryParse(j['pauseUntil'].toString()),
        pauseReason: j['pauseReason'] as String?,
        runTime: (j['runTime'] ?? '09:00').toString(),
        runDays: (j['runDays'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
        dailyLimit: (j['dailyLimit'] as num?)?.toInt() ?? 10,
        preferences: j['preferences'] is Map<String, dynamic>
            ? AutoApplyPreferences.fromJson(
                j['preferences'] as Map<String, dynamic>)
            : const AutoApplyPreferences(),
        matchingRules: j['matchingRules'] is Map<String, dynamic>
            ? AutoApplyMatchingRules.fromJson(
                j['matchingRules'] as Map<String, dynamic>)
            : const AutoApplyMatchingRules(),
        reviewMode: j['reviewMode'] as bool? ?? true,
        aiCoverLetter: j['aiCoverLetter'] is Map<String, dynamic>
            ? AutoApplyAiCoverLetter.fromJson(
                j['aiCoverLetter'] as Map<String, dynamic>)
            : const AutoApplyAiCoverLetter(),
        totalAutoApplied: (j['totalAutoApplied'] as num?)?.toInt() ?? 0,
        lastRunAt: j['lastRunAt'] == null
            ? null
            : DateTime.tryParse(j['lastRunAt'].toString()),
        tier: (j['tier'] ?? 'free').toString(),
        planCap: (j['planCap'] as num?)?.toInt() ?? 0,
        eligible: j['eligible'] as bool? ?? false,
        trial: j['trial'] is Map<String, dynamic>
            ? AutoApplyTrial.fromJson(j['trial'] as Map<String, dynamic>)
            : AutoApplyTrial.empty,
      );
}

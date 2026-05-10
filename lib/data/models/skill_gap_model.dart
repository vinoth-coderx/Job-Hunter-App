class DemandedSkill {
  final String skill;
  final int demandPercent;
  const DemandedSkill({required this.skill, required this.demandPercent});
  factory DemandedSkill.fromJson(Map<String, dynamic> j) => DemandedSkill(
        skill: (j['skill'] ?? '').toString(),
        demandPercent: (j['demandPercent'] as num?)?.toInt() ?? 0,
      );
}

class SkillResource {
  final String skill;
  final String title;
  final String type; // 'course' | 'book' | 'tutorial' | 'project'
  final String? url;
  final int? estimatedHours;
  const SkillResource({
    required this.skill,
    required this.title,
    required this.type,
    this.url,
    this.estimatedHours,
  });
  factory SkillResource.fromJson(Map<String, dynamic> j) => SkillResource(
        skill: (j['skill'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        type: (j['type'] ?? 'course').toString(),
        url: j['url'] as String?,
        estimatedHours: (j['estimatedHours'] as num?)?.toInt(),
      );
}

class SkillGapResult {
  final String role;
  final String? city;
  final int jobsAnalyzed;
  final int readinessScore;
  final List<DemandedSkill> matchedSkills;
  final List<DemandedSkill> missingSkills;
  final List<SkillResource> resources;
  final bool usedAi;

  const SkillGapResult({
    required this.role,
    this.city,
    required this.jobsAnalyzed,
    required this.readinessScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.resources,
    required this.usedAi,
  });

  factory SkillGapResult.fromJson(Map<String, dynamic> j) => SkillGapResult(
        role: (j['role'] ?? '').toString(),
        city: j['city'] as String?,
        jobsAnalyzed: (j['jobsAnalyzed'] as num?)?.toInt() ?? 0,
        readinessScore: (j['readinessScore'] as num?)?.toInt() ?? 0,
        matchedSkills: (j['matchedSkills'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DemandedSkill.fromJson)
                .toList() ??
            const [],
        missingSkills: (j['missingSkills'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DemandedSkill.fromJson)
                .toList() ??
            const [],
        resources: (j['resources'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(SkillResource.fromJson)
                .toList() ??
            const [],
        usedAi: j['usedAi'] as bool? ?? false,
      );
}

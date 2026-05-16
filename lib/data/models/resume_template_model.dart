/// User-facing resume template (catalog item).
///
/// The backend exposes two endpoints:
///   - GET /resume-templates           — list view (no html)
///   - GET /resume-templates/:slug      — detail view (includes live html)
class ResumeTemplateSummary {
  ResumeTemplateSummary({
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.previewImageUrl,
    required this.atsScore,
    required this.isPremium,
  });

  final String slug;
  final String name;
  final String description;
  final String category;
  final String? previewImageUrl;
  final int atsScore;
  final bool isPremium;

  factory ResumeTemplateSummary.fromJson(Map<String, dynamic> json) {
    return ResumeTemplateSummary(
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'general',
      previewImageUrl: json['previewImageUrl'] as String?,
      atsScore: (json['atsScore'] as num?)?.toInt() ?? 0,
      isPremium: (json['isPremium'] as bool?) ?? false,
    );
  }
}

class ResumeTemplateDetail extends ResumeTemplateSummary {
  ResumeTemplateDetail({
    required super.slug,
    required super.name,
    required super.description,
    required super.category,
    required super.previewImageUrl,
    required super.atsScore,
    required super.isPremium,
    required this.html,
  });

  final String html;

  factory ResumeTemplateDetail.fromJson(Map<String, dynamic> json) {
    return ResumeTemplateDetail(
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'general',
      previewImageUrl: json['previewImageUrl'] as String?,
      atsScore: (json['atsScore'] as num?)?.toInt() ?? 0,
      isPremium: (json['isPremium'] as bool?) ?? false,
      html: (json['html'] as String?) ?? '',
    );
  }
}

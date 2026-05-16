/// Mirror of `services/ai/resumeRewriter.service.ts:RewriteResult`.
class ResumeRewriteResult {
  /// The primary rewrite the UI should slot into the field by default.
  final String text;

  /// Up to 3 alternative phrasings the user can swap to. Empty when the
  /// model returned only one variant or when the call fell back without
  /// running AI.
  final List<String> alternates;
  final bool usedAi;
  final bool cached;

  const ResumeRewriteResult({
    required this.text,
    required this.alternates,
    required this.usedAi,
    required this.cached,
  });

  factory ResumeRewriteResult.fromJson(Map<String, dynamic> j) =>
      ResumeRewriteResult(
        text: (j['text'] ?? '').toString(),
        alternates: (j['alternates'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        usedAi: j['usedAi'] as bool? ?? false,
        cached: j['cached'] as bool? ?? false,
      );

  /// Convenience for the picker UI: primary first, then alternates.
  List<String> get allOptions => [text, ...alternates];
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/skill_gap_model.dart';
import '../../data/services/ai_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class SkillGapScreen extends StatefulWidget {
  const SkillGapScreen({super.key});

  @override
  State<SkillGapScreen> createState() => _SkillGapScreenState();
}

class _SkillGapScreenState extends State<SkillGapScreen>
    with TapGuardMixin<SkillGapScreen> {
  final _role = TextEditingController();
  final _city = TextEditingController();

  Future<SkillGapResult>? _future;

  // Skills the user has added to their profile this session — used to
  // move chips from the "missing" wrap into "you already have" without
  // waiting for a backend re-analysis.
  final Set<String> _adoptedSkills = {};
  // Skills currently being PATCHed — drives the per-chip spinner so the
  // user gets immediate feedback the tap was registered.
  final Set<String> _addingSkills = {};

  @override
  void dispose() {
    _role.dispose();
    _city.dispose();
    super.dispose();
  }

  void _go() {
    final r = _role.text.trim();
    if (r.length < 2) {
      AppSnackbar.error(context, 'Enter a target role');
      return;
    }
    setState(() {
      _adoptedSkills.clear();
      _addingSkills.clear();
      _future = AiService.instance.skillGap(
        role: r,
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      );
    });
  }

  /// Adopt a missing skill into the user's profile. Optimistic — we mark
  /// the chip as "adopted" first, then PATCH; on failure we roll back.
  Future<void> _adoptSkill(String skill) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final lower = skill.toLowerCase();
    if (_adoptedSkills.contains(lower) || _addingSkills.contains(lower)) {
      return;
    }
    setState(() => _addingSkills.add(lower));

    final next = <String>{
      ...user.skills,
      skill,
    };
    final ok = await auth.updateProfile(skills: next.toList());
    if (!mounted) return;
    setState(() {
      _addingSkills.remove(lower);
      if (ok) {
        _adoptedSkills.add(lower);
      }
    });
    if (ok) {
      AppSnackbar.success(context, 'Added "$skill" to your profile');
    } else {
      AppSnackbar.error(context, 'Could not add this skill');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Skill Gap',
                    style: AppTextStyles.h4
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'See what to learn next',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: context.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _searchCard(),
          const SizedBox(height: 12),
          if (_future != null)
            FutureBuilder<SkillGapResult>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(snap.error.toString(),
                        textAlign: TextAlign.center),
                  );
                }
                final r = snap.data!;
                if (r.jobsAnalyzed == 0) return _notEnoughCard(r);
                return _resultsView(r);
              },
            ),
        ],
      ),
    );
  }

  Widget _searchCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          children: [
            CustomTextField(
              controller: _role,
              hint: 'Target role (e.g., Backend Developer)',
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _city,
              hint: 'City (optional)',
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Analyse my gaps',
              icon: Icons.auto_awesome,
              onPressed: _go,
            ),
          ],
        ),
      );

  Widget _notEnoughCard(SkillGapResult r) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off,
                size: 48, color: context.textTertiary),
            const SizedBox(height: 8),
            Text('No active jobs found for "${r.role}"',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary)),
            const SizedBox(height: 4),
            Text(
              'Try a broader role title or remove the city filter.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textTertiary),
            ),
          ],
        ),
      );

  Widget _resultsView(SkillGapResult r) {
    Color color;
    String label;
    if (r.readinessScore >= 75) {
      color = AppColors.success;
      label = 'Ready';
    } else if (r.readinessScore >= 50) {
      color = AppColors.warning;
      label = 'Partial fit';
    } else {
      color = AppColors.urgent;
      label = 'Big gap';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: r.readinessScore / 100,
                      strokeWidth: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.2),
                    ),
                    Text('${r.readinessScore}%',
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.h4
                            .copyWith(color: context.textPrimary)),
                    Text(
                      'Based on ${r.jobsAnalyzed} active ${r.role} job${r.jobsAnalyzed == 1 ? '' : 's'}'
                      '${r.city != null && r.city!.isNotEmpty ? " in ${r.city}" : ""}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Re-bucket missing → matched on the fly when the user adopts a
        // chip. Avoids a round-trip to /skill-gap just to update the UI.
        ..._buildBuckets(r),
        if (r.resources.isNotEmpty) ...[
          _sectionTitle('Suggested resources', AppColors.primary,
              trailing: r.usedAi ? 'AI' : null),
          const SizedBox(height: 6),
          ...r.resources.map(_resourceCard),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text, Color color, {String? trailing}) => Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(trailing,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  )),
            ),
        ],
      );

  /// Renders the "have" + "missing" sections, accounting for any skills
  /// the user adopted this session (which need to move from missing →
  /// matched without waiting for a server re-analysis).
  List<Widget> _buildBuckets(SkillGapResult r) {
    final adopted = _adoptedSkills;
    final stillMissing = r.missingSkills
        .where((s) => !adopted.contains(s.skill.toLowerCase()))
        .toList();
    final extraMatched = r.missingSkills
        .where((s) => adopted.contains(s.skill.toLowerCase()))
        .toList();
    final allMatched = [...r.matchedSkills, ...extraMatched];

    return [
      if (allMatched.isNotEmpty) ...[
        _sectionTitle('You already have', AppColors.success),
        const SizedBox(height: 6),
        _matchedWrap(allMatched),
        const SizedBox(height: 16),
      ],
      if (stillMissing.isNotEmpty) ...[
        _sectionTitle('Skills you\'re missing', AppColors.urgent,
            trailing: 'TAP TO ADD'),
        const SizedBox(height: 6),
        _missingWrap(stillMissing),
        const SizedBox(height: 16),
      ],
    ];
  }

  Widget _matchedWrap(List<DemandedSkill> skills) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: skills
            .map((s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(s.skill,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('${s.demandPercent}%',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: context.textTertiary)),
                    ],
                  ),
                ))
            .toList(),
      );

  Widget _missingWrap(List<DemandedSkill> skills) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: skills.map((s) {
          final adding = _addingSkills.contains(s.skill.toLowerCase());
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: adding ? null : () => _adoptSkill(s.skill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.urgent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.urgent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (adding)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.urgent,
                      ),
                    )
                  else
                    const Icon(Icons.add_circle_outline,
                        size: 14, color: AppColors.urgent),
                  const SizedBox(width: 4),
                  Text(s.skill,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.urgent,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('${s.demandPercent}%',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: context.textTertiary)),
                ],
              ),
            ),
          );
        }).toList(),
      );

  Widget _resourceCard(SkillResource r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          children: [
            Icon(_iconFor(r.type), color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      r.skill,
                      r.type,
                      if (r.estimatedHours != null) '~${r.estimatedHours}h',
                    ].join(' · '),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            if (r.url != null && r.url!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => guard(
                  () async {
                    final uri = Uri.tryParse(r.url!);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  key: 'open-${r.url}',
                ),
              ),
          ],
        ),
      );

  IconData _iconFor(String type) => switch (type) {
        'book' => Icons.menu_book_rounded,
        'tutorial' => Icons.play_circle_outline,
        'project' => Icons.code,
        _ => Icons.school_outlined,
      };
}

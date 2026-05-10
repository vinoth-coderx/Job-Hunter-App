import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/ai_field_suggestion.dart';
import '../../data/models/profile_optimizer_model.dart';
import '../../data/services/ai_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_profile_provider.dart';
import '../widgets/app_text.dart';

class ProfileOptimizerScreen extends StatefulWidget {
  const ProfileOptimizerScreen({super.key});

  @override
  State<ProfileOptimizerScreen> createState() => _ProfileOptimizerScreenState();
}

class _ProfileOptimizerScreenState extends State<ProfileOptimizerScreen> {
  Future<ProfileOptimizationResult>? _future;
  ProfileOptimizationResult? _last;

  /// Suggestion titles the user already applied this session — drives the
  /// "Applied" green chip without waiting for the backend to drop them
  /// from the next analysis.
  final Set<String> _appliedTitles = {};

  /// Per-card AI-generated values, keyed by the suggestion title. Lets a
  /// user tap "Generate" → see the value → then "Apply" without losing
  /// state on a rebuild.
  final Map<String, AiFieldSuggestion> _generatedValues = {};

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh(force: false);
  }

  void _refresh({bool force = true}) {
    // Skip the AI call entirely when the profile is empty — there's
    // nothing for the optimizer to grade, and it would burn a quota
    // slot for noise. The UI renders the empty-state CTA instead.
    if (!_hasProfileData()) {
      setState(() {
        _refreshing = false;
        _future = null;
        _last = null;
      });
      return;
    }
    setState(() {
      _refreshing = force;
      _future = AiService.instance.profileOptimizer(refresh: force);
    });
    _future!.then((r) {
      if (!mounted) return;
      setState(() {
        _last = r;
        _refreshing = false;
        if (force) {
          // A fresh AI run reflects whatever the user applied — wipe per-
          // session marks so the new suggestion list is treated honestly.
          _appliedTitles.clear();
          _generatedValues.clear();
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _refreshing = false);
    });
  }

  /// Coach has nothing to grade until the seeker has either uploaded a
  /// resume or filled at least one core profile field. Gate the screen
  /// so we don't show garbage suggestions (or burn a quota slot) for an
  /// empty profile — the empty-state CTA points the user to fill it in.
  bool _hasProfileData() {
    final user = context.read<AuthProvider>().user;
    if (user != null &&
        (user.headline.trim().isNotEmpty ||
            user.skills.isNotEmpty ||
            user.preferredRoles.isNotEmpty ||
            user.experienceYears > 0)) {
      return true;
    }
    final resume = context.read<ResumeProfileProvider>().profile;
    return resume.resumeFileName.trim().isNotEmpty;
  }

  // ── Field plumbing ─────────────────────────────────────────────────

  /// Maps the AI's suggestion `field` string to the canonical key the
  /// backend (and our generator/applier) understands. The optimizer
  /// schema uses 'expectedSalary' but other surfaces sometimes say
  /// 'salary' or 'jobType' — normalise once, here.
  static String _canonicalField(String field) {
    switch (field) {
      case 'jobType':
      case 'jobTypes':
        return 'preferredJobTypes';
      case 'salary':
        return 'expectedSalary';
      case 'experience':
        return 'experienceYears';
      // 'summary' has no backend field — the optimizer treats it like an
      // extended headline; map it so Apply lands somewhere useful.
      case 'summary':
        return 'headline';
      default:
        return field;
    }
  }

  /// Fields whose `suggestedValue` we can pipe straight into
  /// AuthProvider.updateProfile. Anything else falls back to the manual
  /// "Open profile" path.
  static const _autoApplyableFields = {
    'headline',
    'summary',
    'skills',
    'preferredRoles',
    'preferredLocations',
    'preferredJobTypes',
    'expectedSalary',
    'experienceYears',
  };

  /// Apply a structured suggestion (or a generated value) to the user's
  /// profile via AuthProvider. Returns true on success.
  Future<bool> _applyValue({
    required String field,
    String? text,
    List<String>? values,
    num? numericValue,
  }) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return false;

    final canonical = _canonicalField(field);

    switch (canonical) {
      case 'headline':
        final v = text ?? values?.first;
        if (v == null || v.isEmpty) return false;
        return auth.updateProfile(headline: v);

      case 'skills':
        final next = <String>{...user.skills};
        if (values != null) next.addAll(values);
        if (text != null && text.isNotEmpty) next.add(text);
        return auth.updateProfile(skills: next.toList());

      case 'preferredRoles':
        final next = <String>{...user.preferredRoles};
        if (values != null) next.addAll(values);
        if (text != null && text.isNotEmpty) next.add(text);
        return auth.updateProfile(preferredRoles: next.toList());

      case 'preferredLocations':
        final next = <String>{...user.preferredLocations};
        if (values != null) next.addAll(values);
        if (text != null && text.isNotEmpty) next.add(text);
        return auth.updateProfile(preferredLocations: next.toList());

      case 'preferredJobTypes':
        // Read existing list off the user model; we don't keep a Dart-
        // level field for this so we round-trip via auth.user dynamic.
        final existing = (user.preferredJobTypes).toList();
        final next = <String>{...existing};
        if (values != null) next.addAll(values.map((s) => s.toLowerCase()));
        if (text != null && text.isNotEmpty) next.add(text.toLowerCase());
        return auth.updateProfile(preferredJobTypes: next.toList());

      case 'experienceYears':
        int? n = numericValue?.toInt();
        if (n == null && text != null) {
          final m = RegExp(r'(\d+)').firstMatch(text);
          n = m == null ? null : int.tryParse(m.group(1)!);
        }
        if (n == null || n < 0 || n > 50) return false;
        return auth.updateProfile(experienceYears: n);

      case 'expectedSalary':
        int? n = numericValue?.toInt();
        if (n == null) {
          final raw = text ?? values?.first ?? '';
          final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
          n = int.tryParse(digits);
          // "6 LPA" / "6" → assume lakhs and scale up.
          if (n != null && n > 0 && n < 200) n = n * 100000;
        }
        if (n == null || n <= 0) return false;
        return auth.updateProfile(expectedSalaryMin: n);

      default:
        return false;
    }
  }

  Future<void> _applySuggestion(ProfileSuggestion s) async {
    final ok = await _applyValue(
      field: s.field,
      text: s.suggestedText,
      values: s.suggestedValues,
    );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Added to your profile');
      setState(() => _appliedTitles.add(s.title));
      // Force-refresh so the score recomputes AND the next suggestion
      // list reflects the new profile state. Backend cache is busted by
      // updateProfile, so this isn't redundant.
      _refresh(force: true);
    } else {
      AppSnackbar.error(context, 'Could not apply this suggestion');
    }
  }

  Future<void> _applyGenerated(
      ProfileSuggestion s, AiFieldSuggestion g) async {
    final ok = await _applyValue(
      field: s.field,
      text: g.value,
      values: g.values,
      numericValue: g.numericValue,
    );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, 'Added to your profile');
      setState(() {
        _appliedTitles.add(s.title);
        _generatedValues.remove(s.title);
      });
      _refresh(force: true);
    } else {
      AppSnackbar.error(context, 'Could not apply this suggestion');
    }
  }

  Future<void> _generateValue(ProfileSuggestion s) async {
    final canonical = _canonicalField(s.field);
    if (!_autoApplyableFields.contains(canonical)) return;

    try {
      final res = await AiService.instance.profileFieldSuggest(field: canonical);
      if (!mounted) return;
      // Quota always comes back; feed it to the global provider so the
      // banner stays in sync with reality.
      context.read<AiQuotaProvider>().update(res.quota);

      if (res.data == null || !res.data!.hasValue) {
        AppSnackbar.error(context, 'AI couldn\'t generate a value for this');
        return;
      }
      setState(() => _generatedValues[s.title] = res.data!);
    } on AiQuotaExceededException catch (e) {
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(e.quota);
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Generate failed: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

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
                Text('Profile Coach',
                    style: AppTextStyles.h4
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                _aiPill(),
              ],
            ),
            Text(
              'Make recruiters notice you',
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
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'New angle',
            onPressed: _refreshing ? null : () => _refresh(force: true),
          ),
        ],
      ),
      body: !_hasProfileData()
          ? _emptyProfileGate()
          : FutureBuilder<ProfileOptimizationResult>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _last == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError && _last == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(snap.error.toString(),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final r = snap.data ?? _last!;
                return RefreshIndicator(
                  onRefresh: () async => _refresh(force: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _scoreCard(r),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        '${r.suggestions.length} suggestions',
                        trailing: r.usedAi ? 'AI' : null,
                      ),
                      const SizedBox(height: 8),
                      ...r.suggestions.map(_card),
                      if (r.suggestions.isEmpty) _allDoneCard(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _aiPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      );

  Widget _emptyProfileGate() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Add your profile first',
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Coach needs a profile to grade. Upload a resume or fill in your headline, skills and preferred roles — then come back for AI suggestions.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: context.textSecondary,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                      context, AppRoutes.resumeProfile);
                  if (!mounted) return;
                  setState(() {});
                  _refresh(force: false);
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload resume'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                      context, AppRoutes.profileInformation);
                  if (!mounted) return;
                  setState(() {});
                  _refresh(force: false);
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Fill profile'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _allDoneCard() => Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: AppText.body(
                'Your profile looks great — no high-impact changes suggested.',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );

  Widget _scoreCard(ProfileOptimizationResult r) {
    final score = r.completenessScore;
    Color color;
    String label;
    if (score >= 100) {
      color = AppColors.success;
      label = 'Profile complete';
    } else if (score >= 85) {
      color = AppColors.success;
      label = 'Excellent';
    } else if (score >= 60) {
      color = AppColors.warning;
      label = 'Good — room to improve';
    } else {
      color = AppColors.urgent;
      label = 'Needs work';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: v,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.2),
                  ),
                  Text('${(v * 100).round()}%',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: color, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.caption('Profile completeness',
                    color: context.textSecondary),
                AppText.h4(label),
                if (score < 100) ...[
                  const SizedBox(height: 2),
                  AppText.caption(
                    score >= 85
                        ? 'Apply the suggestions below to push to 100%'
                        : 'Tap "Apply" or "Generate" to boost your score',
                    color: context.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ProfileSuggestion s) {
    final applied = _appliedTitles.contains(s.title);
    final canonical = _canonicalField(s.field);
    final hasStructuredValue =
        (s.suggestedText != null && s.suggestedText!.isNotEmpty) ||
            (s.suggestedValues != null && s.suggestedValues!.isNotEmpty);
    final supports = _autoApplyableFields.contains(canonical);
    final generated = _generatedValues[s.title];

    Color priorityColor;
    String priorityLabel;
    switch (s.priority) {
      case SuggestionPriority.high:
        priorityColor = AppColors.urgent;
        priorityLabel = 'HIGH';
        break;
      case SuggestionPriority.medium:
        priorityColor = AppColors.warning;
        priorityLabel = 'MEDIUM';
        break;
      case SuggestionPriority.low:
        priorityColor = context.textTertiary;
        priorityLabel = 'LOW';
        break;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: applied ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: applied
                ? AppColors.success.withValues(alpha: 0.4)
                : context.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText.body(s.title,
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(priorityLabel,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: priorityColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppText.caption(s.description),
            // The original AI-bundled value (if any)
            if (s.suggestedText != null && s.suggestedText!.isNotEmpty)
              _quoteBlock(s.suggestedText!),
            if (s.suggestedValues != null && s.suggestedValues!.isNotEmpty)
              _chipBlock(s.suggestedValues!, AppColors.primary),
            // The on-demand generated value (if user tapped Generate)
            if (generated != null) _generatedPreview(generated),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: applied
                  ? _appliedChip()
                  : _ctaRow(
                      s: s,
                      hasStructuredValue: hasStructuredValue,
                      supports: supports,
                      generated: generated,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctaRow({
    required ProfileSuggestion s,
    required bool hasStructuredValue,
    required bool supports,
    required AiFieldSuggestion? generated,
  }) {
    // Resume needs a file upload — always show "Upload resume" CTA.
    if (s.field == 'resume') {
      return _filledButton(
        icon: Icons.upload_file_rounded,
        label: 'Upload resume',
        color: AppColors.primary,
        onTap: () => Navigator.pushNamed(context, AppRoutes.resumeProfile),
      );
    }

    // Field type the backend can patch directly.
    if (supports) {
      // 1) AI bundled a concrete value → straight Apply.
      if (hasStructuredValue) {
        return _ApplyButton(onApply: () => _applySuggestion(s));
      }
      // 2) User already generated a value this session → Apply that.
      if (generated != null) {
        return _ApplyButton(onApply: () => _applyGenerated(s, generated));
      }
      // 3) Otherwise → offer Generate (1 quota slot, then becomes Apply).
      return _GenerateButton(onGenerate: () => _generateValue(s));
    }

    // Field that needs human judgement — fall back to manual edit.
    return _outlinedButton(
      icon: Icons.edit_outlined,
      label: 'Open profile',
      onTap: () => Navigator.pushNamed(context, AppRoutes.resumeProfile),
    );
  }

  Widget _quoteBlock(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.surfaceVariant,
            borderRadius: AppRadius.inputRadius,
          ),
          child: Text(text,
              style: AppTextStyles.bodySmall
                  .copyWith(fontStyle: FontStyle.italic)),
        ),
      );

  Widget _chipBlock(List<String> values, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map((v) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: AppRadius.pillRadius,
                      border:
                          Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      v,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );

  /// Renders whatever value the AI just generated so the user sees it
  /// before tapping Apply. Different shape per field type.
  Widget _generatedPreview(AiFieldSuggestion g) {
    if (g.values != null && g.values!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: AppRadius.inputRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('AI suggested',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: g.values!
                    .map((v) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: AppRadius.pillRadius,
                          ),
                          child: Text(
                            v,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }
    final preview = g.value ??
        (g.numericValue != null
            ? (g.field == 'expectedSalary'
                ? '₹${_formatIndianNumber(g.numericValue!.toInt())}'
                : g.numericValue!.toString())
            : '');
    if (preview.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.inputRadius,
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('AI suggested',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Text(preview,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  fontStyle: FontStyle.italic,
                )),
          ],
        ),
      ),
    );
  }

  Widget _appliedChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 16),
            const SizedBox(width: 6),
            Text(
              'Applied',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _filledButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// Thousand-separator using the Indian numbering style (1,23,456) so the
/// suggested salary preview reads naturally to the user. Kept here (not
/// in core/utils) because it's only used by this screen.
String _formatIndianNumber(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final restWithCommas = rest.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
    (m) => '${m[1]},',
  );
  return '$restWithCommas,$last3';
}

class _ApplyButton extends StatefulWidget {
  final Future<void> Function() onApply;
  const _ApplyButton({required this.onApply});

  @override
  State<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends State<_ApplyButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onApply();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.auto_fix_high,
                    color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _busy ? 'Applying…' : 'Apply',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined "Generate with AI" button. Distinct from Apply — uses an
/// outlined treatment + sparkle icon so the user can tell the cards apart
/// at a glance (Apply = filled blue, Generate = outline blue).
class _GenerateButton extends StatefulWidget {
  final Future<void> Function() onGenerate;
  const _GenerateButton({required this.onGenerate});

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onGenerate();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smRadius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                const Icon(Icons.auto_awesome,
                    color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                _busy ? 'Generating…' : 'Generate with AI',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: AppText.body(title,
                fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      );
}

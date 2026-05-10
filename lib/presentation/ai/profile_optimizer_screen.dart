import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/profile_optimizer_model.dart';
import '../../data/services/ai_service.dart';

class ProfileOptimizerScreen extends StatefulWidget {
  const ProfileOptimizerScreen({super.key});

  @override
  State<ProfileOptimizerScreen> createState() => _ProfileOptimizerScreenState();
}

class _ProfileOptimizerScreenState extends State<ProfileOptimizerScreen> {
  Future<ProfileOptimizationResult>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = AiService.instance.profileOptimizer();
    });
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
                Text('Profile Coach',
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-analyse',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<ProfileOptimizationResult>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final r = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
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
                if (r.suggestions.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your profile looks great — no high-impact changes suggested.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scoreCard(ProfileOptimizationResult r) {
    final score = r.completenessScore;
    Color color;
    String label;
    if (score >= 85) {
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
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
                  value: score / 100,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
                Text('$score%',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile completeness',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: context.textSecondary)),
                Text(label,
                    style: AppTextStyles.h4
                        .copyWith(color: context.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ProfileSuggestion s) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(priorityLabel,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: priorityColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.description, style: AppTextStyles.bodySmall),
          if (s.suggestedText != null && s.suggestedText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(s.suggestedText!,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          if (s.suggestedValues != null && s.suggestedValues!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: s.suggestedValues!
                  .map((v) => Chip(
                        label: Text(v),
                        backgroundColor: context.chipBg,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openTargetForField(s.field),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Open profile'),
            ),
          ),
        ],
      ),
    );
  }

  void _openTargetForField(String field) {
    // All fields land on the same Resume Profile screen — that's where
    // skills/headline/experience/etc. all live.
    Navigator.pushNamed(context, AppRoutes.resumeProfile);
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
            child: Text(title,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
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

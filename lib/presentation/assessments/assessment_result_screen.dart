import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../widgets/custom_button.dart';

class AssessmentResultScreen extends StatelessWidget {
  final AssessmentResult result;
  const AssessmentResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isPassed ? AppColors.success : AppColors.urgent;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text('${result.skill} · result'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          _scoreCard(context, color),
          const SizedBox(height: 16),
          if (result.badgeAwarded)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium,
                      color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '"${result.skill}" added to your verified skills.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Review',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.review.asMap().entries.map(
                (e) => _reviewCard(context, e.key + 1, e.value),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(result),
          ),
        ),
      ),
    );
  }

  Widget _scoreCard(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: result.scorePercent / 100,
                  strokeWidth: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
                Text('${result.scorePercent}%',
                    style: AppTextStyles.h3.copyWith(
                        color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isPassed ? 'You passed' : 'Not yet — try again',
                  style: AppTextStyles.h3.copyWith(color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.correctAnswers} of ${result.total} correct',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(BuildContext context, int num, AssessmentReviewItem r) {
    final color = r.isCorrect ? AppColors.success : AppColors.urgent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.isCorrect ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text('Q$num',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.question,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textPrimary)),
          const SizedBox(height: 8),
          ...r.options.asMap().entries.map((e) {
            final i = e.key;
            final isSel = r.selectedIndex == i;
            final isCorrect = r.correctIndex == i;
            Color bg;
            Color fg = context.textPrimary;
            if (isCorrect) {
              bg = AppColors.success.withValues(alpha: 0.12);
              fg = AppColors.success;
            } else if (isSel && !isCorrect) {
              bg = AppColors.urgent.withValues(alpha: 0.10);
              fg = AppColors.urgent;
            } else {
              bg = context.surfaceVariant;
            }
            return Container(
              margin: const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(e.value, style: TextStyle(color: fg))),
                  if (isCorrect)
                    const Icon(Icons.check, size: 16, color: AppColors.success),
                  if (isSel && !isCorrect)
                    const Icon(Icons.close, size: 16, color: AppColors.urgent),
                ],
              ),
            );
          }),
          if (r.explanation != null && r.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('💡 ${r.explanation}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}

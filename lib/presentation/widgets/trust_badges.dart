import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_text.dart';

/// Trust-and-safety pills surfaced across the app. They render compact,
/// consistent badges so a "Verified" pill on a recruiter card looks
/// identical to one on a job detail header.

enum BadgeSize { small, medium }

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = BadgeSize.small});
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final double iconSize = size == BadgeSize.small ? 13 : 16;
    final EdgeInsets padding = size == BadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: iconSize, color: AppColors.primary),
          const SizedBox(width: 4),
          AppText.labelSmall(
            size == BadgeSize.small ? 'Verified' : 'Verified company',
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

class SafeApplyBadge extends StatelessWidget {
  const SafeApplyBadge({super.key});

  /// Returns a SafeApplyBadge when the recruiter clears the safety bar,
  /// otherwise an empty SizedBox so callers can place it inline without
  /// a conditional wrapper.
  static Widget fromFlags({
    Key? key,
    required bool companyVerified,
    required bool recruiterApproved,
    required int trustScore,
  }) {
    final ok = companyVerified && recruiterApproved && trustScore >= 60;
    return ok ? SafeApplyBadge(key: key) : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          AppText.labelSmall(
            'Safe to apply',
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

class TrustScorePill extends StatelessWidget {
  const TrustScorePill({super.key, required this.score});
  final int score;

  Color get _color {
    if (score >= 70) return AppColors.success;
    if (score >= 40) return Colors.orange;
    return AppColors.urgent;
  }

  String get _label {
    if (score >= 70) return 'High trust';
    if (score >= 40) return 'Medium trust';
    return 'Low trust';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AppText.labelSmall(
        '$_label · $score',
        color: _color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class FraudWarningBanner extends StatelessWidget {
  const FraudWarningBanner({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.urgentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.urgent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.urgent),
          const SizedBox(width: 10),
          Expanded(
            child: AppText.caption(
              message ??
                  'Never pay any recruiter to apply. Never share OTPs or bank details. Report jobs that ask for money.',
              color: AppColors.urgent,
            ),
          ),
        ],
      ),
    );
  }
}

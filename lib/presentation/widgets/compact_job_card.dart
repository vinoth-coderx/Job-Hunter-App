import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import 'app_avatar.dart';

/// Compact job card sized for horizontal carousels on the Home screen
/// (Top matches, Recently posted). Width is fixed so multiple cards peek
/// off the trailing edge — same pattern as Naukri / Indeed feeds.
class CompactJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final bool applied;
  final double width;

  const CompactJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.applied = false,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    final hasMatch = job.matchScore != null && job.matchScore! > 60;
    final hasSalary = job.salary.isNotEmpty;

    // Subtle fade+lift on first appearance. Same pattern as JobCard so
    // horizontal rails feel as responsive as the vertical feed.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: SizedBox(
        width: width,
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Logo(url: job.companyLogo),
                    const Spacer(),
                    if (hasMatch) _MatchPill(score: job.matchScore!),
                    if (applied) ...[
                      if (hasMatch) const SizedBox(width: 6),
                      const _AppliedPill(),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  job.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  job.company.isEmpty ? '—' : job.company,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (job.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.location,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                Row(
                  children: [
                    if (hasSalary)
                      Expanded(
                        child: Text(
                          job.salary,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else if (job.postedTime.isNotEmpty)
                      Expanded(
                        child: Text(
                          job.postedTime,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: context.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String url;
  const _Logo({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: context.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        Icons.business_rounded,
        color: context.textTertiary,
        size: 20,
      ),
    );
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: () {
        final resolved = AppAvatar.resolveBackendUrl(url);
        if (resolved == null) return placeholder;
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: BoxFit.cover,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => placeholder,
        );
      }(),
    );
  }
}

class _MatchPill extends StatelessWidget {
  final double score;
  const _MatchPill({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = score.round();
    final Color color;
    if (pct >= 90) {
      color = AppColors.success;
    } else if (pct >= 75) {
      color = AppColors.primary;
    } else {
      color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: color, size: 11),
          const SizedBox(width: 3),
          Text(
            '$pct%',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppliedPill extends StatelessWidget {
  const _AppliedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.successBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'APPLIED',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Section header used above home feed sections (Top matches, Recently
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: AppTextStyles.h4
                            .copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal carousel that lays out a fixed-width card list with
/// consistent edge insets. Use inside a SliverToBoxAdapter.
class HorizontalCardList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const HorizontalCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 208,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Shimmer placeholder shaped like a CompactJobCard. Used while the home
/// feed is loading so users see structure rather than a spinner.
class CompactJobCardSkeleton extends StatelessWidget {
  final double width;
  const CompactJobCardSkeleton({super.key, this.width = 280});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariant,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(context, width: 44, height: 44, radius: 12),
            const SizedBox(height: 14),
            _box(context, width: width * 0.7, height: 14),
            const SizedBox(height: 8),
            _box(context, width: width * 0.45, height: 12),
            const Spacer(),
            _box(context, width: width * 0.5, height: 14),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context,
      {required double width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Vertical job-card-shaped skeleton, for the "More for you" list while
/// it's loading.
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariant,
      highlightColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _box(context, width: 50, height: 50, radius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(context, width: double.infinity, height: 14),
                      const SizedBox(height: 8),
                      _box(context, width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _box(context, width: 180, height: 12),
            const SizedBox(height: 16),
            Row(
              children: [
                _box(context, width: 60, height: 22, radius: 8),
                const SizedBox(width: 6),
                _box(context, width: 80, height: 22, radius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context,
      {required double width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/services/ai_service.dart';
import '../../widgets/app_text.dart';

/// Compact "Was this useful?" thumbs row that any AI result surface
/// can drop in. Wraps `AiService.sendFeedback` with optimistic local
/// state — we don't await the network round-trip before flipping the
/// UI because feedback is best-effort by design.
///
/// Pass a stable `refId` per surface:
///   - ATS:        `'job:<jobId>'` or `'generic'`
///   - Cover letter: `'<jobId>:<tone>'`
///   - Applicant rank: `'<jobId>'`
/// The backend upserts on `(user, feature, refId)` so re-tapping the
/// same thumb clears the rating (rating=0).
class AiFeedbackBar extends StatefulWidget {
  final String feature;
  final String refId;
  final String label;

  const AiFeedbackBar({
    super.key,
    required this.feature,
    required this.refId,
    this.label = 'Was this useful?',
  });

  @override
  State<AiFeedbackBar> createState() => _AiFeedbackBarState();
}

class _AiFeedbackBarState extends State<AiFeedbackBar> {
  int _rating = 0;

  void _setRating(int next) {
    final value = _rating == next ? 0 : next;
    setState(() => _rating = value);
    AiService.instance.sendFeedback(
      feature: widget.feature,
      refId: widget.refId,
      rating: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppText.caption(
              widget.label,
              color: context.textSecondary,
            ),
          ),
          _Thumb(
            icon: Icons.thumb_up_outlined,
            activeIcon: Icons.thumb_up,
            active: _rating == 1,
            onTap: () => _setRating(1),
          ),
          const SizedBox(width: 4),
          _Thumb(
            icon: Icons.thumb_down_outlined,
            activeIcon: Icons.thumb_down,
            active: _rating == -1,
            onTap: () => _setRating(-1),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;
  const _Thumb({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : context.textTertiary;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          active ? activeIcon : icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}

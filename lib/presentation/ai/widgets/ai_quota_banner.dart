import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../providers/ai_quota_provider.dart';
import '../../widgets/app_text.dart';

/// App-wide AI quota banner. Renders nothing when the user has plenty of
/// quota left; switches between two states otherwise:
///   - LOW    → soft warning (amber), shows remaining count
///   - EXHAUST→ blocking notice (red), shows live HH:MM:SS countdown +
///              upgrade CTA
///
/// Mount once near the top of `RoleAwareMainScreen` so it's visible across
/// every tab without duplicating it in each screen.
class AiQuotaBanner extends StatelessWidget {
  final VoidCallback? onUpgradeTap;
  const AiQuotaBanner({super.key, this.onUpgradeTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AiQuotaProvider>(
      builder: (ctx, prov, _) {
        final q = prov.quota;
        if (q == null) return const SizedBox.shrink();
        if (!q.isExhausted && !q.isLow) return const SizedBox.shrink();

        if (q.isExhausted) {
          return _ExhaustedBanner(
            provider: prov,
            onUpgradeTap: onUpgradeTap,
            globalCap: q.globalRemaining <= 0,
          );
        }
        return _LowBanner(remaining: q.userRemaining, total: q.userLimit);
      },
    );
  }
}

class _LowBanner extends StatelessWidget {
  final int remaining;
  final int total;
  const _LowBanner({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border(bottom: BorderSide(color: AppColors.warning, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: AppText.body(
              'AI quota running low — $remaining of $total left for today.',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExhaustedBanner extends StatelessWidget {
  final AiQuotaProvider provider;
  final VoidCallback? onUpgradeTap;
  final bool globalCap;
  const _ExhaustedBanner({
    required this.provider,
    required this.onUpgradeTap,
    required this.globalCap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.urgentBg,
        border: Border(bottom: BorderSide(color: AppColors.urgent, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_clock_outlined,
                  size: 18, color: AppColors.urgent),
              const SizedBox(width: 8),
              Expanded(
                child: AppText.body(
                  globalCap
                      ? 'Free AI is busy across the platform — try again after the reset.'
                      : 'You have used today\'s free AI quota.',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              StreamBuilder<DateTime>(
                stream: provider.countdownStream,
                builder: (_, __) => AppText.caption(
                  'Resets in ${provider.formatTimeUntilReset()}',
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (onUpgradeTap != null)
                InkWell(
                  borderRadius: AppRadius.smRadius,
                  onTap: onUpgradeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.urgent,
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: AppText.button(
                      'Upgrade',
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

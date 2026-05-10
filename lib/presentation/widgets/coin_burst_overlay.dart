import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_text_styles.dart';
import '../../providers/coins_provider.dart';

/// Global overlay that watches [CoinsProvider.lastEarnDelta] and plays
/// a brief "+N 🪙" burst when the seeker earns coins. Mounted once at
/// the root (via [MaterialApp.builder]) so the same animation fires
/// regardless of which screen triggered the earn.
///
/// Animation: a small pill scales up + drifts upward + fades out near
/// the top-right of the screen (where the header pill normally sits).
/// Burst stays compact — the design memo asks for premium, not noisy.
class CoinBurstOverlay extends StatefulWidget {
  final Widget child;
  const CoinBurstOverlay({super.key, required this.child});

  @override
  State<CoinBurstOverlay> createState() => _CoinBurstOverlayState();
}

class _CoinBurstOverlayState extends State<CoinBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int? _displayDelta;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _maybeTrigger() {
    final coins = context.read<CoinsProvider>();
    final delta = coins.lastEarnDelta;
    if (delta == null || delta <= 0) return;
    // Capture-and-consume — the provider state is cleared immediately
    // so a fast back-to-back earn (apply + checkin) re-fires the
    // animation instead of being swallowed by debouncing.
    setState(() => _displayDelta = delta);
    coins.consumeLastEarnDelta();
    _c.forward(from: 0).then((_) {
      if (mounted) setState(() => _displayDelta = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes via Consumer so this rebuild fires
    // even while a navigator transition is in flight.
    return Consumer<CoinsProvider>(
      builder: (ctx, coins, child) {
        // Defer trigger to post-frame so we don't call setState during
        // build of the provider's notifyListeners() pass.
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _maybeTrigger());
        return Stack(
          children: [
            child!,
            if (_displayDelta != null)
              Positioned(
                top: MediaQuery.of(ctx).padding.top + 6,
                right: 16,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) {
                      final t = _c.value;
                      // Three-phase tween: pop-in (0-0.2), hold+drift
                      // (0.2-0.7), fade out (0.7-1.0).
                      final scale = t < 0.2
                          ? Curves.elasticOut.transform(t / 0.2)
                          : 1.0;
                      final drift = -28.0 * Curves.easeOut.transform(t);
                      final opacity = t < 0.7
                          ? 1.0
                          : 1.0 -
                              ((t - 0.7) / 0.3)
                                  .clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, drift),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _BurstPill(delta: _displayDelta!),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _BurstPill extends StatelessWidget {
  final int delta;
  const _BurstPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 5),
          Text(
            '+$delta',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

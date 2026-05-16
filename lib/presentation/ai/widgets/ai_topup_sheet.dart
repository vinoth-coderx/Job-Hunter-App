import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/services/ai_topup_service.dart';
import '../../../data/services/razorpay_checkout_service.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_text.dart';

/// Pay-as-you-go AI credit top-up sheet. Opens automatically when the
/// quota-exhausted 429 banner is shown; can also be opened manually
/// from the AI usage history screen.
///
/// Returns the new pack balance through Navigator.pop so the caller
/// (e.g. quota banner) can refresh its snapshot without round-tripping
/// to /ai/quota.
class AiTopUpSheet extends StatefulWidget {
  const AiTopUpSheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => const AiTopUpSheet(),
    );
  }

  @override
  State<AiTopUpSheet> createState() => _AiTopUpSheetState();
}

class _AiTopUpSheetState extends State<AiTopUpSheet> {
  late Future<List<AiTopUpPack>> _packsFuture;
  bool _processingPackId = false;
  String? _activePackId;

  @override
  void initState() {
    super.initState();
    _packsFuture = AiTopUpService.instance.listPacks();
  }

  Future<void> _buy(AiTopUpPack pack) async {
    if (_processingPackId) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      _toast('Sign in before purchasing credits');
      return;
    }
    setState(() {
      _processingPackId = true;
      _activePackId = pack.id;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = RazorpayCheckoutService();
      final result = await svc.startAiTopUpCheckout(
        pack: pack,
        userEmail: user.email,
        userName: user.name,
      );
      if (!mounted) return;
      if (result.success && result.grant != null) {
        final granted = result.grant!;
        messenger.showSnackBar(SnackBar(
          content: Text(granted.alreadyCredited
              ? 'Already credited — balance ${granted.balance}'
              : '+${granted.creditsGranted} credits added · balance ${granted.balance}'),
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(granted.balance);
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(result.message ?? 'Payment failed'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Could not process payment: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _processingPackId = false;
          _activePackId = null;
        });
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                AppText.h3('Top up AI credits'),
              ],
            ),
            const SizedBox(height: 6),
            AppText.body(
              'Out of today\'s free quota? Buy a pack — credits never expire and roll over until you use them.',
              height: 1.4,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<AiTopUpPack>>(
              future: _packsFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: AppText.body('Couldn\'t load packs: ${snap.error}'),
                  );
                }
                final packs = snap.data ?? const <AiTopUpPack>[];
                if (packs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No top-up packs available right now.'),
                  );
                }
                return Column(
                  children: [
                    for (final p in packs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PackCard(
                          pack: p,
                          processing: _activePackId == p.id,
                          enabled: !_processingPackId,
                          onTap: () => _buy(p),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText.caption(
                    'Secured by Razorpay · UPI, Card, Net Banking, Wallets',
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final AiTopUpPack pack;
  final bool processing;
  final bool enabled;
  final VoidCallback onTap;
  const _PackCard({
    required this.pack,
    required this.processing,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = pack.bestValue;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.lgRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.08)
              : context.surface,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: highlight
                ? AppColors.primary.withValues(alpha: 0.45)
                : context.cardBorder,
            width: highlight ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: AppRadius.mdRadius,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.flash_on_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText.h4(pack.label),
                      if (highlight) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BEST VALUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText.caption(
                    '${pack.credits} credits · ₹${(pack.priceInr / pack.credits).toStringAsFixed(2)}/credit',
                    color: context.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            processing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(
                    '₹${pack.priceInr}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

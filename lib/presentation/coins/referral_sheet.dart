import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/services/referrals_service.dart';
import '../../providers/coins_provider.dart';

/// Bottom-sheet that surfaces the seeker's referral code (with share
/// affordance) and an entry-field for claiming a friend's code. Both
/// directions live in one sheet so the user never has to hunt for the
/// other half of the loop.
class ReferralSheet extends StatefulWidget {
  const ReferralSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReferralSheet(),
    );
  }

  @override
  State<ReferralSheet> createState() => _ReferralSheetState();
}

class _ReferralSheetState extends State<ReferralSheet> {
  final ReferralsService _service = ReferralsService.instance;
  final TextEditingController _redeemCtrl = TextEditingController();

  String? _code;
  bool _loadingCode = true;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _redeemCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    try {
      final code = await _service.myCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _loadingCode = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCode = false);
    }
  }

  void _copyAndShare() {
    final code = _code;
    if (code == null || code.isEmpty) return;
    final msg =
        "I'm using Job Hunter to find jobs. Use my code $code on signup and we both get bonus coins!";
    Clipboard.setData(ClipboardData(text: msg));
    AppSnackbar.success(context, 'Invite copied — paste it anywhere to share');
  }

  Future<void> _redeem() async {
    final code = _redeemCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _redeeming = true);
    try {
      final result = await _service.claim(code);
      if (!mounted) return;
      context.read<CoinsProvider>().setBalance(result.coinsBalance);
      AppSnackbar.success(
        context,
        '+${result.coinsAwarded} coins! Welcome bonus claimed.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // ApiClient surfaces backend message verbatim — pass it through
      // so "already claimed" / "invalid code" reads cleanly.
      AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.cardBorder,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              Text(
                'Invite friends',
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You get +30 coins, your friend gets +20 — every time someone signs up with your code.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _CodeCard(
                code: _code,
                loading: _loadingCode,
                onShare: _copyAndShare,
              ),
              const SizedBox(height: 22),
              Text(
                'Have a code from a friend?',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _redeemCtrl,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 12,
                      decoration: InputDecoration(
                        hintText: 'Enter code',
                        counterText: '',
                        filled: true,
                        fillColor: context.scaffoldBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(color: context.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          borderSide: BorderSide(color: context.cardBorder),
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _redeeming ? null : _redeem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.input),
                        ),
                      ),
                      child: _redeeming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Redeem',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String? code;
  final bool loading;
  final VoidCallback onShare;
  const _CodeCard({
    required this.code,
    required this.loading,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR CODE',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        code ?? '—',
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontSize: 26,
                        ),
                      ),
              ],
            ),
          ),
          IconButton(
            onPressed: code == null || code!.isEmpty ? null : onShare,
            tooltip: 'Copy invite message',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

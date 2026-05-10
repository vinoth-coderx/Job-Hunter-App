import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/user_model.dart';

Future<void> showShareProfileSheet(BuildContext context, UserModel user) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareProfileSheet(user: user),
  );
}

class _ShareProfileSheet extends StatefulWidget {
  final UserModel user;
  const _ShareProfileSheet({required this.user});

  @override
  State<_ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<_ShareProfileSheet>
    with TapGuardMixin<_ShareProfileSheet> {
  UserModel get user => widget.user;

  String get _profileLink =>
      'https://jobhunder.app/u/${user.id.substring(0, user.id.length.clamp(0, 8))}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.profession,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Share your profile',
              style: AppTextStyles.h4, textAlign: TextAlign.left),
          const SizedBox(height: 4),
          Text(
            'Send your profile link to recruiters and friends.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded,
                    color: context.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _profileLink,
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => debounceTap(
                    () async {
                      await Clipboard.setData(
                          ClipboardData(text: _profileLink));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile link copied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    key: 'copy',
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ShareTarget(
                icon: Icons.message_rounded,
                label: 'Message',
                color: const Color(0xFF22C55E),
                onTap: () =>
                    debounceTap(() => _stub(context, 'Messages'), key: 'share'),
              ),
              _ShareTarget(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                color: const Color(0xFFEF4444),
                onTap: () =>
                    debounceTap(() => _stub(context, 'Email'), key: 'share'),
              ),
              _ShareTarget(
                icon: Icons.send_rounded,
                label: 'Telegram',
                color: const Color(0xFF0088CC),
                onTap: () =>
                    debounceTap(() => _stub(context, 'Telegram'), key: 'share'),
              ),
              _ShareTarget(
                icon: Icons.alternate_email_rounded,
                label: 'Twitter',
                color: const Color(0xFF1DA1F2),
                onTap: () =>
                    debounceTap(() => _stub(context, 'Twitter'), key: 'share'),
              ),
              _ShareTarget(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                color: context.textSecondary,
                onTap: () => debounceTap(
                    () => _stub(context, 'System share'),
                    key: 'share'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () =>
                  debounceTap(() => Navigator.pop(context), key: 'close'),
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: const Text('Show QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.textPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stub(BuildContext context, String target) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shared via $target'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareTarget({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

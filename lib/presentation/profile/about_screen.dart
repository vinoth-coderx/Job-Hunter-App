import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(title: 'About'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.12),
                              AppColors.primary.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        child: const AppLogo(size: 96),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('Job Hunter',
                          style: AppTextStyles.h2.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'v1.0.0 · Build 100',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: Text(
                        'Job Hunter helps you discover roles that match your skills, '
                        'track applications end-to-end, and stay in touch with recruiters — '
                        'all in one beautifully simple app.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Highlights', style: AppTextStyles.h4),
                    const SizedBox(height: 12),
                    _Highlight(
                      icon: Icons.flash_on_rounded,
                      title: 'Smart Search',
                      subtitle:
                          'Voice + filters powered by intent matching.',
                      color: AppColors.warning,
                    ),
                    _Highlight(
                      icon: Icons.shield_outlined,
                      title: 'Privacy First',
                      subtitle:
                          'Your data is shared only when you actively apply.',
                      color: AppColors.success,
                    ),
                    _Highlight(
                      icon: Icons.bolt_rounded,
                      title: 'Real-time Updates',
                      subtitle:
                          'Track shortlists and interview invites instantly.',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _LinkTile(
                            icon: Icons.policy_outlined,
                            title: 'Privacy Policy',
                            onTap: () => _toast(context),
                          ),
                          const _Divider(),
                          _LinkTile(
                            icon: Icons.description_outlined,
                            title: 'Terms of Service',
                            onTap: () => _toast(context),
                          ),
                          const _Divider(),
                          _LinkTile(
                            icon: Icons.star_border_rounded,
                            title: 'Rate the App',
                            onTap: () => _toast(context),
                          ),
                          const _Divider(),
                          _LinkTile(
                            icon: Icons.public_rounded,
                            title: 'Visit Website',
                            trailingText: 'jobhunter.app',
                            onTap: () => _toast(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '© 2026 Job Hunter. Made with Flutter.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: context.textPrimary),
            ),
          ),
          Expanded(
            child: Center(child: Text(title, style: AppTextStyles.h4)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Highlight({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.textPrimary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: context.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
            if (trailingText != null) ...[
              Text(trailingText!,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.open_in_new_rounded,
                size: 18, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66),
      child: Container(
        height: 1,
        color: context.divider.withValues(alpha: 0.6),
      ),
    );
  }
}

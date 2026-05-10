import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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
              _Header(title: 'Help & Support'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _Hero(),
                    const SizedBox(height: 24),
                    Text('Get in touch', style: AppTextStyles.h4),
                    const SizedBox(height: 12),
                    _ContactCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Live Chat',
                      subtitle: 'Avg. response 2 min',
                      color: AppColors.primary,
                      onTap: () => _toast(context, 'Opening chat...'),
                    ),
                    const SizedBox(height: 10),
                    _ContactCard(
                      icon: Icons.mail_outline_rounded,
                      title: 'Email Us',
                      subtitle: 'support@jobhunder.app',
                      color: AppColors.warning,
                      onTap: () => _toast(context, 'Opening email...'),
                    ),
                    const SizedBox(height: 10),
                    _ContactCard(
                      icon: Icons.call_outlined,
                      title: 'Call Us',
                      subtitle: '+91 80000 12345 · Mon–Sat',
                      color: AppColors.success,
                      onTap: () => _toast(context, 'Calling support...'),
                    ),
                    const SizedBox(height: 24),
                    Text('Frequently asked', style: AppTextStyles.h4),
                    const SizedBox(height: 12),
                    const _FaqCard(items: [
                      _FaqItem(
                        question: 'How do I apply for a job?',
                        answer:
                            'Open any job from Home or Search, review the role, and tap the "Apply Now" button at the bottom.',
                      ),
                      _FaqItem(
                        question: 'Can I cancel my Pro subscription?',
                        answer:
                            'Yes. Visit Profile → Subscription and tap "Manage". You can cancel anytime; access stays until the period ends.',
                      ),
                      _FaqItem(
                        question: 'How is my profile shared with employers?',
                        answer:
                            'Only when you actively apply or tap "Share Profile". We never share your data without consent.',
                      ),
                      _FaqItem(
                        question: 'I forgot my password — what now?',
                        answer:
                            'On the login screen, tap "Forgot password?" and follow the email link to reset it.',
                      ),
                    ]),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Job Hunter · v1.0.0',
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

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
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

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -20,
            child: Icon(
              Icons.support_agent_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help?',
                      style: AppTextStyles.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "We're here 24×7. Pick a channel that works for you.",
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqCard extends StatelessWidget {
  final List<_FaqItem> items;
  const _FaqCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionPanelList.radio(
            elevation: 0,
            expandedHeaderPadding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < items.length; i++)
                ExpansionPanelRadio(
                  value: i,
                  canTapOnHeader: true,
                  backgroundColor: context.surface,
                  headerBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Text(items[i].question,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  body: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        items[i].answer,
                        style: AppTextStyles.bodySmall
                            .copyWith(height: 1.6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

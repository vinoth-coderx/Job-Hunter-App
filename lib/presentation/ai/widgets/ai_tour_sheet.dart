import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/app_text.dart';

/// One-time AI features tour. Auto-shown on the first home-screen
/// visit after sign-in (gated by [StorageService.hasAiTourSeen]).
/// 4 cards swiped through with a "Got it" finish, persists the seen
/// flag so we never nag the user again.
///
/// Each card maps to a real route the user can deep-link into so the
/// tour doubles as a discoverability surface — tap any card and you
/// land on that feature.
class AiTourSheet extends StatefulWidget {
  const AiTourSheet({super.key});

  /// Show iff the tour hasn't been seen yet. Returns the future the
  /// caller can `await` if they want the gate logic; otherwise it's
  /// fire-and-forget.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (StorageService.hasAiTourSeen()) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => const AiTourSheet(),
    );
    await StorageService.setAiTourSeen();
  }

  @override
  State<AiTourSheet> createState() => _AiTourSheetState();
}

class _AiTourSheetState extends State<AiTourSheet> {
  final _ctrl = PageController();
  int _index = 0;

  static const _cards = <_TourCard>[
    _TourCard(
      icon: Icons.fact_check_outlined,
      title: 'ATS resume score',
      body:
          'Get a 0–100 ATS score for your resume against any job. See exactly which keywords are missing.',
      route: AppRoutes.atsScore,
    ),
    _TourCard(
      icon: Icons.support_agent_rounded,
      title: 'Career assistant chat',
      body:
          'Ask about resumes, interviews, salary, or job search. Replies stream in real time and stay in your conversation.',
      route: AppRoutes.aiAssistant,
    ),
    _TourCard(
      icon: Icons.psychology_alt_outlined,
      title: 'Skill gap analysis',
      body:
          'Pick a target role — see which skills you have, which you\'re missing, and what to learn next.',
      route: AppRoutes.skillGap,
    ),
    _TourCard(
      icon: Icons.auto_fix_high_rounded,
      title: 'Profile coach',
      body:
          'AI suggestions to improve your profile. Tap any field to get an instant rewrite that\'s ATS-friendly.',
      route: AppRoutes.profileOptimizer,
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish({String? deepLink}) async {
    Navigator.of(context).pop();
    if (deepLink != null) {
      // Defer the navigation by a microtask so the modal close finishes
      // before the new route push, avoiding a Material transition glitch.
      await Future<void>.microtask(() {});
      if (!mounted) return;
      Navigator.of(context).pushNamed(deepLink);
    }
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
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                AppText.h4('AI inside Job Hunter'),
                const Spacer(),
                TextButton(
                  onPressed: () => _finish(),
                  child: const Text('Skip'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final c = _cards[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: AppRadius.lgRadius,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              borderRadius: AppRadius.mdRadius,
                            ),
                            child: Icon(c.icon,
                                size: 22, color: AppColors.primary),
                          ),
                          const SizedBox(height: 12),
                          AppText.h3(c.title),
                          const SizedBox(height: 6),
                          AppText.body(c.body, height: 1.4),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _finish(deepLink: c.route),
                            icon: const Icon(Icons.arrow_outward_rounded,
                                size: 16),
                            label: const Text('Try it'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _cards.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _index == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _index == i
                          ? AppColors.primary
                          : context.cardBorder,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_index < _cards.length - 1) {
                  _ctrl.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                } else {
                  _finish();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                _index < _cards.length - 1 ? 'Next' : 'Got it',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourCard {
  final IconData icon;
  final String title;
  final String body;
  final String route;
  const _TourCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.route,
  });
}

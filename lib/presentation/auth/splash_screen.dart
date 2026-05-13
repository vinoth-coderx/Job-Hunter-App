import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _breathController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Future<void> _authFuture;

  // Becomes true once the intro slide-ins finish — gates the feature
  // rotator + pulsing dots so they don't fight the entrance animation.
  bool _showRotator = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Slow continuous breath cycle on the logo — runs forever once the
    // intro completes so the screen never reads as frozen even when a
    // cold-start auth check takes a few seconds.
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Kick off the auth check in parallel with the intro animations so the
    // splash doesn't serially wait on storage/network after the animation ends.
    // 10s timeout is a safety net: if the backend never responds we bounce
    // to login rather than leaving the user staring at the rotator forever.
    _authFuture = context
        .read<AuthProvider>()
        .checkAuthStatus()
        .timeout(const Duration(seconds: 10), onTimeout: () {});
    _runIntro();
  }

  Future<void> _runIntro() async {
    await _logoController.forward();
    await _textController.forward();
    if (!mounted) return;
    // Start the breath + rotator the moment the title settles so the
    // screen has continuous motion through the rest of the wait.
    _breathController.repeat(reverse: true);
    setState(() => _showRotator = true);
    // Small breath at the end so the finished frame is visible.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _navigate();
  }

  Future<void> _navigate() async {
    await _authFuture;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    // Returning users (already signed in on a previous session) go
    // straight to /main. Onboarding is only triggered from the fresh
    // signup paths in login_screen / email_auth_screen — never from
    // the resume-existing-session splash flow.
    if (auth.isAuthenticated || auth.isGuest) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
      return;
    }
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  // Colors sampled from the app logo (deep navy → vibrant blue accents).
  static const Color _logoNavy = Color(0xFF0A1B3D);
  static const Color _logoNavyDeep = Color(0xFF050E22);
  static const Color _logoBlue = Color(0xFF1E88FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_logoBlue, _logoNavy, _logoNavyDeep],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: AnimatedBuilder(
                      animation: _breathController,
                      builder: (_, child) {
                        // Subtle 1.0 → 1.04 breath after intro — easy
                        // way to keep the hero alive without screaming.
                        final t = _breathController.value;
                        final breathScale = 1.0 + 0.04 * t;
                        return Transform.scale(scale: breathScale, child: child);
                      },
                      child: const AppLogo(size: 120),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        Text(
                          'Job Hunter',
                          style:
                              AppTextStyles.h1.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find your dream job',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 44),
                // Feature rotator + pulsing dots — fade in after the
                // intro completes so the entry animations stay clean.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _showRotator ? 1.0 : 0.0,
                  child: const Column(
                    children: [
                      _FeatureRotator(),
                      SizedBox(height: 18),
                      _PulseDots(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  const _FeatureItem(this.icon, this.label);
}

class _FeatureRotator extends StatefulWidget {
  const _FeatureRotator();

  @override
  State<_FeatureRotator> createState() => _FeatureRotatorState();
}

class _FeatureRotatorState extends State<_FeatureRotator> {
  // Order is deliberately mixed across seeker + hirer-facing capabilities
  // so any returning user sees something they recognise within 2–3 ticks.
  static const List<_FeatureItem> _items = [
    _FeatureItem(Icons.auto_awesome_rounded, 'Analyzing AI matches'),
    _FeatureItem(Icons.bolt_rounded, 'Loading One-Tap apply'),
    _FeatureItem(Icons.psychology_alt_rounded, 'Tuning recommendations'),
    _FeatureItem(Icons.chat_bubble_rounded, 'Connecting to recruiters'),
    _FeatureItem(Icons.monetization_on_rounded, 'Syncing coins & streak'),
    _FeatureItem(Icons.notifications_active_rounded, 'Refreshing alerts'),
    _FeatureItem(Icons.search_rounded, "Curating today's picks"),
  ];

  Timer? _timer;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: Row(
          key: ValueKey(item.label),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDots extends StatefulWidget {
  const _PulseDots();

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot's wave is phase-shifted so the trio reads as a
            // single travelling pulse rather than three blinks.
            final phase = (_c.value - i * 0.18) % 1.0;
            final pulse = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            final scale = 0.7 + 0.5 * pulse;
            final opacity = 0.35 + 0.55 * pulse;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8 * scale,
              height: 8 * scale,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

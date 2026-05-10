import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

/// Branded transition shown while the user toggles between seeker and
/// hirer mode. Owns the entire role-swap: kicks off `switchRole` on the
/// auth provider, decides where to land based on what setup is missing
/// (seeker onboarding wizard, hirer company-profile setup), then hands
/// the navigator off to that destination — all without ever exposing
/// the in-flight state to the user.
///
/// The seeker variant keeps the original lightweight intro (orbiting
/// rings + pulsing dots). The hirer variant is dressed up to read as
/// an "executive console" — deep navy + gold palette, animated grid
/// backdrop, gold-embossed logo plate, and a progress bar timed to
/// the hold duration. Same hold time and skip affordance.
class RoleSwitchSplash extends StatefulWidget {
  final String targetRole; // 'seeker' or 'hirer'
  final Duration holdDuration;

  const RoleSwitchSplash({
    super.key,
    required this.targetRole,
    this.holdDuration = const Duration(milliseconds: 1400),
  });

  /// Mounts the splash and runs the role transition end-to-end. The
  /// splash itself will:
  ///   1. Kick off `auth.switchRole(targetRole)` while its entrance
  ///      animation plays.
  ///   2. Wait for *both* the visual hold and the network call to
  ///      complete so the transition feels consistent regardless of
  ///      backend latency.
  ///   3. Decide the destination based on what setup is still missing,
  ///      then either pop (back to /main, which re-renders under the
  ///      new active role) or push the appropriate setup screen.
  ///
  /// Callers can `await` this to know when the transition is fully
  /// settled — they don't need to call `switchRole` themselves.
  static Future<void> show(
    BuildContext context, {
    required String targetRole,
    Duration holdDuration = const Duration(milliseconds: 1400),
  }) async {
    // Hirer transition gets a longer hold so the dressed-up entrance
    // animations have room to land — 1.4s reads as a flicker once the
    // gold sheen + grid drift come in.
    final effectiveHold = targetRole == 'hirer'
        ? const Duration(milliseconds: 2000)
        : holdDuration;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => RoleSwitchSplash(
          targetRole: targetRole,
          holdDuration: effectiveHold,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<RoleSwitchSplash> createState() => _RoleSwitchSplashState();
}

class _RoleSwitchSplashState extends State<RoleSwitchSplash>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _entry;
  late final AnimationController _dots;
  late final AnimationController _hold;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _hold = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    )..forward();
    _orchestrate();
  }

  /// Runs the role-swap network call + onboarding gate while the
  /// splash plays. The visual hold and the network call run in
  /// parallel, but routing waits for both — so a slow API doesn't
  /// dump the user onto the destination before the splash is finished
  /// and a fast API doesn't make the splash feel meaninglessly long.
  Future<void> _orchestrate() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    final holdComplete = Future<void>.delayed(widget.holdDuration);
    // Cap the role-switch network call so a stalled backend (Render free
    // tier cold-start, dropped connection, etc.) can't trap the user on
    // the splash forever — surface a friendly error and back out instead.
    final result = await auth
        .switchRole(widget.targetRole)
        .timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('[RoleSwitchSplash] switchRole timed out after 20s');
        return (
          ok: false,
          needsHirerProfile: false,
          error: 'Server is taking too long to respond. Please try again.',
        );
      },
    );
    await holdComplete;
    if (!mounted) return;

    if (!result.ok) {
      // Backend rejected the switch. Surface the cause and back out
      // to wherever the caller pushed us from.
      await _entry.reverse();
      if (!mounted) return;
      navigator.pop();
      if (result.needsHirerProfile && widget.targetRole == 'hirer') {
        // First-time hirer — bounce through company setup. The setup
        // screen pops `true` on success; the toggle handler in
        // profile_screen retries the transition so the user lands in
        // hirer mode without seeing this splash twice.
        navigator.pushNamed(AppRoutes.hirerProfileSetup);
        return;
      }
      messenger.showSnackBar(SnackBar(
        content: Text(result.error ?? 'Could not switch role'),
      ));
      return;
    }

    // Switch landed. For seeker we additionally gate on whether the
    // onboarding wizard has ever been seen — fields-empty alone isn't
    // enough, since users who skipped past the wizard once shouldn't
    // be re-prompted on every future toggle back to seeker.
    final needsOnboarding = widget.targetRole == 'seeker' &&
        auth.needsOnboarding &&
        !StorageService.hasSeekerOnboardingSeen();

    await _entry.reverse();
    if (!mounted) return;
    if (needsOnboarding) {
      navigator.pushReplacementNamed(AppRoutes.onboarding);
    } else {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    _entry.dispose();
    _dots.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHirer = widget.targetRole == 'hirer';
    return isHirer ? _buildHirerBody() : _buildSeekerBody();
  }

  // ────────────────────────── Hirer ──────────────────────────

  Widget _buildHirerBody() {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1F),
      body: Stack(
        children: [
          // Animated grid + glow backdrop. Reads as an executive
          // dashboard powering on rather than a flat colour wash.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbit,
              builder: (_, __) => CustomPaint(
                painter: _HirerBackdropPainter(t: _orbit.value),
              ),
            ),
          ),
          // Soft vignette so the centre composition draws focus.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (_, child) {
                final t = Curves.easeOutCubic.transform(_entry.value);
                return Opacity(
                  opacity: _entry.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: child,
                  ),
                );
              },
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _HirerLogoPlate(orbit: _orbit),
                        const SizedBox(height: 36),
                        const _GoldBadge(label: 'HIRER CONSOLE'),
                        const SizedBox(height: 22),
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [
                              Color(0xFFFFE7A8),
                              Color(0xFFFFC857),
                              Color(0xFFB88B2E),
                            ],
                          ).createShader(rect),
                          child: Text(
                            'Welcome, Hirer',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              fontSize: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Recruit · Review · Hire',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              height: 1.5,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          width: 220,
                          child: _GoldProgressBar(controller: _hold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Seeker ──────────────────────────

  Widget _buildSeekerBody() {
    const headline = 'Back to Seeker';
    const subtitle = 'Find roles tailored to your profile';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.95),
              const Color(0xFF1F4FE0),
              const Color(0xFF06224A),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _entry,
            builder: (context, child) {
              final t = Curves.easeOutBack.transform(_entry.value);
              return Opacity(
                opacity: _entry.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  child: child,
                ),
              );
            },
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _OrbitingLogo(orbit: _orbit),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SEEKER MODE',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _PulsingDots(controller: _dots),
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

// ───────────────────────── Hirer pieces ─────────────────────────

const _hirerGold = Color(0xFFFFC857);
const _hirerGoldDeep = Color(0xFFB88B2E);
const _hirerInk = Color(0xFF050B1F);
const _hirerInkMid = Color(0xFF0E1A38);

/// Layered grid + radial glow drawn behind the hirer hero. Slow
/// horizontal drift on the grid sells the "console powering up"
/// idea without competing with the centred composition.
class _HirerBackdropPainter extends CustomPainter {
  final double t;
  const _HirerBackdropPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // Base navy gradient.
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_hirerInk, _hirerInkMid, _hirerInk],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // Soft gold halo upper-right.
    final halo = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.6),
        radius: 0.9,
        colors: [
          _hirerGold.withValues(alpha: 0.22),
          _hirerGold.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, halo);

    // Indigo halo lower-left for asymmetry.
    final indigo = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, 0.7),
        radius: 0.9,
        colors: [
          const Color(0xFF5B5BFF).withValues(alpha: 0.18),
          const Color(0xFF5B5BFF).withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, indigo);

    // Drifting grid. Two passes (vertical + horizontal) for an
    // architectural feel. Phase animates with `t`.
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const spacing = 40.0;
    final phase = (t * spacing) % spacing;
    for (double x = -spacing + phase; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -spacing + phase; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // A few brighter gold grid intersections that fade in/out — gives
    // the grid the impression of activity without animating every node.
    final dotPaint = Paint()..color = _hirerGold;
    final rng = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final phaseI = (t + i / 14) % 1.0;
      final pulse = (math.sin(phaseI * math.pi * 2) + 1) / 2;
      dotPaint.color = _hirerGold.withValues(alpha: 0.05 + 0.25 * pulse);
      canvas.drawCircle(Offset(dx, dy), 1.6 + pulse * 0.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HirerBackdropPainter old) => old.t != t;
}

/// Logo on a gold-bordered plate with a slow-rotating sheen.
class _HirerLogoPlate extends StatelessWidget {
  final AnimationController orbit;
  const _HirerLogoPlate({required this.orbit});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbit,
      builder: (_, __) {
        final t = orbit.value;
        return SizedBox(
          width: 152,
          height: 152,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating sheen ring.
              Transform.rotate(
                angle: t * 6.2832,
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _hirerGold.withValues(alpha: 0.0),
                        _hirerGold.withValues(alpha: 0.6),
                        _hirerGold.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Inner gold border.
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hirerGold.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
              ),
              // Plate behind logo. Subtle gradient + glow gives the
              // logo a "presented on a card" feel rather than floating.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFCF2), Color(0xFFFFE7A8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hirerGold.withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: AppLogo(size: 68, elevated: false),
                ),
              ),
              // Briefcase corner badge — anchors the role identity.
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_hirerGold, _hirerGoldDeep],
                    ),
                    border: Border.all(color: _hirerInk, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _hirerGold.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    size: 16,
                    color: _hirerInk,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GoldBadge extends StatelessWidget {
  final String label;
  const _GoldBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(
          colors: [
            _hirerGold.withValues(alpha: 0.18),
            _hirerGold.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: _hirerGold.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 14, color: _hirerGold),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: _hirerGold,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin gold progress bar that fills over the hold duration. Reads as
/// "your console is preparing" without the noise of a spinner.
class _GoldProgressBar extends StatelessWidget {
  final AnimationController controller;
  const _GoldProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value.clamp(0.0, 1.0);
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: t,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [_hirerGoldDeep, _hirerGold, Color(0xFFFFE7A8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hirerGold.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Seeker pieces ─────────────────────────

/// Logo with a thin counter-rotating ring + soft glow ring. The two
/// orbits move at different rates so the composition reads as
/// "transitioning" rather than a static loading spinner.
class _OrbitingLogo extends StatelessWidget {
  final AnimationController orbit;
  const _OrbitingLogo({required this.orbit});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orbit,
      builder: (context, _) {
        final t = orbit.value;
        return SizedBox(
          width: 152,
          height: 152,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: t * 6.2832,
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -t * 6.2832 * 1.4,
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                ),
              ),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: AppLogo(size: 58, elevated: false),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingDots extends StatelessWidget {
  final AnimationController controller;
  const _PulsingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (t + i * 0.18) % 1.0;
            final scale = 0.65 +
                0.45 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

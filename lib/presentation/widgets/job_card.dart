import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';

/// Job-card design follows Indeed's seeker-feed pattern adapted to our
/// theme:
///   1. Top row — "One Tap" pill (native jobs only) + bookmark/dismiss
///      action icons aligned right.
///   2. Title (bold, two-line clamp).
///   3. Company • Location single line.
///   4. Highlight pills — salary + employment type as green check chips,
///      remaining perks/benefits as quiet gray chips.
///   5. Corner ribbons — application status (top-right) and AI auto-apply
///      (top-left) layered over the card with the same gift-ribbon
///      treatment we had before; they're a brand differentiator and
///      coexist with the new top action row.
///
/// Callers pass `onSave` / `isSaved` to wire bookmark behaviour, and
/// `onDismiss` to surface the thumbs-down (skipped if null so non-feed
/// surfaces like the application list don't grow a spurious action).
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final String? statusBadge;
  final Color? statusColor;
  final Color? statusBgColor;

  /// True → AI auto-apply ribbon on the top-left corner.
  final bool aiApplied;

  /// Bookmark wiring. When [onSave] is null the icon is hidden — keeps
  /// the application/applied screens visually clean (saving an already-
  /// applied job is a confusing affordance).
  final bool isSaved;
  final VoidCallback? onSave;

  /// Optional dismiss/"not interested" affordance (thumbs-down). Hidden
  /// when null because the backend doesn't have a hide-job endpoint
  /// for every surface yet — feed-style screens can opt in.
  final VoidCallback? onDismiss;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.statusBadge,
    this.statusColor,
    this.statusBgColor,
    this.aiApplied = false,
    this.isSaved = false,
    this.onSave,
    this.onDismiss,
  });

  static const _ribbonStatuses = {
    'applied',
    'shortlisted',
    'interview',
    'offered',
    'offer',
    'hired',
  };

  String? get _normalizedRibbonStatus {
    final s = (statusBadge ?? '').trim().toLowerCase();
    if (!_ribbonStatuses.contains(s)) return null;
    return s == 'offer' ? 'offered' : s;
  }

  bool get _hasRibbonStatus => _normalizedRibbonStatus != null;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final ribbonKey = _normalizedRibbonStatus;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        _cardBody(context),
        if (ribbonKey != null)
          Positioned(
            top: 0,
            right: 0,
            child: _StatusRibbon(statusKey: ribbonKey),
          )
        else if (onSave != null)
          Positioned(
            top: 8,
            right: 8,
            child: _ActionIconButton(
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.primary : context.textSecondary,
              onTap: onSave,
            ),
          ),
        if (aiApplied)
          const Positioned(
            top: 0,
            left: 0,
            child: _AiRibbon(),
          ),
      ],
    );
  }

  Widget _cardBody(BuildContext context) {
    final hasMatch = job.matchScore != null && job.matchScore! > 60;
    final hasSalary = job.salary.isNotEmpty;
    final typeChips = _buildTypeChips();
    final perks = job.perks
        .where((p) => p.trim().isNotEmpty)
        .take(4)
        .toList();
    final hasActions = onDismiss != null;
    final hasOneTap = job.isNative;
    // Corner ribbons cover ~90px in the top-left and top-right; the
    // floating save icon takes ~36px on the top-right when no ribbon
    // is present. Inset the title/meta so they don't slide under either.
    final rightRibbonInset = _hasRibbonStatus
        ? 78.0
        : (onSave != null ? 40.0 : 0.0);
    final leftRibbonInset = aiApplied ? 78.0 : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xlRadius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.xlRadius,
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasOneTap || hasMatch || hasActions) ...[
                Padding(
                  padding: EdgeInsets.only(
                    left: leftRibbonInset,
                    right: rightRibbonInset,
                  ),
                  child: Row(
                    children: [
                      if (hasOneTap) const _OneTapBadge(),
                      if (hasOneTap && hasMatch) const SizedBox(width: 6),
                      if (hasMatch)
                        _MatchPill(score: job.matchScore!),
                      const Spacer(),
                      if (onDismiss != null)
                        _ActionIconButton(
                          icon: Icons.thumb_down_off_alt_rounded,
                          color: context.textSecondary,
                          onTap: onDismiss,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Padding(
                padding: EdgeInsets.only(right: rightRibbonInset),
                child: Text(
                  job.title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (job.company.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.only(right: rightRibbonInset),
                  child: Text(
                    job.company,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (job.location.isNotEmpty) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: EdgeInsets.only(right: rightRibbonInset),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: context.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.location,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12.5,
                            color: context.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasSalary || typeChips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasSalary) _GreenCheckPill(label: job.salary),
                    ...typeChips,
                  ],
                ),
              ],
              if (perks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in perks) _NeutralChip(label: p),
                  ],
                ),
              ],
              if (job.postedTime.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: context.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      job.postedTime,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        color: context.textTertiary,
                      ),
                    ),
                    if (statusBadge != null && !_hasRibbonStatus) ...[
                      const Spacer(),
                      _StatusBadge(
                        label: statusBadge!,
                        color: statusColor ?? AppColors.urgent,
                        bgColor: statusBgColor ?? context.urgentBg,
                      ),
                    ],
                  ],
                ),
              ] else if (statusBadge != null && !_hasRibbonStatus) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _StatusBadge(
                    label: statusBadge!,
                    color: statusColor ?? AppColors.urgent,
                    bgColor: statusBgColor ?? context.urgentBg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the green check pills for employment type. When the job
  /// has both a primary type and a remote-work flag (e.g. "Full-time"
  /// + "Remote") we render a single pill with a "+1" suffix to mirror
  /// Indeed's compact two-tags-as-one treatment.
  List<Widget> _buildTypeChips() {
    final type = _capitalize(job.employmentType);
    final remote = job.isRemote ? 'Remote' : '';
    if (type.isEmpty && remote.isEmpty) return const [];
    if (type.isNotEmpty && remote.isNotEmpty) {
      return [_GreenCheckPill(label: type, suffix: '+1')];
    }
    final label = type.isNotEmpty ? type : remote;
    return [_GreenCheckPill(label: label)];
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    final parts = s.split(RegExp(r'[\s-]+'));
    return parts
        .map((p) =>
            p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// Lightning-pill that marks jobs posted through our own hirer flow.
/// Reused inside the apply modal hero so the brand cue is consistent
/// from feed → detail → apply.
class _OneTapBadge extends StatelessWidget {
  const _OneTapBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            'One Tap',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green check pill — used for the highlight properties (salary,
/// employment type) the seeker is most likely scanning for. Subtle
/// success-tinted background, dark green text, leading check icon.
class _GreenCheckPill extends StatelessWidget {
  final String label;
  final String? suffix;
  const _GreenCheckPill({required this.label, this.suffix});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.success.withValues(alpha: 0.16)
        : AppColors.success.withValues(alpha: 0.10);
    final fg = isDark ? const Color(0xFF7BD89A) : const Color(0xFF1B7F3C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.1,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 6),
            Text(
              suffix!,
              style: AppTextStyles.labelSmall.copyWith(
                color: fg.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quiet neutral chip used for non-promoted properties — perks, benefits
/// (paid time off, provident fund, etc.). Reads as supporting info next
/// to the green highlight pills.
class _NeutralChip extends StatelessWidget {
  final String label;
  const _NeutralChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: AppRadius.smRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: context.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Compact match-score pill — replaces the gradient hero card the old
/// JobCard used. Sits next to the One Tap pill so the seeker reads
/// "fits you" right after "easy to apply".
class _MatchPill extends StatelessWidget {
  final double score;
  const _MatchPill({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = score.round();
    final Color color;
    if (pct >= 90) {
      color = AppColors.success;
    } else if (pct >= 75) {
      color = AppColors.primary;
    } else {
      color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '$pct% match',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.smRadius,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// ───────────────────────── Ribbons ─────────────────────────

/// Visual spec for a single ribbon variant — label + 3-stop gradient
/// (left/middle/right) + glow color.
class _RibbonStyle {
  final String label;
  final Color glow;
  final List<Color> gradient;
  const _RibbonStyle({
    required this.label,
    required this.glow,
    required this.gradient,
  });
}

const Map<String, _RibbonStyle> _ribbonStyles = {
  'applied': _RibbonStyle(
    label: 'APPLIED',
    glow: AppColors.success,
    gradient: [Color(0xFF16A34A), Color(0xFF22C55E), Color(0xFF15803D)],
  ),
  'shortlisted': _RibbonStyle(
    label: 'SHORTLISTED',
    glow: Color(0xFF2563EB),
    gradient: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF1E40AF)],
  ),
  'interview': _RibbonStyle(
    label: 'INTERVIEW',
    glow: Color(0xFF7C3AED),
    gradient: [Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFF5B21B6)],
  ),
  'offered': _RibbonStyle(
    label: 'OFFERED',
    glow: Color(0xFFF59E0B),
    gradient: [Color(0xFFD97706), Color(0xFFFBBF24), Color(0xFFB45309)],
  ),
  'hired': _RibbonStyle(
    label: 'HIRED',
    glow: Color(0xFF059669),
    gradient: [Color(0xFF065F46), Color(0xFF10B981), Color(0xFF047857)],
  ),
};

/// Diagonal status banner anchored at the top-right corner.
class _StatusRibbon extends StatefulWidget {
  final String statusKey;
  const _StatusRibbon({required this.statusKey});

  @override
  State<_StatusRibbon> createState() => _StatusRibbonState();
}

class _StatusRibbonState extends State<_StatusRibbon>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _StatusRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusKey != widget.statusKey) {
      _entry
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _ribbonStyles[widget.statusKey] ?? _ribbonStyles['applied']!;
    return IgnorePointer(
      child: SizedBox(
        width: 92,
        height: 92,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: Listenable.merge([_shimmer, _entry]),
            builder: (context, _) {
              final entryT = Curves.easeOutBack.transform(_entry.value);
              return Opacity(
                opacity: _entry.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset((1 - entryT) * 30, (1 - entryT) * -30),
                  child: Transform.translate(
                    offset: const Offset(22, 22),
                    child: Transform.rotate(
                      angle: 0.7853981633974483,
                      child: _ribbonBar(style, _shimmer.value),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _ribbonBar(_RibbonStyle style, double t) {
    final shimmerX = -1.5 + (t * 3.0);
    return Container(
      width: 140,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: style.glow.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(shimmerX - 0.4, 0),
              end: Alignment(shimmerX + 0.4, 0),
              colors: const [
                Colors.transparent,
                Color(0x66FFFFFF),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.srcATop,
            child: Container(color: Colors.white),
          ),
          Text(
            style.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 1.5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "AUTO APPLY" ribbon at the top-left, marking applications
/// submitted by auto-apply.
class _AiRibbon extends StatefulWidget {
  const _AiRibbon();

  @override
  State<_AiRibbon> createState() => _AiRibbonState();
}

class _AiRibbonState extends State<_AiRibbon>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 110,
        height: 110,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: Listenable.merge([_shimmer, _entry]),
            builder: (context, _) {
              final entryT = Curves.easeOutBack.transform(_entry.value);
              return Opacity(
                opacity: _entry.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset((1 - entryT) * -30, (1 - entryT) * -30),
                  child: Transform.translate(
                    offset: const Offset(-26, 26),
                    child: Transform.rotate(
                      angle: -0.7853981633974483,
                      child: _bar(_shimmer.value),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bar(double t) {
    final shimmerX = -1.5 + (t * 3.0);
    return Container(
      width: 150,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFF5B21B6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(shimmerX - 0.4, 0),
              end: Alignment(shimmerX + 0.4, 0),
              colors: const [
                Colors.transparent,
                Color(0x66FFFFFF),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.srcATop,
            child: Container(color: Colors.white),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 11, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'AUTO APPLY',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 1.5,
                      offset: const Offset(0, 1),
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

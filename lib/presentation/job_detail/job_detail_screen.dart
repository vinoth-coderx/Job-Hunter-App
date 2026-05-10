import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/job_model.dart';
import '../../data/services/api_client.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/job_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coins_provider.dart';
import '../../providers/job_provider.dart';
import '../widgets/compact_job_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/home_section.dart';
import '../widgets/scroll_to_top_fab.dart';
import 'apply_webview_screen.dart';
import 'quick_apply_sheet.dart';
import 'similar_jobs_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Job _job;
  bool _isApplying = false;
  bool _isLoadingDetails = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _refreshFromApi();
    _trackView();
  }

  /// Fire a view-tracking call so hirers see analytics. Best-effort —
  /// swallowed errors don't degrade the page experience.
  void _trackView() {
    if (_job.id.isEmpty) return;
    () async {
      try {
        await ApiClient.instance.post('jobs/${_job.id}/view');
      } catch (_) {
        // analytics is non-critical
      }
    }();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Pull the latest server document so optional fields like the full
  /// description, skills, salary, and apply URL are always present.
  Future<void> _refreshFromApi() async {
    if (_job.id.isEmpty) return;
    setState(() => _isLoadingDetails = true);
    try {
      final fresh = await JobService().getJobById(_job.id);
      if (!mounted || fresh == null) return;
      setState(() {
        // Take everything from the server (incl. screeningQuestions,
        // requiredDocuments, isNative, applyType) and only carry over
        // match metadata, which /jobs/:id doesn't include.
        _job = fresh.copyWith(
          matchScore: _job.matchScore,
          matchedSkills: _job.matchedSkills,
          missingSkills: _job.missingSkills,
          matchReasoning: _job.matchReasoning,
        );
      });
    } catch (_) {/* keep cached job */} finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _handleApply() async {
    final jobProvider = context.read<JobProvider>();
    if (jobProvider.hasApplied(_job.id)) {
      AppSnackbar.info(context, 'You have already applied for this job');
      return;
    }

    // Native jobs use the in-app one-click sheet, not the WebView.
    if (_job.isNative) {
      final sent = await QuickApplySheet.show(context, _job);
      if (!mounted) return;
      if (sent == true) _showSuccessDialog();
      return;
    }

    final url = _job.applyUrl ?? '';
    // No external listing → record application directly via API.
    if (url.isEmpty) {
      await _markApplied(jobProvider);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      await _markApplied(jobProvider);
      return;
    }

    // Open the official site inside our app and auto-mark applied on
    // return. We treat the CTA tap itself as the intent-to-apply signal
    // (same model as Indeed/LinkedIn click-tracking) and skip the
    // post-webview "Did you apply?" sheet — it nags the user and most
    // people answer it inconsistently anyway.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplyWebviewScreen(
          url: url,
          company: _job.company,
        ),
      ),
    );
    if (!mounted) return;
    await _markApplied(jobProvider);
  }

  void _shareJob() {
    final url = _job.applyUrl;
    final text = StringBuffer()
      ..writeln(_job.title)
      ..write(_job.company);
    if (_job.location.isNotEmpty) {
      text.write(' · ${_job.location}');
    }
    if (url != null && url.isNotEmpty) {
      text
        ..writeln()
        ..write(url);
    }
    Clipboard.setData(ClipboardData(text: text.toString()));
    AppSnackbar.success(context, 'Job details copied — paste anywhere to share');
  }

  Future<void> _markApplied(JobProvider jobProvider) async {
    setState(() => _isApplying = true);
    final ok = await jobProvider.applyToJob(_job);
    if (!mounted) return;
    setState(() => _isApplying = false);
    if (ok) {
      // Sync the header coin pill from the server-confirmed balance.
      final balance = jobProvider.lastApplyCoinsBalance;
      if (balance != null) {
        context.read<CoinsProvider>().setBalance(balance);
      }
      _showSuccessDialog();
    } else {
      AppSnackbar.error(
        context,
        jobProvider.error ?? 'Failed to record application',
      );
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Application tracked',
      // Dialog paints its own animated radial-gradient backdrop, so the
      // route barrier is fully transparent — otherwise the gradient
      // washes through a flat black tint.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _ApplySuccessDialog(
        company: _job.company,
        onDone: () {
          Navigator.pop(context); // dismiss the dialog
          Navigator.pop(context); // exit job detail
        },
      ),
      // Plain fade — the dialog drives its own confetti + icon animation,
      // a competing scale/slide here just muddies the burst.
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final isSaved = jobProvider.isJobSaved(_job.id);
    final hasApplied = jobProvider.hasApplied(_job.id);

    // Match the home screen: gradient under a transparent status bar with
    // contrast-correct icons (dark icons in light mode, light icons in dark).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.gradientTop,
        floatingActionButton: ScrollToTopFab(
          controller: _scrollCtrl,
          showAfterPixels: 500,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        // The apply CTA lives in [bottomNavigationBar] so the Scaffold
        // automatically lifts the scroll-to-top FAB above it. Keeping it
        // inside the body would let the FAB overlap the button on long
        // descriptions.
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: context.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_job.isNative && _job.postedByUserId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _MessageRecruiterButton(
                      hirerUserId: _job.postedByUserId,
                      jobId: _job.id,
                    ),
                  ),
                Expanded(
                  child: PrimaryButton(
                    // Native (own-app) jobs go through QuickApplySheet —
                    // labelled "Easy Apply" with a bolt icon to mirror the
                    // One-Tap pill on the job card. Scraped jobs route to
                    // an external WebView, so they keep the generic CTA.
                    label: hasApplied
                        ? 'Already Applied ✓'
                        : (_job.isNative ? 'Easy Apply' : 'Apply for this job'),
                    icon: hasApplied
                        ? null
                        : (_job.isNative ? Icons.bolt_rounded : null),
                    isLoading: _isApplying,
                    onPressed: hasApplied ? null : _handleApply,
                    backgroundColor:
                        hasApplied ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.gradientTop, context.gradientBottom],
              stops: [0.0, 0.35],
            ),
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _CircleButton(
                        icon: Icons.ios_share_rounded,
                        onTap: _shareJob,
                      ),
                      const SizedBox(width: 10),
                      _CircleButton(
                        icon: isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        iconColor:
                            isSaved ? AppColors.primary : context.textPrimary,
                        onTap: () => jobProvider.toggleSaveJob(_job.id),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle — small visual cue that this sheet is
                      // the "card" lifting away from the gradient header.
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.cardBorder,
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                      if (_isLoadingDetails)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Header(job: _job),
                              if (_hasStatHero) ...[
                                const SizedBox(height: 14),
                                _StatHero(job: _job),
                              ],
                              if (_hasInfoRow) ...[
                                const SizedBox(height: 16),
                                _InfoChips(job: _job),
                              ],
                              if (_job.skills.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.bolt_rounded, label: 'Skills'),
                                const SizedBox(height: 12),
                                _SkillsBlock(job: _job),
                              ],
                              if (_job.niceToHaveSkills.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Nice to have',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final s in _job.niceToHaveSkills)
                                      _SoftChip(label: s),
                                  ],
                                ),
                              ],
                              if (_job.description.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.menu_book_rounded,
                                    label: 'About this role'),
                                const SizedBox(height: 12),
                                _ExpandableText(text: _job.description),
                              ],
                              if (_job.responsibilities.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.checklist_rounded,
                                    label: "What you'll do"),
                                const SizedBox(height: 10),
                                _BulletList(items: _job.responsibilities),
                              ],
                              if (_job.perks.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.celebration_rounded,
                                    label: 'Perks & benefits'),
                                const SizedBox(height: 12),
                                _PerksGrid(perks: _job.perks),
                              ],
                              if (_job.education != null &&
                                  _job.education!.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.school_rounded,
                                    label: 'Education'),
                                const SizedBox(height: 10),
                                Text(
                                  _job.education!,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              if (_job.requiredDocuments.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                _SectionTitle(
                                    icon: Icons.attach_file_rounded,
                                    label: 'Required documents'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final d in _job.requiredDocuments)
                                      _SoftChip(label: _capitalize(d)),
                                  ],
                                ),
                              ],
                              // Contact info that the recruiter dropped
                              // inline in the job description (email or
                              // phone). Surfaced as the last section so
                              // the seeker has a visible fallback when
                              // the listing doesn't expose Apply / Chat
                              // affordances. Renders nothing if neither
                              // is found.
                              ..._buildContactSection(context, _job.description),
                              if ((_job.applyUrl ?? '').isNotEmpty &&
                                  !_job.isNative) ...[
                                const SizedBox(height: 28),
                                _SourceLink(
                                  url: _job.applyUrl!,
                                  // Tapping the source link opens the same in-app
                                  // apply browser; if the user submits and taps
                                  // "I've applied" we record it via the API.
                                  onTap: _handleApply,
                                ),
                              ],
                              _SimilarJobs(currentJob: _job),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasInfoRow =>
      _job.employmentType.isNotEmpty ||
      _job.remoteType.isNotEmpty ||
      (_job.openingsCount != null && _job.openingsCount! > 0);

  bool get _hasStatHero =>
      _job.salary.isNotEmpty || _job.experience.isNotEmpty;

  /// Renders the "Recruiter contact" section if the job description
  /// includes an email address or phone number. Returns an empty list
  /// otherwise so the section disappears cleanly. Phones and emails are
  /// each tappable — they open the dialer / mail composer via
  /// `url_launcher`.
  ///
  /// Kept inline (rather than as a top-level widget) because both the
  /// extraction regexes and the launch handlers are job-detail-specific
  /// and we'd just be threading them around with extra props.
  List<Widget> _buildContactSection(BuildContext context, String description) {
    final emails = _extractEmails(description);
    final phones = _extractPhones(description);
    if (emails.isEmpty && phones.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      _SectionTitle(
        icon: Icons.contact_mail_rounded,
        label: 'Recruiter contact',
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'Tap to open your dialer or mail app.',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.textTertiary,
            fontSize: 12,
          ),
        ),
      ),
      for (final email in emails)
        _ContactRow(
          icon: Icons.alternate_email_rounded,
          label: email,
          subtitle: 'Email',
          onTap: () => _launchUri(context, Uri(scheme: 'mailto', path: email)),
        ),
      for (final phone in phones)
        _ContactRow(
          icon: Icons.call_rounded,
          label: phone,
          subtitle: 'Call',
          onTap: () => _launchUri(
            context,
            Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^+0-9]'), '')),
          ),
        ),
    ];
  }

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        AppSnackbar.error(context, 'Could not open ${uri.scheme} link');
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, e.toString());
    }
  }
}

/// De-duped, ordered email matches from the description. Limited to a
/// reasonable cap so a pathological description doesn't render dozens
/// of contact rows.
List<String> _extractEmails(String text) {
  if (text.isEmpty) return const [];
  final pattern = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  final seen = <String>{};
  final out = <String>[];
  for (final m in pattern.allMatches(text)) {
    final v = m.group(0)!;
    final lc = v.toLowerCase();
    if (seen.add(lc)) out.add(v);
    if (out.length >= 4) break;
  }
  return out;
}

/// Phone numbers matching common international + Indian formats. We
/// reject obvious false positives — runs of digits that look like
/// salary figures, years, or zip codes — by requiring 10+ digits in
/// the canonical form. Spaces, hyphens, parens, and a leading `+` are
/// allowed in the source string and stripped for the dialer launch.
List<String> _extractPhones(String text) {
  if (text.isEmpty) return const [];
  final pattern = RegExp(
    r'(?:(?:\+|00)\d{1,3}[\s\-]?)?(?:\(\d{1,4}\)[\s\-]?)?\d{2,5}[\s\-]?\d{3,5}[\s\-]?\d{3,5}',
  );
  final seen = <String>{};
  final out = <String>[];
  for (final m in pattern.allMatches(text)) {
    final v = m.group(0)!.trim();
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 15) continue;
    if (seen.add(digits)) out.add(v);
    if (out.length >= 3) break;
  }
  return out;
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textTertiary,
                          fontSize: 11.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 16, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join('-');
}

/// Celebration dialog after a successful apply.
///
/// One [AnimationController] drives every piece via [Interval]s so the
/// staggered ring ripples, bouncy check icon, slide-up text, and button
/// fade all share the same vsync — no per-piece controllers, no jank.
/// Everything moves with [Transform]/[Opacity] (composite-only ops) so
/// the GPU does the work and the timeline stays smooth on low-end phones.
/// Full-screen "Application sent!" celebration. The icon pops in with
/// an elastic bounce while a confetti burst fans out from the center
/// and falls under gravity. A 3-pulse haptic burst fires synchronously
/// with the icon pop so the celebration feels physical.
class _ApplySuccessDialog extends StatefulWidget {
  final String company;
  final VoidCallback onDone;
  const _ApplySuccessDialog({required this.company, required this.onDone});

  @override
  State<_ApplySuccessDialog> createState() => _ApplySuccessDialogState();
}

class _ApplySuccessDialogState extends State<_ApplySuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _iconScale;
  late final Animation<double> _titleT;
  late final Animation<double> _subT;
  late final Animation<double> _btnT;
  late final List<_ConfettiPiece> _pieces;

  /// Latches the max value of [_c] seen so far. Confetti is a one-shot
  /// physical burst — pieces shouldn't suck back to center on reverse,
  /// so the painter reads from this notifier (which never decreases)
  /// instead of [_c] directly. The pieces fade out with the wrapper
  /// FadeTransition once the dialog dismisses.
  final ValueNotifier<double> _burstSeen = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();

    // Three-pulse haptic burst — heavy + medium + medium spaced ~120ms
    // apart matches the rhythm of a party-popper "pop pop pop".
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) HapticFeedback.mediumImpact();
    });

    _pieces = _ConfettiPiece.generate(count: 70);

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      // Reverse runs ~2.7× faster than entry — exit should feel snappy
      // but still play the inverse stagger so the dialog never snaps shut.
      reverseDuration: const Duration(milliseconds: 740),
    );
    _c.addListener(() {
      if (_c.value > _burstSeen.value) _burstSeen.value = _c.value;
    });
    _iconScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      // Elastic looks broken in reverse — use a plain ease-in for shrink-out.
      reverseCurve: const Interval(0.0, 0.45, curve: Curves.easeInCubic),
    );
    _titleT = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.30, 0.55, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.30, 0.55, curve: Curves.easeInCubic),
    );
    _subT = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.40, 0.65, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.40, 0.65, curve: Curves.easeInCubic),
    );
    _btnT = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.55, 0.85, curve: Curves.easeInCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _burstSeen.dispose();
    super.dispose();
  }

  /// Reverses the stagger first so each element animates out the way
  /// it came in (button → subtitle → title → icon), then hands off to
  /// [widget.onDone] which closes the dialog via the route's fade.
  Future<void> _handleDone() async {
    await _c.reverse();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated radial-gradient backdrop — fades in deep emerald that
        // washes outward from where the icon will land, then settles to
        // a near-black halo. Replaces the flat black barrier and makes
        // the celebration feel intentional rather than tacked-on.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Color.lerp(const Color(0xFF064E3B),
                          const Color(0xFF065F46), t)!,
                      Color.lerp(const Color(0xFF111827),
                          const Color(0xFF0B1220), t)!,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              // Three concentric ring waves expanding from the icon —
              // Apple-Pay-style "tap accepted" affordance. Painted in a
              // separate layer so the rings sit *behind* the badge while
              // the confetti burst flies *in front*.
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, __) => CustomPaint(
                        painter: _RingWavePainter(t: _c.value),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
              // Confetti spans the full screen so pieces can fly past the
              // edge of the centered text/button — RepaintBoundary keeps
              // the per-frame canvas redraw isolated from the rest.
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _burstSeen,
                      builder: (_, __) => CustomPaint(
                        painter: _ConfettiPainter(
                          pieces: _pieces,
                          t: _burstSeen.value,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) {
                          // Gentle continuous breathe on the badge halo
                          // after entry — keeps the moment alive instead
                          // of going static after the elastic settle.
                          final breathe = _c.value > 0.5
                              ? 1 +
                                  0.04 *
                                      math.sin(
                                          (_c.value - 0.5) * math.pi * 4)
                              : 1.0;
                          return Transform.scale(
                            scale: _iconScale.value * breathe,
                            child: _CheckBadge(progress: _c),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                  _SlideFade(
                    t: _titleT,
                    child: Text(
                      'Application sent!',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SlideFade(
                    t: _subT,
                    child: Text(
                      'Tracked at ${widget.company}. Keep the streak going!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.45,
                      ),
                    ),
                  ),
                      const SizedBox(height: 32),
                      _SlideFade(
                        t: _btnT,
                        child: SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: 'Keep hunting',
                            onPressed: _handleDone,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated checkmark badge — circular surface with a stroke-drawn tick
/// that paints itself onto the canvas progressively. Looks far more
/// "alive" than dropping a pre-rendered Icon, and fades out cleanly on
/// reverse because the painter only reads `progress.value`.
class _CheckBadge extends StatelessWidget {
  final Animation<double> progress;
  const _CheckBadge({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        // Stroke draws between t=0.18 and t=0.55 — starts a beat after
        // the elastic pop begins so the user sees the badge land first,
        // then the tick "writes" inside it.
        final raw = ((progress.value - 0.18) / (0.55 - 0.18)).clamp(0.0, 1.0);
        final strokeT = Curves.easeOutCubic.transform(raw);
        return Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.55),
                blurRadius: 44,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.25),
                blurRadius: 80,
                spreadRadius: 24,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _CheckStrokePainter(t: strokeT),
          ),
        );
      },
    );
  }
}

class _CheckStrokePainter extends CustomPainter {
  final double t;
  _CheckStrokePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final w = size.width;
    final h = size.height;
    // Tick polyline calibrated against a 116×116 badge — the values
    // below are normalised so it scales cleanly on smaller devices.
    final p1 = Offset(w * 0.30, h * 0.52);
    final p2 = Offset(w * 0.46, h * 0.66);
    final p3 = Offset(w * 0.74, h * 0.40);

    final firstLeg = (p2 - p1).distance;
    final secondLeg = (p3 - p2).distance;
    final total = firstLeg + secondLeg;
    final drawn = total * t;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= firstLeg) {
      final f = drawn / firstLeg;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * f, p1.dy + (p2.dy - p1.dy) * f);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final f = ((drawn - firstLeg) / secondLeg).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * f, p2.dy + (p3.dy - p2.dy) * f);
    }

    final paint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckStrokePainter old) => old.t != t;
}

/// Three concentric ring waves that expand from the centre and fade out —
/// reads as "tap accepted, energy radiating outward". Each ring is
/// staggered so they chase each other instead of all firing at once.
class _RingWavePainter extends CustomPainter {
  final double t;
  _RingWavePainter({required this.t});

  static const _ringStarts = [0.05, 0.18, 0.32];

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.max(size.width, size.height) * 0.65;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final start in _ringStarts) {
      final raw = ((t - start) / 0.55).clamp(0.0, 1.0);
      if (raw == 0) continue;
      final eased = Curves.easeOutCubic.transform(raw);
      final radius = 60 + eased * maxR;
      final alpha = (1 - raw).clamp(0.0, 1.0) * 0.55;
      paint.color = AppColors.success.withValues(alpha: alpha);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingWavePainter old) => old.t != t;
}

/// One piece of confetti. Position is computed at paint-time from
/// projectile motion (start + vt + ½gt²) so the painter is stateless.
class _ConfettiPiece {
  final double angle; // launch direction in radians
  final double speed; // launch speed (px/s)
  final double rotationSpeed; // rad/s
  final double initialRotation;
  final Color color;
  final double size;
  final bool isCircle;

  const _ConfettiPiece({
    required this.angle,
    required this.speed,
    required this.rotationSpeed,
    required this.initialRotation,
    required this.color,
    required this.size,
    required this.isCircle,
  });

  static List<_ConfettiPiece> generate({required int count}) {
    // Seed the RNG so every burst looks the same — predictable visuals
    // across re-runs without storing per-piece state.
    final r = math.Random(7);
    const palette = [
      Color(0xFF22C55E), // success green
      Color(0xFF3B82F6), // primary blue
      Color(0xFFF59E0B), // amber
      Color(0xFFEC4899), // pink
      Color(0xFF8B5CF6), // violet
      Color(0xFFFBBF24), // gold
    ];
    return List.generate(count, (_) {
      // Launch upward with ±~80° spread so most pieces fly up first
      // before gravity pulls them down — looks like a real burst.
      final angle =
          -math.pi / 2 + (r.nextDouble() - 0.5) * (math.pi * 0.9);
      return _ConfettiPiece(
        angle: angle,
        speed: 600 + r.nextDouble() * 520,
        rotationSpeed: (r.nextDouble() - 0.5) * 12,
        initialRotation: r.nextDouble() * math.pi * 2,
        color: palette[r.nextInt(palette.length)],
        size: 8 + r.nextDouble() * 7,
        isCircle: r.nextBool(),
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t; // 0..1, drives projectile time

  _ConfettiPainter({required this.pieces, required this.t});

  static const double _gravity = 1400; // px/s²
  static const double _durationSec = 1.8; // matches controller duration

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final time = t * _durationSec;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    // Fade out over the last quarter so the burst doesn't pop off-screen.
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);

    for (final p in pieces) {
      final vx = math.cos(p.angle) * p.speed;
      final vy = math.sin(p.angle) * p.speed;
      final dx = cx + vx * time;
      final dy = cy + vy * time + 0.5 * _gravity * time * time;

      paint.color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.initialRotation + p.rotationSpeed * time);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Slide-up + fade-in driven by an [Interval]-curved animation.
class _SlideFade extends StatelessWidget {
  final Animation<double> t;
  final Widget child;
  const _SlideFade({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, c) => Opacity(
        opacity: t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - t.value) * 12),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  final Job job;
  const _Header({required this.job});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: context.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(Icons.apartment_rounded,
          color: context.textTertiary, size: 32),
    );
    final hasMeta = job.location.isNotEmpty || job.postedTime.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo plate — subtle gradient border + drop shadow so the
            // company mark feels presented rather than sitting flat.
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: job.companyLogo.isEmpty
                    ? placeholder
                    : CachedNetworkImage(
                        imageUrl: job.companyLogo,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => placeholder,
                        errorWidget: (_, __, ___) => placeholder,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (job.company.isNotEmpty)
                    Text(
                      job.company,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Top-right corner badge — match score gets priority because
            // it's the user's "should I care?" signal at-a-glance. When
            // there's no match score we fall through to nothing here so
            // the row doesn't reserve dead space.
            if (job.matchScore != null) ...[
              const SizedBox(width: 8),
              _MatchBadge(score: job.matchScore!.round()),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Title row — title left, deadline pill right. Wrap so a long
        // title pushes the pill to its own line instead of clipping.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                job.title,
                style: AppTextStyles.h2.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.22,
                ),
              ),
            ),
            if (job.applicationDeadline != null) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _ClosingPill(deadline: job.applicationDeadline!),
              ),
            ],
          ],
        ),
        if (hasMeta) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (job.location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: context.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      job.location,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12.5,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (job.postedTime.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: context.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      job.postedTime,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12.5,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        // Match-score reasoning appears as a subtle one-liner under the
        // meta row so the "why" is still visible without dragging in the
        // big match-summary card.
        if (job.matchScore != null &&
            job.matchReasoning != null &&
            job.matchReasoning!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.matchReasoning!,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Compact "100% match" badge for the top-right of the header. Colour
/// follows the same fit-tier scale as the old `_MatchSummary` card so
/// users who already learned the colour code recognise it instantly.
class _MatchBadge extends StatelessWidget {
  final int score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 90) {
      color = AppColors.success;
    } else if (score >= 75) {
      color = AppColors.primary;
    } else if (score >= 50) {
      color = AppColors.warning;
    } else {
      color = context.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$score% match',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
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

/// Compact pill version of the old `_DeadlineBadge`. Lives next to the
/// title rather than as its own banner — the deadline is a useful but
/// secondary signal (the salary + match score deserve the visual real
/// estate the banner used to take).
class _ClosingPill extends StatelessWidget {
  final DateTime deadline;
  const _ClosingPill({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) return const SizedBox.shrink();
    final daysLeft = deadline.difference(now).inDays;
    final isUrgent = daysLeft <= 3;
    final isSoon = daysLeft <= 7;
    final color = isUrgent
        ? AppColors.urgent
        : isSoon
            ? AppColors.warning
            : AppColors.info;
    final label = daysLeft == 0
        ? 'Closes today'
        : daysLeft == 1
            ? 'Closes tomorrow'
            : 'Closes in ${daysLeft}d';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Similar jobs" rail — pulls from the already-loaded match feed in
/// JobProvider. Filters to same category, drops the current job, caps
/// at 12. The trailing card opens a full-screen list. If nothing usable
/// is loaded, the section hides entirely (we never invent jobs).
class _SimilarJobs extends StatelessWidget {
  final Job currentJob;
  const _SimilarJobs({required this.currentJob});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<JobProvider>().jobs;
    final similar = feed
        .where((j) => j.id != currentJob.id && j.category == currentJob.category)
        .take(12)
        .toList();
    if (similar.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Similar jobs',
            subtitle: 'Other ${currentJob.category} roles you may like',
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          ),
          SizedBox(
            // Match HorizontalCardList default so CompactJobCard (and the
            // applied/match pill row) doesn't overflow the rail by 1px.
            height: 208,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              // +1 trailing slot for the "View more" card.
              itemCount: similar.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == similar.length) {
                  return _ViewMoreCard(currentJob: currentJob);
                }
                final job = similar[i];
                return CompactJobCard(
                  job: job,
                  applied: context.read<JobProvider>().hasApplied(job.id),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(job: job),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing "View more" affordance at the end of the similar-jobs rail.
/// Tapping opens [SimilarJobsScreen] with the full vertical list.
class _ViewMoreCard extends StatelessWidget {
  final Job currentJob;
  const _ViewMoreCard({required this.currentJob});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SimilarJobsScreen(currentJob: currentJob),
              ),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'View more',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Browse all ${currentJob.category} jobs',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big-and-bold "salary + experience" hero so the user gets the two
/// most important answers (How much? How senior?) at a glance.
/// Indeed-style "key facts" row — salary + experience as inline rows
/// rather than a big card. Each row: small icon + label on left, value
/// in bold on the right. Reads like a structured fact sheet without
/// fighting the title or match badge for visual weight.
class _StatHero extends StatelessWidget {
  final Job job;
  const _StatHero({required this.job});

  @override
  Widget build(BuildContext context) {
    final showSalary = job.salary.isNotEmpty;
    final showExperience = job.experience.isNotEmpty;
    if (!showSalary && !showExperience) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSalary)
          _FactRow(
            icon: Icons.payments_rounded,
            label: 'Pay',
            value: job.salary,
          ),
        if (showSalary && showExperience)
          Divider(
            height: 1,
            thickness: 1,
            color: context.divider.withValues(alpha: 0.5),
          ),
        if (showExperience)
          _FactRow(
            icon: Icons.workspace_premium_rounded,
            label: 'Experience',
            value: job.experience,
          ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Label + value sit side by side instead of pushed to opposite
          // edges. Reads "Pay  ₹2L – ₹9L" like a plain sentence — same
          // pattern Indeed uses.
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact secondary meta — job type, work mode, posted date — as
/// soft pill-chips. When the user's profile has preferences that match
/// the job's job-type or remote-mode, those chips light up green with a
/// check (same treatment as a matched skill) so the seeker sees "this
/// fits how I want to work" at a glance.
class _InfoChips extends StatelessWidget {
  final Job job;
  const _InfoChips({required this.job});

  static String _norm(String s) => s.toLowerCase().trim();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final prefJobTypes = (user?.preferredJobTypes ?? const <String>[])
        .map(_norm)
        .toSet();
    final prefRemote = (user?.preferredRemote ?? const <String>[])
        .map(_norm)
        .toSet();

    final chips = <Widget>[];
    if (job.employmentType.isNotEmpty) {
      chips.add(_InfoPill(
        icon: Icons.work_outline_rounded,
        label: _capitalize(job.employmentType),
        matched: prefJobTypes.contains(_norm(job.employmentType)),
      ));
    }
    if (job.remoteType.isNotEmpty) {
      chips.add(_InfoPill(
        icon: Icons.public_rounded,
        label: _capitalize(job.remoteType),
        matched: prefRemote.contains(_norm(job.remoteType)),
      ));
    }
    if (job.openingsCount != null && job.openingsCount! > 0) {
      chips.add(_InfoPill(
        icon: Icons.groups_rounded,
        label:
            '${job.openingsCount} ${job.openingsCount == 1 ? 'opening' : 'openings'}',
      ));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  // True when this chip lines up with one of the user's stated
  // preferences — drives the green-tinted "matched" treatment.
  final bool matched;
  const _InfoPill({
    required this.icon,
    required this.label,
    this.matched = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = matched
        ? AppColors.success.withValues(alpha: 0.10)
        : context.surfaceVariant;
    final border = matched
        ? AppColors.success.withValues(alpha: 0.30)
        : Colors.transparent;
    final fg = matched ? AppColors.success : context.textPrimary;
    return Container(
      padding: EdgeInsets.fromLTRB(matched ? 10 : 12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matched ? Icons.check_rounded : icon,
            size: matched ? 15 : 14,
            color: matched ? AppColors.success : context.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLink extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _SourceLink({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? url;
    return InkWell(
      onTap: onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: url));
        AppSnackbar.success(context, 'Link copied');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.open_in_new_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original posting', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.surface,
            shape: BoxShape.circle,
            border: Border.all(color: context.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: iconColor ?? context.textPrimary),
        ),
      ),
    );
  }
}

/// "Message recruiter" CTA on a native job. Opens-or-creates the
/// conversation via the existing startConversation API, then jumps into
/// the chat. Disabled while the request is in flight to prevent dupes.
class _MessageRecruiterButton extends StatefulWidget {
  final String hirerUserId;
  final String jobId;
  const _MessageRecruiterButton({
    required this.hirerUserId,
    required this.jobId,
  });

  @override
  State<_MessageRecruiterButton> createState() =>
      _MessageRecruiterButtonState();
}

class _MessageRecruiterButtonState extends State<_MessageRecruiterButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final conv = await ChatService.instance.startConversation(
        otherUserId: widget.hirerUserId,
        jobId: widget.jobId,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.chat, arguments: conv.id);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Could not start chat: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
      ),
      child: IconButton(
        tooltip: 'Message recruiter',
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// New presentation pieces — added when the JobDetail layout was
// expanded to surface fields the hirer fills in (responsibilities,
// perks, deadline, education, nice-to-haves, required documents).
// Each one stays opt-in: the parent only renders the section when its
// data list/value is present, so scraped jobs don't show empty stubs.
// ─────────────────────────────────────────────────────────────────────

/// Section header with a small leading icon — gives a consistent
/// "rhythm" between the multiple new sections so the page reads as a
/// single document instead of a stack of independent cards.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.16),
                AppColors.primary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: AppTextStyles.h4.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}


/// Skills row with matched/missing split. A job skill is marked
/// "matched" (green tick) when EITHER:
///   1. the AI matcher returned it in `job.matchedSkills`, OR
///   2. the user's own profile.skills contains it (case-insensitive,
///      trimmed) — which catches the common case where the AI matcher
///      hasn't run yet, or under-counted what the user actually has.
///
/// Doing the second check client-side fixes the bug where a skill the
/// user obviously had ("mongodb") was rendering as neutral just because
/// the LLM missed it.
class _SkillsBlock extends StatelessWidget {
  final Job job;
  const _SkillsBlock({required this.job});

  static String _norm(String s) => s.toLowerCase().trim();

  @override
  Widget build(BuildContext context) {
    final userSkills = context.select<AuthProvider, Set<String>>(
      (a) => (a.user?.skills ?? const <String>[])
          .map(_norm)
          .where((s) => s.isNotEmpty)
          .toSet(),
    );
    final aiMatched = job.matchedSkills.map(_norm).toSet();
    final aiMissing = job.missingSkills.map(_norm).toSet();
    // Union of AI-confirmed matches + everything the user has on their
    // profile that the job mentions.
    final matchedSet = {...aiMatched, ...userSkills};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in job.skills)
          _SkillChip(
            label: s,
            kind: matchedSet.contains(_norm(s))
                ? _SkillKind.matched
                : aiMissing.contains(_norm(s))
                    ? _SkillKind.missing
                    : _SkillKind.neutral,
          ),
      ],
    );
  }
}

enum _SkillKind { matched, missing, neutral }

class _SkillChip extends StatelessWidget {
  final String label;
  final _SkillKind kind;
  const _SkillChip({required this.label, required this.kind});

  // Match the soft green check pill used on job cards (Full-Time /
  // salary chips) so a matched skill reads consistent with the rest
  // of the app's "you have this" cue.
  static const _matchedFg = Color(0xFF1B7F3C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (kind) {
      case _SkillKind.matched:
        final bg = isDark
            ? AppColors.success.withValues(alpha: 0.16)
            : AppColors.success.withValues(alpha: 0.10);
        final fg = isDark ? const Color(0xFF7BD89A) : _matchedFg;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
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
            ],
          ),
        );
      case _SkillKind.missing:
        return _flatChip(
          bg: context.surfaceVariant,
          fg: context.textSecondary,
        );
      case _SkillKind.neutral:
        return _flatChip(
          bg: AppColors.primary.withValues(alpha: 0.10),
          fg: AppColors.primary,
        );
    }
  }

  Widget _flatChip({required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Subtle outlined chip — used for nice-to-have skills and required
/// documents where we want the data visible but not competing with
/// the primary skill row.
class _SoftChip extends StatelessWidget {
  final String label;
  const _SoftChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardBorder),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: context.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ExpandableText extends StatelessWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: context.textSecondary,
        height: 1.65,
      ),
    );
  }
}

/// Vertical bullet list for responsibilities — preserves order, uses a
/// tiny circular bullet so the layout reads as a clean checklist.
class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Two-column tile grid for perks. Each tile gets a subtle gradient +
/// icon mapped from the perk text, so a "remote work" perk reads
/// visually different from "free lunch" without a custom asset.
class _PerksGrid extends StatelessWidget {
  final List<String> perks;
  const _PerksGrid({required this.perks});

  static IconData _iconFor(String perk) {
    final p = perk.toLowerCase();
    if (p.contains('remote') || p.contains('work from home')) {
      return Icons.home_work_rounded;
    }
    if (p.contains('insurance') ||
        p.contains('health') ||
        p.contains('medical')) {
      return Icons.medical_services_rounded;
    }
    if (p.contains('food') || p.contains('lunch') || p.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (p.contains('learn') ||
        p.contains('education') ||
        p.contains('course')) {
      return Icons.school_rounded;
    }
    if (p.contains('flex') || p.contains('hour')) {
      return Icons.schedule_rounded;
    }
    if (p.contains('bonus') || p.contains('stock') || p.contains('equity')) {
      return Icons.savings_rounded;
    }
    if (p.contains('travel')) return Icons.flight_takeoff_rounded;
    if (p.contains('gym') || p.contains('fitness') || p.contains('wellness')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        // Two columns on phones, three on wider tablets — never stretch
        // a single tile past ~220px wide where the gradient looks washed.
        final cols = c.maxWidth > 520 ? 3 : 2;
        const gap = 10.0;
        final tileWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final perk in perks)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.10),
                        AppColors.primary.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _iconFor(perk),
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        perk,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/resume_profile_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/resume_profile_provider.dart';
import '../widgets/app_avatar.dart';
import 'edit/resume_editors.dart';
import 'resume_viewer_sheet.dart';

class ResumeProfileScreen extends StatefulWidget {
  const ResumeProfileScreen({super.key});

  @override
  State<ResumeProfileScreen> createState() => _ResumeProfileScreenState();
}

class _ResumeProfileScreenState extends State<ResumeProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Seed empty resume fields from the authenticated user's backend
    // profile (onboarding answers, parsed resume). Deferred so it runs
    // after first frame, avoiding notifyListeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      final provider = context.read<ResumeProfileProvider>();
      provider.seedFromUserIfEmpty(user);
      // Pull resume meta + parsed structured fields from the backend so
      // the "My Resume" card and the section auto-fill survive a fresh
      // install / device switch where local storage was wiped.
      // Fire-and-forget — provider notifies listeners as it lands.
      provider.syncFromBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final profile = context.watch<ResumeProfileProvider>().profile;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(
        children: [
          _AppBar(profile: profile),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                _ProfileHeaderCard(user: user, profile: profile),
                const SizedBox(height: 12),
                _ResumeCard(profile: profile),
                const SizedBox(height: 12),
                _ResumeHeadlineCard(headline: profile.resumeHeadline),
                const SizedBox(height: 12),
                _KeySkillsCard(skills: profile.keySkills),
                const SizedBox(height: 12),
                _EmploymentCard(entries: profile.employments),
                const SizedBox(height: 12),
                _EducationCard(entries: profile.educations),
                const SizedBox(height: 12),
                _ITSkillsCard(skills: profile.itSkills),
                const SizedBox(height: 12),
                _ProjectsCard(projects: profile.projects),
                const SizedBox(height: 12),
                _ProfileSummaryCard(summary: profile.profileSummary),
                const SizedBox(height: 12),
                _AccomplishmentsCard(items: profile.accomplishments),
                const SizedBox(height: 12),
                _CareerProfileCard(career: profile.careerProfile),
                const SizedBox(height: 12),
                _PersonalDetailsCard(personal: profile.personalDetails),
                const SizedBox(height: 12),
                _LanguagesCard(languages: profile.languages),
                const SizedBox(height: 12),
                _DiversityCard(note: profile.diversityNote),
                const SizedBox(height: 28),
                _BottomFooter(percent: profile.completionPercent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Press-to-scale (symmetric down/up) — used by tappable cards
// =============================================================
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTap: disabled ? null : widget.onTap,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: Duration(milliseconds: _down ? 120 : 180),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// =============================================================
// App bar with embedded completion progress
// =============================================================
class _AppBar extends StatelessWidget {
  final ResumeProfile profile;
  const _AppBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final percent = profile.completionPercent;
    return Container(
      padding: EdgeInsets.fromLTRB(8, topInset + 6, 12, 10),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded,
                    color: context.textPrimary),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Profile',
                        style: AppTextStyles.h4
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      '$percent% complete',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _completionColor(percent),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percent / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: context.divider.withValues(alpha: 0.4),
                  valueColor:
                      AlwaysStoppedAnimation(_completionColor(percent)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Color _completionColor(int percent) {
    if (percent >= 80) return AppColors.success;
    if (percent >= 50) return AppColors.warning;
    return AppColors.urgent;
  }
}

// =============================================================
// Reusable section card with optional leading icon + status chip
// =============================================================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final VoidCallback? onEdit;
  final Widget? trailing;
  final _StatusChip? status;
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.onEdit,
    this.trailing,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onEdit,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: context.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 6),
                status!,
              ],
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  factory _StatusChip.complete() => const _StatusChip(
        label: 'Complete',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      );

  factory _StatusChip.boost(String boost) => _StatusChip(
        label: boost,
        icon: Icons.trending_up_rounded,
        color: AppColors.warning,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 1. Profile Header card
// =============================================================
class _ProfileHeaderCard extends StatelessWidget {
  final UserModel? user;
  final ResumeProfile profile;
  const _ProfileHeaderCard({required this.user, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = user?.name.toUpperCase() ?? 'GUEST USER';
    final email = user?.email.isNotEmpty == true
        ? user!.email
        : '';
    final phone = user?.phone.isNotEmpty == true ? user!.phone : '';
    final percent = profile.completionPercent;

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtle accent strip at top
          Container(
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AvatarWithRing(
                        photoUrl: user?.photoUrl,
                        fallbackInitial:
                            name.isNotEmpty ? name.substring(0, 1) : '?',
                        percent: percent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => editHeader(context),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.h3.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit_outlined,
                                        size: 16,
                                        color: context.textSecondary),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Last updated  •  ${_today()}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: context.divider),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => editHeader(context),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      _MetaRow(
                        icon: Icons.location_on_outlined,
                        text: profile.location.isEmpty
                            ? 'Add location'
                            : profile.location,
                      ),
                      _MetaRow(
                        icon: Icons.work_outline_rounded,
                        text: profile.experience.isEmpty
                            ? 'Add experience'
                            : profile.experience,
                      ),
                      _MetaRow(
                        icon: Icons.currency_rupee_rounded,
                        text: profile.currentSalary.isEmpty
                            ? 'Add current salary'
                            : profile.currentSalary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (phone.isNotEmpty)
                  _MetaRow(
                    icon: Icons.phone_outlined,
                    text: phone,
                    verified: true,
                  ),
                if (email.isNotEmpty)
                  _MetaRow(
                    icon: Icons.mail_outline_rounded,
                    text: email,
                    verified: true,
                  ),
                GestureDetector(
                  onTap: () => editHeader(context),
                  behavior: HitTestBehavior.opaque,
                  child: _MetaRow(
                    icon: Icons.event_available_outlined,
                    text: profile.availability.isEmpty
                        ? 'Add availability'
                        : profile.availability,
                  ),
                ),
                const SizedBox(height: 14),
                _MissingDetailsBanner(profile: profile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _today() {
    final m = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final n = DateTime.now();
    return '${n.day} ${m[n.month - 1]}, ${n.year}';
  }
}

class _AvatarWithRing extends StatelessWidget {
  final String? photoUrl;
  final String fallbackInitial;
  final int percent;
  const _AvatarWithRing({
    required this.photoUrl,
    required this.fallbackInitial,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.surface,
              border: Border.all(color: context.surface, width: 4),
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                backgroundColor: context.divider,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ),
          AppAvatar(
            url: photoUrl,
            name: fallbackInitial,
            size: 68,
          ),
          Positioned(
            bottom: -4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool verified;
  const _MetaRow({
    required this.icon,
    required this.text,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (verified) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.success),
          ],
        ],
      ),
    );
  }
}

class _MissingDetailsBanner extends StatelessWidget {
  final ResumeProfile profile;
  const _MissingDetailsBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    final missing = <(String, String, VoidCallback)>[];
    if (profile.employments.isEmpty) {
      missing.add(('Add company name and designation', '↑ 10%',
          () => manageEmployments(context)));
    }
    if (profile.profileSummary.isEmpty) {
      missing.add(
          ('Add job summary', '↑ 8%', () => editSummary(context)));
    }
    if (profile.resumeFileName.isEmpty) {
      missing.add(('Upload resume', '↑ 12%',
          () => pickAndSaveResume(context)));
    }
    if (profile.personalDetails.address.isEmpty) {
      missing
          .add(('Add address', '↑ 4%', () => editPersonal(context)));
    }

    if (missing.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withValues(alpha: 0.12),
              AppColors.success.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your profile looks great!',
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                  Text(
                    'Recruiters are 3× more likely to view a complete profile.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final visible = missing.take(2).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.warning.withValues(alpha: 0.18),
                  AppColors.warning.withValues(alpha: 0.08),
                ]
              : const [Color(0xFFFFF3E6), Color(0xFFFFE7CC)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 6),
              Text(
                'Boost your profile',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.warning
                      : const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in visible) ...[
            _MissingItem(label: m.$1, percent: m.$2, onTap: m.$3),
            if (m != visible.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _PressScale(
              onTap: visible.first.$3,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A45), Color(0xFFFF5A2E)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A45).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Add ${missing.length} missing detail${missing.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingItem extends StatelessWidget {
  final String label;
  final String percent;
  final VoidCallback onTap;
  const _MissingItem({
    required this.label,
    required this.percent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add_rounded,
                size: 14, color: AppColors.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Text(percent,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// =============================================================
// 2. Resume card
// =============================================================
class _ResumeCard extends StatelessWidget {
  final ResumeProfile profile;
  const _ResumeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasResume = profile.resumeFileName.isNotEmpty;
    return _SectionCard(
      title: 'Resume',
      icon: Icons.description_outlined,
      status: hasResume ? _StatusChip.complete() : _StatusChip.boost('+12%'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasResume) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.urgent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.resumeFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${_formatSize(profile.resumeSizeBytes)} · Uploaded ${profile.resumeUploadedOn}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showResumeViewer(
                    context,
                    filePath: profile.resumeFilePath,
                    fileName: profile.resumeFileName,
                  ),
                  icon: const Icon(Icons.visibility_outlined,
                      color: AppColors.primary),
                ),
                IconButton(
                  onPressed: () => confirmDeleteResume(context),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.urgent),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DottedBorderBox(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  _PressScale(
                    onTap: () => pickAndSaveResume(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.upload_file_rounded,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(hasResume ? 'Update resume' : 'Upload resume',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Supported Formats: doc, docx, rtf, pdf, upto 2 MB',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: context.divider),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rrect);
    final dashWidth = 5.0;
    final dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
            metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================
// 4. Resume headline
// =============================================================
class _ResumeHeadlineCard extends StatelessWidget {
  final String headline;
  const _ResumeHeadlineCard({required this.headline});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Resume headline',
      icon: Icons.short_text_rounded,
      onEdit: () => editHeadline(context),
      status: headline.isEmpty
          ? _StatusChip.boost('+5%')
          : _StatusChip.complete(),
      child: Text(
        headline.isEmpty
            ? 'Tap the pencil to add a resume headline.'
            : headline,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: headline.isEmpty
              ? context.textTertiary
              : context.textPrimary,
        ),
      ),
    );
  }
}

// =============================================================
// 5. Key skills (chips)
// =============================================================
class _KeySkillsCard extends StatelessWidget {
  final List<String> skills;
  const _KeySkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Key skills',
      icon: Icons.bolt_rounded,
      onEdit: () => editKeySkills(context),
      status: skills.isEmpty
          ? _StatusChip.boost('+8%')
          : _StatusChip.complete(),
      child: skills.isEmpty
          ? Text('No skills added yet.', style: AppTextStyles.bodySmall)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in skills)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.primaryTintBg,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      s,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.primaryTintFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// =============================================================
// 6. Employment
// =============================================================
class _EmploymentCard extends StatelessWidget {
  final List<EmploymentEntry> entries;
  const _EmploymentCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Employment',
      icon: Icons.business_center_outlined,
      status: entries.isEmpty
          ? _StatusChip.boost('+10%')
          : _StatusChip.complete(),
      trailing: TextButton(
        onPressed: () => manageEmployments(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(entries.isEmpty ? 'Add' : 'Manage',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: entries.isEmpty
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your employment details help recruiters understand your experience.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.business_center_outlined,
                              size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(entries[i].designation,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w800)),
                                  ),
                                  if (entries[i].current) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(entries[i].company,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  )),
                              Text(entries[i].period,
                                  style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < entries.length - 1)
                    Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color:
                            context.divider.withValues(alpha: 0.5)),
                ],
              ],
            ),
    );
  }
}

// =============================================================
// 7. Education
// =============================================================
class _EducationCard extends StatelessWidget {
  final List<EducationEntry> entries;
  const _EducationCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Education',
      icon: Icons.school_outlined,
      status: entries.isEmpty
          ? _StatusChip.boost('+6%')
          : _StatusChip.complete(),
      trailing: TextButton(
        onPressed: () => manageEducations(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(entries.isEmpty ? 'Add' : 'Manage',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            Text('Add your educational qualifications.',
                style: AppTextStyles.bodySmall),
          for (final e in entries) ...[
            Row(
              children: [
                Expanded(
                  child: Text(e.degree,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(e.institute,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
            Text('${e.period}  |  ${e.type}',
                style: AppTextStyles.bodySmall),
            if (e.projects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Projects', style: AppTextStyles.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in e.projects)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.cardBorder),
                      ),
                      child: Text(p,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: context.textPrimary)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: context.divider),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// 8. IT skills
// =============================================================
class _ITSkillsCard extends StatelessWidget {
  final List<ITSkill> skills;
  const _ITSkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'IT skills',
      icon: Icons.code_rounded,
      status: skills.isEmpty
          ? _StatusChip.boost('+6%')
          : _StatusChip.complete(),
      trailing: TextButton(
        onPressed: () => manageItSkills(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(skills.isEmpty ? 'Add' : 'Manage',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: skills.isEmpty
          ? Text('Add the technologies you have hands-on experience with.',
              style: AppTextStyles.bodySmall)
          : Column(
              children: [
                for (var i = 0; i < skills.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.code_rounded,
                              size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      skills[i].skill,
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(
                                              fontWeight:
                                                  FontWeight.w800),
                                    ),
                                  ),
                                  if (skills[i].version != '-')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.surfaceVariant,
                                        borderRadius:
                                            BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        'v${skills[i].version}',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                                fontWeight:
                                                    FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 12,
                                      color: context.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('Last used ${skills[i].lastUsed}',
                                      style: AppTextStyles.bodySmall),
                                  const SizedBox(width: 12),
                                  Icon(Icons.bar_chart_rounded,
                                      size: 12,
                                      color: context.textSecondary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      skills[i].experience,
                                      style: AppTextStyles.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < skills.length - 1)
                    Container(
                        height: 1,
                        color: context.divider
                            .withValues(alpha: 0.5)),
                ],
              ],
            ),
    );
  }
}

// =============================================================
// 9. Projects
// =============================================================
class _ProjectsCard extends StatelessWidget {
  final List<ProjectEntry> projects;
  const _ProjectsCard({required this.projects});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Projects',
      icon: Icons.rocket_launch_outlined,
      status: projects.isEmpty
          ? _StatusChip.boost('+5%')
          : _StatusChip.complete(),
      trailing: TextButton(
        onPressed: () => manageProjects(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(projects.isEmpty ? 'Add' : 'Manage',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (projects.isEmpty)
            Text('Showcase the projects you have worked on.',
                style: AppTextStyles.bodySmall),
          for (final p in projects) ...[
            Text(p.title,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(p.company,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
            Text('${p.period}  |  ${p.type}',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            Text(
              p.description,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: context.divider),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// 10. Profile summary
// =============================================================
class _ProfileSummaryCard extends StatefulWidget {
  final String summary;
  const _ProfileSummaryCard({required this.summary});

  @override
  State<_ProfileSummaryCard> createState() => _ProfileSummaryCardState();
}

class _ProfileSummaryCardState extends State<_ProfileSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Profile summary',
      icon: Icons.notes_rounded,
      onEdit: () => editSummary(context),
      status: widget.summary.isEmpty
          ? _StatusChip.boost('+8%')
          : _StatusChip.complete(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.summary.isEmpty
                  ? 'Tap the pencil to add a profile summary.'
                  : widget.summary,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.55,
                color: widget.summary.isEmpty
                    ? context.textTertiary
                    : context.textPrimary,
              ),
            ),
          ),
          if (widget.summary.length > 120)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _expanded ? 'Read less' : 'Read more',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================
// 11. Accomplishments
// =============================================================
class _AccomplishmentsCard extends StatelessWidget {
  final List<Accomplishment> items;
  const _AccomplishmentsCard({required this.items});

  static const _types = [
    ('Online profile', Icons.link_rounded,
        'Add link to online professional profiles (e.g. LinkedIn, etc.)'),
    ('Work sample', Icons.code_rounded,
        'Link relevant work samples (e.g. Github, Behance)'),
    ('White paper / Research publication / Journal entry',
        Icons.menu_book_rounded, 'Add links to your online publications'),
    ('Presentation', Icons.slideshow_rounded,
        'Add links to your online presentations (e.g. Slide-share links etc.)'),
    ('Patent', Icons.workspace_premium_outlined,
        'Add details of patents you have filed'),
    ('Certification', Icons.verified_outlined,
        'Add details of certifications you have completed'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Accomplishments',
      icon: Icons.emoji_events_outlined,
      status: items.isEmpty
          ? _StatusChip.boost('+5%')
          : _StatusChip.complete(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Showcase your credentials by adding relevant certifications, work samples, online profiles, etc.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          for (var i = 0; i < _types.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(_types[i].$2,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_types[i].$1,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Builder(builder: (_) {
                          final added = items.where((e) =>
                              e.type == _types[i].$1);
                          if (added.isEmpty) {
                            return Text(_types[i].$3,
                                style: AppTextStyles.bodySmall);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final a in added)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.value,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => deleteAccomplishment(
                                          context,
                                          items.indexOf(a)),
                                      child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.urgent),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        addAccomplishment(context, _types[i].$1),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            if (i < _types.length - 1)
              Container(
                  height: 1,
                  color: context.divider.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// 12. Career profile
// =============================================================
class _CareerProfileCard extends StatelessWidget {
  final CareerProfile career;
  const _CareerProfileCard({required this.career});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Current Industry', career.currentIndustry),
      ('Department', career.department),
      ('Role category', career.roleCategory),
      ('Job role', career.jobRole),
      ('Desired job type', career.desiredJobType),
      ('Desired employment type', career.desiredEmploymentType),
      ('Preferred shift', career.preferredShift),
      ('Preferred work location', career.preferredLocation),
      ('Expected salary', career.expectedSalary),
    ];
    final filledCount = rows.where((r) => r.$2.isNotEmpty).length;
    return _SectionCard(
      title: 'Career profile',
      icon: Icons.trending_up_rounded,
      onEdit: () => editCareer(context),
      status: filledCount == rows.length
          ? _StatusChip.complete()
          : (filledCount == 0
              ? _StatusChip.boost('+10%')
              : _StatusChip(
                  label: '$filledCount / ${rows.length}',
                  icon: Icons.donut_small_rounded,
                  color: AppColors.info,
                )),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: context.divider.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isEmpty
                    ? context.textTertiary
                    : context.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 13. Personal details
// =============================================================
class _PersonalDetailsCard extends StatelessWidget {
  final PersonalDetails personal;
  const _PersonalDetailsCard({required this.personal});

  @override
  Widget build(BuildContext context) {
    final personalSummary = [
      personal.gender,
      personal.maritalStatus,
    ].where((s) => s.isNotEmpty).join(', ');
    final rows = <(String, String)>[
      ('Personal', personalSummary),
      ('Date of birth', personal.dob),
      ('Category', personal.category),
      ('Work permit', personal.workPermit),
      ('Address', personal.address),
    ];
    final filledCount = rows.where((r) => r.$2.isNotEmpty).length;
    return _SectionCard(
      title: 'Personal details',
      icon: Icons.person_outline_rounded,
      onEdit: () => editPersonal(context),
      status: filledCount == rows.length
          ? _StatusChip.complete()
          : (filledCount == 0
              ? _StatusChip.boost('+6%')
              : _StatusChip(
                  label: '$filledCount / ${rows.length}',
                  icon: Icons.donut_small_rounded,
                  color: AppColors.info,
                )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DetailRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: context.divider.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// 14. Languages
// =============================================================
class _LanguagesCard extends StatelessWidget {
  final List<LanguageProficiency> languages;
  const _LanguagesCard({required this.languages});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Languages',
      icon: Icons.translate_rounded,
      status: languages.isEmpty
          ? _StatusChip.boost('+4%')
          : _StatusChip.complete(),
      trailing: TextButton(
        onPressed: () => manageLanguages(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(languages.isEmpty ? 'Add' : 'Manage',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: languages.isEmpty
          ? Text('Add the languages you can read, write or speak.',
              style: AppTextStyles.bodySmall)
          : Column(
              children: [
                for (var i = 0; i < languages.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(languages[i].language,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w800)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                languages[i].proficiency,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _LangCheck(
                                label: 'Read',
                                enabled: languages[i].read),
                            const SizedBox(width: 16),
                            _LangCheck(
                                label: 'Write',
                                enabled: languages[i].write),
                            const SizedBox(width: 16),
                            _LangCheck(
                                label: 'Speak',
                                enabled: languages[i].speak),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (i < languages.length - 1)
                    Container(
                        height: 1,
                        color:
                            context.divider.withValues(alpha: 0.5)),
                ],
              ],
            ),
    );
  }
}

class _LangCheck extends StatelessWidget {
  final String label;
  final bool enabled;
  const _LangCheck({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          enabled
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: enabled ? AppColors.success : context.textTertiary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// =============================================================
// 15. Diversity & inclusion
// =============================================================
class _DiversityCard extends StatelessWidget {
  final String note;
  const _DiversityCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Diversity & inclusion',
      icon: Icons.diversity_3_rounded,
      onEdit: () => editDiversity(context),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.urgent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text('New',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.urgent,
              fontWeight: FontWeight.w800,
            )),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.isEmpty
                ? 'Share details to attract recruiters who value people from different backgrounds.'
                : note,
            style: AppTextStyles.bodySmall.copyWith(
              color: note.isEmpty
                  ? context.textSecondary
                  : context.textPrimary,
              fontWeight: note.isEmpty ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => editDiversity(context),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(note.isEmpty ? 'Share details' : 'Edit details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Bottom footer summary
// =============================================================
class _BottomFooter extends StatelessWidget {
  final int percent;
  const _BottomFooter({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'Profile completion: $percent%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your data is encrypted and never sold.',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

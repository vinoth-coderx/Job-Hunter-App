import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/applicant_model.dart';
import '../../providers/applicants_provider.dart';
import '../../providers/chat_provider.dart';
import '../interviews/schedule_interview_sheet.dart';
import '../widgets/app_avatar.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ApplicantDetailScreen extends StatefulWidget {
  final String applicationId;
  const ApplicantDetailScreen({super.key, required this.applicationId});

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen>
    with TapGuardMixin<ApplicantDetailScreen> {
  Applicant? _applicant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final fetched = await context
        .read<ApplicantsProvider>()
        .getDetail(widget.applicationId);
    if (!mounted) return;
    setState(() {
      _applicant = fetched;
      _loading = false;
      if (fetched == null) _error = 'Could not load applicant';
    });
  }

  Future<void> _setStatus(String status, {String? rejectionReason}) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<ApplicantsProvider>().updateStatus(
          applicationId: widget.applicationId,
          status: status,
          rejectionReason: rejectionReason,
        );
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        content: Text(context.read<ApplicantsProvider>().error ??
            'Could not update status'),
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text('Marked as $status')));
    await _load();
  }

  Future<void> _openChat(String otherUserId, Applicant a) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final conv = await context.read<ChatProvider>().openConversationWith(
            otherUserId: otherUserId,
            applicationId: a.applicationId,
            jobId: a.jobId,
          );
      if (!mounted) return;
      navigator.pushNamed(AppRoutes.chat, arguments: conv.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Could not open chat: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<String?> _askRejectionReason() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject applicant?'),
        content: CustomTextField(
          controller: c,
          maxLength: 1000,
          maxLines: 3,
          hint: 'Reason (sent to seeker)',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Applicant'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _applicant == null
              ? Center(
                  child: Text(_error ?? 'Not found',
                      style: AppTextStyles.bodyMedium))
              : _content(_applicant!),
    );
  }

  Widget _content(Applicant a) {
    final s = a.seeker;
    final df = DateFormat('d MMM yyyy');
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 200),
          children: [
            _header(a),
            const SizedBox(height: 12),
            if (a.matchScore != null) _matchCard(a),
            const SizedBox(height: 12),
            if (a.quickNote != null && a.quickNote!.isNotEmpty)
              _section('Quick note from applicant', a.quickNote!),
            if (s != null && s.skills.isNotEmpty) _skillsSection(s.skills),
            if (s != null && s.preferredLocations.isNotEmpty)
              _section(
                'Preferred locations',
                s.preferredLocations.join(', '),
              ),
            if (s != null && s.experienceYears > 0)
              _section('Experience', '${s.experienceYears} years'),
            if (a.screeningAnswers.isNotEmpty) _screeningSection(a),
            if (a.rejectionReason != null && a.rejectionReason!.isNotEmpty)
              _section('Rejection reason', a.rejectionReason!),
            const SizedBox(height: 12),
            _statusHistory(a, df),
            const SizedBox(height: 16),
            if (s?.resumeUrl != null && s!.resumeUrl!.isNotEmpty)
              SecondaryButton(
                label: 'Open resume',
                icon: Icons.description_outlined,
                onPressed: isBusy('resume')
                    ? null
                    : () => guard(
                          () async {
                            final uri = Uri.tryParse(s.resumeUrl!);
                            if (uri != null) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          key: 'resume',
                        ),
              ),
            if (s != null) ...[
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Message in app',
                icon: Icons.chat_bubble_outline,
                onPressed: isBusy('chat')
                    ? null
                    : () => guard(() => _openChat(s.id, a), key: 'chat'),
              ),
            ],
            // Hirer-only: schedule interview. Available once the applicant
            // is at least shortlisted; we don't enforce that here, the
            // backend already moves status → 'interview' on schedule.
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Schedule interview',
              icon: Icons.event_outlined,
              onPressed: isBusy('schedule')
                  ? null
                  : () => guard(
                        () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final iv = await ScheduleInterviewSheet.show(
                              context, a.applicationId);
                          if (!mounted) return;
                          if (iv != null) {
                            messenger.showSnackBar(const SnackBar(
                              content: Text('Interview invite sent'),
                              behavior: SnackBarBehavior.floating,
                            ));
                            await _load();
                          }
                        },
                        key: 'schedule',
                      ),
            ),
            if (s?.email != null) ...[
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Email applicant',
                icon: Icons.mail_outline,
                onPressed: isBusy('email')
                    ? null
                    : () => guard(
                          () async {
                            final uri = Uri(scheme: 'mailto', path: s!.email);
                            await launchUrl(uri);
                          },
                          key: 'email',
                        ),
              ),
            ],
            if (s?.phone != null && s!.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Call ${s.phone}',
                icon: Icons.phone,
                onPressed: isBusy('call')
                    ? null
                    : () => guard(
                          () async {
                            final uri = Uri(scheme: 'tel', path: s.phone);
                            await launchUrl(uri);
                          },
                          key: 'call',
                        ),
              ),
            ],
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _actionBar(a),
        ),
      ],
    );
  }

  Widget _header(Applicant a) {
    final s = a.seeker;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          AppAvatar(
            url: s?.avatar,
            name: s?.fullName,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.fullName ?? 'Unknown',
                  style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary),
                ),
                if (s?.headline != null && s!.headline!.isNotEmpty)
                  Text(s.headline!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary)),
                const SizedBox(height: 6),
                if (a.jobSnapshot != null)
                  Text('Applied for: ${a.jobSnapshot!.title}',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchCard(Applicant a) {
    Color color;
    final score = a.matchScore!;
    if (score >= 75) {
      color = AppColors.success;
    } else if (score >= 50) {
      color = AppColors.warning;
    } else {
      color = context.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: color),
          const SizedBox(width: 10),
          Text(
            'Match: ${score.round()}%',
            style: AppTextStyles.bodyMedium
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body, style: AppTextStyles.bodyMedium),
          ],
        ),
      );

  Widget _skillsSection(List<String> skills) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skills',
                style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills
                  .map((s) => Chip(
                        label: Text(s),
                        backgroundColor: context.chipBg,
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  Widget _screeningSection(Applicant a) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Screening answers',
                style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...a.screeningAnswers.map((ans) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ans.question,
                          style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary)),
                      Text(ans.answer,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textSecondary)),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _statusHistory(Applicant a, DateFormat df) {
    if (a.statusHistory.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status history',
              style: AppTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...a.statusHistory.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h.status,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textPrimary),
                    ),
                  ),
                  if (h.changedAt != null)
                    Text(
                      df.format(h.changedAt!.toLocal()),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textTertiary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(Applicant a) {
    final terminal = a.status == 'hired' ||
        a.status == 'rejected' ||
        a.status == 'withdrawn';
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: terminal
            ? Center(
                child: Text(
                  'Application is ${a.status} (terminal state)',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Reject',
                      icon: Icons.close,
                      onPressed: isBusy('status')
                          ? null
                          : () => guard(
                                () async {
                                  final reason = await _askRejectionReason();
                                  if (reason == null) return;
                                  await _setStatus('rejected',
                                      rejectionReason: reason);
                                },
                                key: 'status',
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: a.status == 'shortlisted'
                          ? 'Move to interview'
                          : 'Shortlist',
                      isLoading: isBusy('status'),
                      icon: Icons.check,
                      onPressed: isBusy('status')
                          ? null
                          : () => guard(
                                () async {
                                  if (a.status == 'shortlisted') {
                                    await _setStatus('interview');
                                  } else {
                                    await _setStatus('shortlisted');
                                  }
                                },
                                key: 'status',
                              ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

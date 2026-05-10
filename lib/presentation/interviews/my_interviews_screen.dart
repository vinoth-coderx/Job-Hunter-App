import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/interview_model.dart';
import '../../data/services/interview_service.dart';
import '../../providers/auth_provider.dart';

/// My Interviews — works for both seekers (default) and hirers via the
/// `hirerMode` flag (set when launched from the hirer dashboard).
class MyInterviewsScreen extends StatefulWidget {
  final bool hirerMode;
  const MyInterviewsScreen({super.key, this.hirerMode = false});

  @override
  State<MyInterviewsScreen> createState() => _MyInterviewsScreenState();
}

class _MyInterviewsScreenState extends State<MyInterviewsScreen> {
  Future<List<Interview>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = widget.hirerMode
          ? InterviewService.instance.listForHirer()
          : InterviewService.instance.listForSeeker();
    });
  }

  bool get _isHirer =>
      widget.hirerMode || context.read<AuthProvider>().isHirerMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Interviews'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Interview>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString(),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) return _empty();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _InterviewCard(
                interview: list[i],
                isHirer: _isHirer,
                onChanged: _refresh,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_outlined,
                  size: 56, color: context.textTertiary),
              const SizedBox(height: 12),
              Text('No interviews yet',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary)),
            ],
          ),
        ),
      );
}

class _InterviewCard extends StatelessWidget {
  final Interview interview;
  final bool isHirer;
  final VoidCallback onChanged;
  const _InterviewCard({
    required this.interview,
    required this.isHirer,
    required this.onChanged,
  });

  Color _statusColor(BuildContext context) {
    switch (interview.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
      case 'no_show':
        return AppColors.urgent;
      case 'rescheduled':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, d MMM · h:mm a');
    final now = DateTime.now();
    final isFuture = interview.scheduledAt.isAfter(now);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  interview.jobTitle ?? 'Interview',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  interview.status.toUpperCase(),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: _statusColor(context)),
                ),
              ),
            ],
          ),
          if (interview.companyName != null) ...[
            const SizedBox(height: 2),
            Text(interview.companyName!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: context.textTertiary),
              const SizedBox(width: 6),
              Text(df.format(interview.scheduledAt.toLocal()),
                  style: AppTextStyles.bodySmall),
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined,
                  size: 16, color: context.textTertiary),
              const SizedBox(width: 4),
              Text('${interview.durationMinutes} min',
                  style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(_typeIcon(), size: 16, color: context.textTertiary),
              const SizedBox(width: 6),
              Text('${interview.round.toUpperCase()} · ${interview.interviewType.replaceAll('_', ' ')}',
                  style: AppTextStyles.bodySmall),
            ],
          ),
          if (interview.notesToCandidate != null &&
              interview.notesToCandidate!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(interview.notesToCandidate!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (interview.meetingLink != null &&
                  interview.meetingLink!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(interview.meetingLink!);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.video_call, size: 18),
                    label: const Text('Join'),
                  ),
                ),
              if (!isHirer &&
                  isFuture &&
                  !interview.candidateConfirmed) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await InterviewService.instance.confirm(interview.id);
                        onChanged();
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm'),
                  ),
                ),
              ],
              if (isHirer && interview.status == 'scheduled') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await InterviewService.instance.cancel(interview.id);
                        onChanged();
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon() {
    switch (interview.interviewType) {
      case 'phone':
        return Icons.phone;
      case 'in_person':
        return Icons.location_on_outlined;
      default:
        return Icons.videocam_outlined;
    }
  }
}

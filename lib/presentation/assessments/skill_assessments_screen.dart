import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../../data/services/assessment_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'assessment_quiz_screen.dart';

class SkillAssessmentsScreen extends StatefulWidget {
  const SkillAssessmentsScreen({super.key});

  @override
  State<SkillAssessmentsScreen> createState() => _SkillAssessmentsScreenState();
}

class _SkillAssessmentsScreenState extends State<SkillAssessmentsScreen> {
  Future<List<AssessmentSummary>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = AssessmentService.instance.listMine();
    });
  }

  Future<void> _startNew() async {
    final result = await showModalBottomSheet<({String skill, String level})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StartAssessmentSheet(),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final session = await AssessmentService.instance.start(
        skill: result.skill,
        level: result.level,
      );
      if (!mounted) return;
      final outcome = await navigator.push<AssessmentResult>(
        MaterialPageRoute(
          builder: (_) => AssessmentQuizScreen(session: session),
        ),
      );
      if (outcome != null && mounted) _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not start: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Skill assessments'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<AssessmentSummary>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final list = snap.data ?? [];
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: list.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _Card(item: list[i]),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNew,
        icon: const Icon(Icons.quiz_outlined),
        label: const Text('Take an assessment'),
      ),
    );
  }

  Widget _empty() => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.workspace_premium_outlined,
              size: 56, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Take an assessment to earn a verified skill badge',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: context.textSecondary),
          ),
        ],
      );
}

class _Card extends StatelessWidget {
  final AssessmentSummary item;
  const _Card({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isPassed ? AppColors.success : AppColors.urgent;
    final df = DateFormat('d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 24,
            child: Icon(
              item.badgeAwarded ? Icons.workspace_premium : Icons.quiz_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.skill,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${item.level} · ${item.scorePercent}%${item.completedAt != null ? " · ${df.format(item.completedAt!.toLocal())}" : ""}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.isPassed ? 'PASSED' : 'TRY AGAIN',
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartAssessmentSheet extends StatefulWidget {
  const _StartAssessmentSheet();
  @override
  State<_StartAssessmentSheet> createState() => _StartAssessmentSheetState();
}

class _StartAssessmentSheetState extends State<_StartAssessmentSheet> {
  final _skill = TextEditingController();
  String _level = 'intermediate';

  @override
  void dispose() {
    _skill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const AppText.h3('New assessment'),
            const SizedBox(height: 4),
            const AppText.caption(
              '8 questions · 70% to pass · earn a verified badge',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _skill,
              hint: 'Skill (e.g., Flutter, SQL, React)',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: const [
                ('beginner', 'Beginner'),
                ('intermediate', 'Intermediate'),
                ('advanced', 'Advanced'),
              ].map((l) {
                return ChoiceChip(
                  label: Text(l.$2),
                  selected: _level == l.$1,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _level = l.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Start',
              icon: Icons.play_arrow,
              onPressed: () {
                final s = _skill.text.trim();
                if (s.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a skill')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  (skill: s, level: _level),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

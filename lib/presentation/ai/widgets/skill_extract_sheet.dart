import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/services/ai_service.dart';
import '../../../providers/ai_quota_provider.dart';
import '../../widgets/app_text.dart';
import '../../widgets/custom_button.dart';

/// Reusable bottom-sheet for the "Paste a JD → see required skills" flow.
/// Powered by /ai/skills/extract — weight 0 + 7d cache, so the same input
/// never charges quota twice.
///
/// Returns the list of skills the user explicitly chose to keep (we let
/// them deselect any that look noisy before propagating). Returns null
/// when cancelled.
///
/// Drop-in usage from any screen:
/// ```
/// final picked = await SkillExtractSheet.show(context);
/// if (picked != null) {
///   // do something with `picked` — adopt to profile, fill JD, etc.
/// }
/// ```
class SkillExtractSheet extends StatefulWidget {
  final String? initialText;
  final String title;
  final String hint;

  const SkillExtractSheet({
    super.key,
    this.initialText,
    this.title = 'Extract skills',
    this.hint =
        'Paste a job description, a role summary, or any text. We will pull out the relevant skills.',
  });

  static Future<List<String>?> show(
    BuildContext context, {
    String? initialText,
    String title = 'Extract skills',
    String? hint,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => SkillExtractSheet(
        initialText: initialText,
        title: title,
        hint: hint ??
            'Paste a job description, a role summary, or any text. '
                'We will pull out the relevant skills.',
      ),
    );
  }

  @override
  State<SkillExtractSheet> createState() => _SkillExtractSheetState();
}

class _SkillExtractSheetState extends State<SkillExtractSheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  String? _error;
  List<String> _skills = const [];
  bool _cached = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _ctrl.text.trim();
    if (text.length < 30) {
      AppSnackbar.error(context, 'Paste at least 30 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AiService.instance.extractSkills(text);
      if (!mounted) return;
      // Endpoint returns the latest quota in its envelope, but the
      // helper doesn't expose it — kick a fresh quota fetch so the
      // banner stays in sync without an extra round-trip surface.
      if (!res.cached) {
        unawaited(context.read<AiQuotaProvider>().refresh());
      }
      setState(() {
        _skills = res.skills;
        _cached = res.cached;
        _selected
          ..clear()
          ..addAll(res.skills);
        _loading = false;
      });
    } on AiQuotaExceededException catch (e) {
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(e.quota);
      setState(() {
        _loading = false;
        _error = e.message;
      });
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toggle(String skill) {
    setState(() {
      if (_selected.contains(skill)) {
        _selected.remove(skill);
      } else {
        _selected.add(skill);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: AppRadius.pillRadius,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: AppText.h4(widget.title)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AppText.caption(widget.hint),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _ctrl,
                      maxLines: 6,
                      minLines: 4,
                      maxLength: 18000,
                      decoration: InputDecoration(
                        hintText: 'Paste text here…',
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      AppText.caption(_error!, color: AppColors.urgent),
                    ],
                    if (_skills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          AppText.label(
                            'Found ${_skills.length} skills'
                            '${_cached ? " (cached)" : ""}',
                          ),
                          const Spacer(),
                          AppText.caption(
                            'Tap to deselect noise',
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _skills)
                            _SkillChip(
                              label: s,
                              selected: _selected.contains(s),
                              onTap: () => _toggle(s),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: _skills.isEmpty ? 'Extract skills' : 'Re-extract',
                      icon: _skills.isEmpty ? Icons.auto_awesome : Icons.refresh,
                      isLoading: _loading,
                      onPressed: _loading ? null : _run,
                    ),
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Use ${_selected.length}',
                      backgroundColor: AppColors.success,
                      onPressed: _selected.isEmpty
                          ? null
                          : () =>
                              Navigator.of(context).pop(_selected.toList()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SkillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.textTertiary;
    return InkWell(
      borderRadius: AppRadius.pillRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.12 : 0.04),
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: color.withValues(alpha: selected ? 0.40 : 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : Icons.add,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            AppText.chip(label, color: color),
          ],
        ),
      ),
    );
  }
}

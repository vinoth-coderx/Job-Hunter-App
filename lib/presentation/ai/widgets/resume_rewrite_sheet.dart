import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/resume_rewrite_model.dart';
import '../../../data/services/ai_service.dart';
import '../../../providers/ai_quota_provider.dart';
import '../../widgets/app_text.dart';
import '../../widgets/custom_button.dart';

/// Reusable bottom-sheet that runs the resume rewriter for ONE field and
/// returns the user's chosen variant (or null if dismissed).
///
/// Drop-in usage from any editor:
/// ```
/// final next = await ResumeRewriteSheet.show(
///   context,
///   kind: 'summary',
///   originalText: controller.text,
///   role: user.headline,
/// );
/// if (next != null) controller.text = next;
/// ```
///
/// Behaviour:
/// - Auto-runs the rewrite once on open.
/// - Renders the primary rewrite + alternates as selectable cards.
/// - Re-run button to regenerate (counts as a fresh quota slot).
/// - Pop returns the selected string; cancel returns null.
class ResumeRewriteSheet extends StatefulWidget {
  final String kind; // 'bullet' | 'summary' | 'achievement'
  final String originalText;
  final String? role;
  final String? tone;
  const ResumeRewriteSheet({
    super.key,
    required this.kind,
    required this.originalText,
    this.role,
    this.tone,
  });

  static Future<String?> show(
    BuildContext context, {
    required String kind,
    required String originalText,
    String? role,
    String? tone,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => ResumeRewriteSheet(
        kind: kind,
        originalText: originalText,
        role: role,
        tone: tone,
      ),
    );
  }

  @override
  State<ResumeRewriteSheet> createState() => _ResumeRewriteSheetState();
}

class _ResumeRewriteSheetState extends State<ResumeRewriteSheet> {
  ResumeRewriteResult? _result;
  bool _loading = false;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AiService.instance.resumeRewrite(
        kind: widget.kind,
        text: widget.originalText,
        role: widget.role,
        tone: widget.tone,
      );
      if (!mounted) return;
      context.read<AiQuotaProvider>().update(res.quota);
      setState(() {
        _result = res.data;
        _selectedIndex = 0;
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

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final options = _result?.allOptions ?? const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                AppText.h4('Rewrite ${_kindLabel(widget.kind)}'),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _run,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Re-run',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const AppText.caption('Tap a version below to use it.'),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppText.body(_error!,
                    color: AppColors.urgent, textAlign: TextAlign.center),
              )
            else if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: AppText.body('No rewrite generated.',
                    textAlign: TextAlign.center),
              )
            else
              for (int i = 0; i < options.length; i++)
                _OptionCard(
                  index: i,
                  text: options[i],
                  isPrimary: i == 0,
                  selected: _selectedIndex == i,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
            const SizedBox(height: 12),
            if (options.isNotEmpty)
              PrimaryButton(
                label: 'Use selected',
                onPressed: () => Navigator.of(context).pop(options[_selectedIndex]),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'bullet':
        return 'bullet';
      case 'summary':
        return 'summary';
      case 'achievement':
        return 'achievement';
      default:
        return kind;
    }
  }
}

class _OptionCard extends StatelessWidget {
  final int index;
  final String text;
  final bool isPrimary;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({
    required this.index,
    required this.text,
    required this.isPrimary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : context.surfaceVariant,
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: selected ? AppColors.primary : context.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  AppText.labelSmall(
                    isPrimary ? 'Primary' : 'Alternative $index',
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppText.body(text),
            ],
          ),
        ),
      ),
    );
  }
}

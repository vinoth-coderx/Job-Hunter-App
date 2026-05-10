import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../../data/services/assessment_service.dart';
import '../widgets/custom_button.dart';
import 'assessment_result_screen.dart';

class AssessmentQuizScreen extends StatefulWidget {
  final AssessmentSession session;
  const AssessmentQuizScreen({super.key, required this.session});

  @override
  State<AssessmentQuizScreen> createState() => _AssessmentQuizScreenState();
}

class _AssessmentQuizScreenState extends State<AssessmentQuizScreen> {
  int _index = 0;
  late final Map<int, int> _selections = {};
  bool _submitting = false;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  AssessmentQuestion get _q => widget.session.questions[_index];
  int get _total => widget.session.questions.length;
  bool get _hasSelected => _selections[_index] != null;
  bool get _isLast => _index == _total - 1;

  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave assessment?'),
        content: const Text(
            'Your answers will be lost and the assessment will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final answers = _selections.entries
          .map((e) => (questionIndex: e.key, selectedIndex: e.value))
          .toList();
      final timeTaken =
          DateTime.now().difference(_startedAt).inSeconds.clamp(1, 60 * 60 * 4);
      final result = await AssessmentService.instance.submit(
        id: widget.session.id,
        answers: answers,
        timeTakenSeconds: timeTaken,
      );
      if (!mounted) return;
      // Replace the quiz with the result so back doesn't return into the
      // post-submit quiz state.
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AssessmentResultScreen(result: result),
      ));
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          title: Text('${widget.session.skill} · ${_index + 1}/$_total'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _total,
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Text(_q.question,
                      style: AppTextStyles.h4
                          .copyWith(color: context.textPrimary)),
                  const SizedBox(height: 16),
                  ..._q.options.asMap().entries.map((e) {
                    final i = e.key;
                    final selected = _selections[_index] == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selections[_index] = i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.10)
                                : context.surface,
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : context.cardBorder,
                              width: selected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : context.textTertiary,
                                    width: 2,
                                  ),
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.value,
                                    style: AppTextStyles.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_index > 0)
                      Expanded(
                        child: SecondaryButton(
                          label: 'Back',
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _index -= 1),
                        ),
                      ),
                    if (_index > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: _isLast ? 'Submit' : 'Next',
                        icon: _isLast ? Icons.send : Icons.arrow_forward,
                        isLoading: _submitting,
                        onPressed: !_hasSelected || _submitting
                            ? null
                            : () {
                                if (_isLast) {
                                  _submit();
                                } else {
                                  setState(() => _index += 1);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/company_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class AddReviewSheet extends StatefulWidget {
  final String companyId;
  const AddReviewSheet({super.key, required this.companyId});

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();

  static Future<bool?> show(BuildContext context, String companyId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReviewSheet(companyId: companyId),
    );
  }
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  int _overall = 0;
  int? _culture;
  int? _wlb;
  int? _growth;
  int? _pay;
  int? _management;
  String _role = 'candidate';
  bool _anonymous = true;

  final _title = TextEditingController();
  final _pros = TextEditingController();
  final _cons = TextEditingController();
  final _advice = TextEditingController();
  bool _submitting = false;

  static const _roles = [
    ('candidate', 'Candidate'),
    ('employee', 'Current employee'),
    ('ex_employee', 'Ex-employee'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _pros.dispose();
    _cons.dispose();
    _advice.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_overall < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an overall rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await CompanyService.instance.submitReview(
        id: widget.companyId,
        overall: _overall,
        culture: _culture,
        workLifeBalance: _wlb,
        growth: _growth,
        pay: _pay,
        management: _management,
        reviewerRole: _role,
        isAnonymous: _anonymous,
        title: _title.text.trim(),
        pros: _pros.text.trim(),
        cons: _cons.text.trim(),
        adviceToManagement: _advice.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: ListView(
          controller: scroll,
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
            const AppText.h3('Write a review'),
            const SizedBox(height: 4),
            const AppText.caption(
              'Reviews stay anonymous by default. Only your role label is shown.',
            ),
            const SizedBox(height: 12),
            _label('Your relationship'),
            Wrap(
              spacing: 6,
              children: _roles
                  .map((r) => ChoiceChip(
                        label: Text(r.$2),
                        selected: _role == r.$1,
                        onSelected: (_) => setState(() => _role = r.$1),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.2),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _label('Overall *'),
            _starRow(_overall, (v) => setState(() => _overall = v)),
            const SizedBox(height: 12),
            _miniRating('Culture', _culture,
                (v) => setState(() => _culture = v)),
            _miniRating('Work-life balance', _wlb,
                (v) => setState(() => _wlb = v)),
            _miniRating('Growth', _growth,
                (v) => setState(() => _growth = v)),
            _miniRating('Pay', _pay, (v) => setState(() => _pay = v)),
            _miniRating('Management', _management,
                (v) => setState(() => _management = v)),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _title,
              hint: 'Title (optional)',
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _pros,
              hint: 'Pros',
              maxLines: 3,
              maxLength: 4000,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _cons,
              hint: 'Cons',
              maxLines: 3,
              maxLength: 4000,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _advice,
              hint: 'Advice to management (optional)',
              maxLines: 2,
              maxLength: 4000,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
              title: const Text('Submit anonymously'),
              subtitle: const Text('Your name and avatar will not be shown'),
              activeThumbColor: AppColors.primary,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Submit review',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Cancel',
              onPressed:
                  _submitting ? null : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AppText.caption(s),
      );

  Widget _miniRating(
    String label,
    int? current,
    ValueChanged<int?> onChange,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: AppTextStyles.bodySmall),
            ),
            Expanded(
              child: _starRow(current ?? 0, (v) {
                // tap a star at value V again to clear (set to null)
                if (current == v) {
                  onChange(null);
                } else {
                  onChange(v);
                }
              }),
            ),
          ],
        ),
      );

  Widget _starRow(int value, ValueChanged<int> onTap) => Row(
        children: List.generate(5, (i) {
          final star = i + 1;
          return IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            onPressed: () => onTap(star),
            icon: Icon(
              star <= value ? Icons.star : Icons.star_border,
              color: AppColors.warning,
            ),
          );
        }),
      );
}

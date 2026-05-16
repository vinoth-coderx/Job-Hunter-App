import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snackbar.dart';
import '../../data/models/hirer_job_model.dart';
import '../../data/services/hirer_job_service.dart';
import '../../providers/ai_quota_provider.dart';
import '../../providers/hirer_jobs_provider.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// 5-step wizard to post a native job.
/// Steps: Basics → Details → Compensation → Application → Preview.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  int _step = 0;
  bool _submitting = false;

  // Step 1 — Basics
  final _title = TextEditingController();
  final _department = TextEditingController();
  final _location = TextEditingController();
  String _jobType = 'full-time';
  String _remoteType = 'onsite';
  int _openings = 1;
  DateTime? _deadline;

  // Step 2 — Details
  final _description = TextEditingController();
  final _responsibilityInput = TextEditingController();
  final List<String> _responsibilities = [];
  final _skillInput = TextEditingController();
  final List<String> _skills = [];
  final _niceSkillInput = TextEditingController();
  final List<String> _niceSkills = [];
  final _education = TextEditingController();
  int? _expMin;
  int? _expMax;

  // Step 3 — Compensation
  bool _isSalaryVisible = true;
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _perkInput = TextEditingController();
  final List<String> _perks = [];

  // Step 4 — Application Settings
  String _applyType = 'easy_apply';
  final List<String> _requiredDocuments = ['resume'];
  final List<ScreeningQuestion> _screeningQuestions = [];

  static const _jobTypes = ['full-time', 'part-time', 'contract', 'internship', 'temporary'];
  static const _remoteTypes = ['onsite', 'remote', 'hybrid'];

  @override
  void dispose() {
    _title.dispose();
    _department.dispose();
    _location.dispose();
    _description.dispose();
    _responsibilityInput.dispose();
    _skillInput.dispose();
    _niceSkillInput.dispose();
    _education.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _perkInput.dispose();
    super.dispose();
  }

  bool _validateStep() {
    String? err;
    switch (_step) {
      case 0:
        if (_title.text.trim().length < 2) {
          err = 'Job title is required';
        } else if (_location.text.trim().length < 2) {
          err = 'Location is required';
        }
        break;
      case 1:
        if (_description.text.trim().length < 20) {
          err = 'Description must be at least 20 characters';
        } else if (_skills.isEmpty) {
          err = 'Add at least one required skill';
        } else if (_expMin != null && _expMax != null && _expMin! > _expMax!) {
          err = 'Min experience cannot be greater than max';
        }
        break;
      case 2:
        if (_isSalaryVisible) {
          final mn = int.tryParse(_salaryMin.text);
          final mx = int.tryParse(_salaryMax.text);
          if (mn != null && mx != null && mn > mx) {
            err = 'Salary min cannot exceed max';
          }
        }
        break;
      case 3:
        // Application settings — defaults are valid; no required field.
        break;
    }
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return false;
    }
    return true;
  }

  HirerJobInput _buildInput({required bool draft}) {
    return HirerJobInput(
      title: _title.text.trim(),
      department: _department.text.trim().isEmpty
          ? null
          : _department.text.trim(),
      description: _description.text.trim(),
      responsibilities: List.unmodifiable(_responsibilities),
      location: _location.text.trim(),
      jobType: _jobType,
      remoteType: _remoteType,
      openingsCount: _openings,
      experienceMinYears: _expMin,
      experienceMaxYears: _expMax,
      education: _education.text.trim().isEmpty ? null : _education.text.trim(),
      skills: List.unmodifiable(_skills),
      niceToHaveSkills: List.unmodifiable(_niceSkills),
      isSalaryVisible: _isSalaryVisible,
      salaryMin: int.tryParse(_salaryMin.text),
      salaryMax: int.tryParse(_salaryMax.text),
      currency: 'INR',
      perks: List.unmodifiable(_perks),
      applyType: _applyType,
      requiredDocuments: List.unmodifiable(_requiredDocuments),
      screeningQuestions: List.unmodifiable(_screeningQuestions),
      applicationDeadline: _deadline,
      saveAsDraft: draft,
    );
  }

  Future<void> _submit({required bool draft}) async {
    if (!_validateStep()) return;
    setState(() => _submitting = true);
    final created = await context
        .read<HirerJobsProvider>()
        .create(_buildInput(draft: draft));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<HirerJobsProvider>().error ??
            'Could not save job'),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(draft ? 'Saved as draft' : 'Job published'),
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.of(context).pop(created);
  }

  void _addToList(TextEditingController c, List<String> target,
      {int? max}) {
    final v = c.text.trim();
    if (v.isEmpty) return;
    if (max != null && target.length >= max) return;
    if (target.contains(v)) {
      c.clear();
      return;
    }
    setState(() {
      target.add(v);
      c.clear();
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _deadline ?? now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text('Post a job (${_step + 1}/5)'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _StepDots(active: _step, total: 5),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: switch (_step) {
                0 => _step1Basics(),
                1 => _step2Details(),
                2 => _step3Compensation(),
                3 => _step4Application(),
                _ => _step5Preview(),
              },
            ),
          ),
          _NavBar(
            step: _step,
            submitting: _submitting,
            onBack: _step == 0
                ? null
                : () => setState(() => _step--),
            onNext: _step < 4
                ? () {
                    if (_validateStep()) setState(() => _step++);
                  }
                : null,
            onPublish: _step == 4 ? () => _submit(draft: false) : null,
            onDraft: _step == 4 ? () => _submit(draft: true) : null,
          ),
        ],
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────
  Widget _step1Basics() => ListView(
        children: [
          _h('Basics'),
          _field(_title, 'Job title *', maxLength: 200),
          _field(_department, 'Department (optional)', maxLength: 100),
          _field(_location, 'Location * (e.g., Chennai, Tamil Nadu)',
              maxLength: 200),
          _dropdown('Job type', _jobType, _jobTypes,
              (v) => setState(() => _jobType = v)),
          _dropdown('Work mode', _remoteType, _remoteTypes,
              (v) => setState(() => _remoteType = v)),
          _intStepper(
            label: 'Openings',
            value: _openings,
            onChange: (v) => setState(() => _openings = v),
            min: 1,
            max: 1000,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Application deadline'),
            subtitle: Text(_deadline == null
                ? 'No deadline'
                : _deadline!.toLocal().toIso8601String().split('T').first),
            trailing: TextButton(
              onPressed: _pickDeadline,
              child: const Text('Pick date'),
            ),
          ),
        ],
      );

  // ── Step 2 ────────────────────────────────────────────────────────
  Widget _step2Details() => ListView(
        children: [
          _h('Details'),
          _field(_description, 'Job description (min 20 chars) *',
              maxLines: 8, maxLength: 20000),
          if (_description.text.trim().length >= 50)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _polishJd,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Polish with AI'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          _chipInput(
            controller: _responsibilityInput,
            placeholder: 'Add a responsibility',
            chips: _responsibilities,
            onAdd: () =>
                _addToList(_responsibilityInput, _responsibilities, max: 20),
            onRemove: (s) => setState(() => _responsibilities.remove(s)),
          ),
          const SizedBox(height: 12),
          _chipInput(
            controller: _skillInput,
            placeholder: 'Required skills * (e.g., Flutter, Node.js)',
            chips: _skills,
            onAdd: () => _addToList(_skillInput, _skills, max: 40),
            onRemove: (s) => setState(() => _skills.remove(s)),
          ),
          const SizedBox(height: 12),
          _chipInput(
            controller: _niceSkillInput,
            placeholder: 'Nice-to-have skills',
            chips: _niceSkills,
            onAdd: () => _addToList(_niceSkillInput, _niceSkills, max: 40),
            onRemove: (s) => setState(() => _niceSkills.remove(s)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _intStepper(
                  label: 'Min exp (yrs)',
                  value: _expMin ?? 0,
                  onChange: (v) => setState(() => _expMin = v),
                  min: 0,
                  max: 60,
                  allowNull: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _intStepper(
                  label: 'Max exp (yrs)',
                  value: _expMax ?? 0,
                  onChange: (v) => setState(() => _expMax = v),
                  min: 0,
                  max: 60,
                  allowNull: true,
                ),
              ),
            ],
          ),
          _field(_education, 'Education (optional)'),
        ],
      );

  // ── Step 3 ────────────────────────────────────────────────────────
  Widget _step3Compensation() => ListView(
        children: [
          _h('Compensation'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show salary on listing'),
            value: _isSalaryVisible,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _isSalaryVisible = v),
          ),
          if (_isSalaryVisible) ...[
            Row(
              children: [
                Expanded(
                  child: _field(_salaryMin, 'Min salary (₹)',
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_salaryMax, 'Max salary (₹)',
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _chipInput(
            controller: _perkInput,
            placeholder: 'Add a perk (e.g., Health Insurance)',
            chips: _perks,
            onAdd: () => _addToList(_perkInput, _perks, max: 30),
            onRemove: (s) => setState(() => _perks.remove(s)),
          ),
        ],
      );

  // ── Step 4 ────────────────────────────────────────────────────────
  Widget _step4Application() => ListView(
        children: [
          _h('Application settings'),
          _dropdown(
            'Apply type',
            _applyType,
            const ['easy_apply', 'custom_form'],
            (v) => setState(() => _applyType = v),
            labels: const {
              'easy_apply': 'Easy apply (one-click)',
              'custom_form': 'Custom form',
            },
          ),
          const SizedBox(height: 8),
          const AppText.body('Required documents', fontWeight: FontWeight.w600),
          ...['resume', 'cover_letter', 'portfolio'].map(
            (doc) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_docLabel(doc)),
              value: _requiredDocuments.contains(doc),
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (!_requiredDocuments.contains(doc)) {
                      _requiredDocuments.add(doc);
                    }
                  } else {
                    _requiredDocuments.remove(doc);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: AppText.body('Screening questions (max 5)',
                    fontWeight: FontWeight.w600),
              ),
              if (_screeningQuestions.length < 5) ...[
                TextButton.icon(
                  onPressed: _generateScreeningQuestions,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI suggest'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addScreening,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ],
          ),
          ..._screeningQuestions.asMap().entries.map(
                (e) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(e.value.question),
                    subtitle: Text(
                        '${e.value.type}${e.value.isRequired ? " · required" : ""}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(
                          () => _screeningQuestions.removeAt(e.key)),
                    ),
                  ),
                ),
              ),
        ],
      );

  // ── Step 5 ────────────────────────────────────────────────────────
  Widget _step5Preview() => ListView(
        children: [
          _h('Preview'),
          _previewCard('Title', _title.text),
          if (_department.text.trim().isNotEmpty)
            _previewCard('Department', _department.text),
          _previewCard('Location', _location.text),
          _previewCard('Type', '$_jobType · $_remoteType'),
          _previewCard('Openings', _openings.toString()),
          if (_deadline != null)
            _previewCard('Deadline',
                _deadline!.toLocal().toIso8601String().split('T').first),
          _previewCard('Description', _description.text),
          if (_responsibilities.isNotEmpty)
            _previewCard('Responsibilities', _responsibilities.join('\n• ')),
          _previewCard('Skills', _skills.join(', ')),
          if (_niceSkills.isNotEmpty)
            _previewCard('Nice to have', _niceSkills.join(', ')),
          if (_expMin != null || _expMax != null)
            _previewCard('Experience',
                '${_expMin ?? 0} – ${_expMax ?? "any"} years'),
          if (_education.text.trim().isNotEmpty)
            _previewCard('Education', _education.text),
          if (_isSalaryVisible &&
              (_salaryMin.text.isNotEmpty || _salaryMax.text.isNotEmpty))
            _previewCard('Salary',
                '₹${_salaryMin.text.isEmpty ? "?" : _salaryMin.text} – ₹${_salaryMax.text.isEmpty ? "?" : _salaryMax.text}'),
          if (_perks.isNotEmpty) _previewCard('Perks', _perks.join(', ')),
          _previewCard('Apply type', _applyType),
          _previewCard('Required documents', _requiredDocuments.join(', ')),
          if (_screeningQuestions.isNotEmpty)
            _previewCard('Screening questions',
                _screeningQuestions.map((q) => '• ${q.question}').join('\n')),
        ],
      );

  // ── Reusable bits ─────────────────────────────────────────────────
  String _docLabel(String d) => switch (d) {
        'resume' => 'Resume',
        'cover_letter' => 'Cover letter',
        'portfolio' => 'Portfolio',
        _ => d,
      };

  Widget _h(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: AppText.h3(s),
      );

  Widget _previewCard(String label, String value) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: AppText.caption(label),
          subtitle: Text(value),
        ),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CustomTextField(
          controller: c,
          hint: label,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType ?? TextInputType.text,
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChange, {
    Map<String, String>? labels,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: _decoration(label),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(labels?[o] ?? _humanise(o)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChange(v);
          },
        ),
      );

  String _humanise(String s) => s
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  Widget _intStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChange,
    required int min,
    required int max,
    bool allowNull = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InputDecorator(
          decoration: _decoration(label),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: value > min ? () => onChange(value - 1) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    allowNull && value == 0 ? '—' : value.toString(),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: value < max ? () => onChange(value + 1) : null,
              ),
            ],
          ),
        ),
      );

  Widget _chipInput({
    required TextEditingController controller,
    required String placeholder,
    required List<String> chips,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: controller,
                  hint: placeholder,
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
              ),
            ],
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((c) => Chip(
                          label: Text(c),
                          onDeleted: () => onRemove(c),
                        ))
                    .toList(),
              ),
            ),
        ],
      );

  Future<void> _addScreening() async {
    final q = await showDialog<ScreeningQuestion>(
      context: context,
      builder: (_) => const _ScreeningQuestionDialog(),
    );
    if (q != null) setState(() => _screeningQuestions.add(q));
  }

  /// AI polish for the current JD draft. Opens a side-by-side preview
  /// sheet showing the rewritten body + the changes applied; the hirer
  /// chooses to accept or reject. We never auto-replace because the
  /// rewrite changes how the user's draft reads — silent overwrites
  /// would be jarring.
  Future<void> _polishJd() async {
    final title = _title.text.trim();
    final original = _description.text.trim();
    if (title.length < 3 || original.length < 50) {
      AppSnackbar.error(
        context,
        'Add a title and at least 50 characters of description first.',
      );
      return;
    }
    try {
      final res = await HirerJobService.instance.polishJd(
        title: title,
        description: original,
      );
      if (!mounted) return;
      if (!res.cached) {
        // ignore: discarded_futures
        context.read<AiQuotaProvider>().refresh();
      }
      if (!res.usedAi || res.polished.trim() == original) {
        AppSnackbar.success(
          context,
          'Your description already reads well — nothing to change.',
        );
        return;
      }
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _PolishedJdSheet(
          original: original,
          polished: res.polished,
          changes: res.changes,
        ),
      );
      if (accepted == true && mounted) {
        setState(() => _description.text = res.polished);
        AppSnackbar.success(context, 'Description replaced with the polished version.');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Polish failed: $e');
    }
  }

  /// Pull AI-suggested screening questions for the current draft. The
  /// hirer reviews + selects which to keep — we don't auto-fill so a
  /// rushed click never silently bloats the listing with 5 questions.
  /// Cap stays at 5 total: existing custom rows count toward the limit.
  Future<void> _generateScreeningQuestions() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.length < 3 || description.length < 20) {
      AppSnackbar.error(
        context,
        'Add a title and at least a short description first.',
      );
      return;
    }
    final remaining = 5 - _screeningQuestions.length;
    if (remaining <= 0) return;

    setState(() {});
    try {
      final res = await HirerJobService.instance.generateScreeningQuestions(
        title: title,
        description: description,
        skills: _skills.toList(),
      );
      if (!mounted) return;
      // Keep the quota banner in sync — the helper doesn't expose the
      // post-call snapshot directly, so kick a refresh on cache miss.
      if (!res.cached) {
        // ignore: discarded_futures
        context.read<AiQuotaProvider>().refresh();
      }
      if (res.questions.isEmpty) {
        AppSnackbar.error(context, 'No suggestions generated.');
        return;
      }
      final picked = await showModalBottomSheet<List<ScreeningQuestion>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _GeneratedScreeningSheet(
          candidates: res.questions
              .map((m) => ScreeningQuestion.fromJson(m))
              .toList(),
          maxPick: remaining,
        ),
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      setState(() => _screeningQuestions.addAll(picked.take(remaining)));
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not generate questions: $e');
      }
    }
  }
}

/// Bottom sheet that lets the hirer review AI-suggested screening
/// questions and pick which ones to add to the draft. Selection is
/// capped by [maxPick] so the parent never overflows the 5-question
/// hard cap on the listing.
class _GeneratedScreeningSheet extends StatefulWidget {
  final List<ScreeningQuestion> candidates;
  final int maxPick;
  const _GeneratedScreeningSheet({
    required this.candidates,
    required this.maxPick,
  });

  @override
  State<_GeneratedScreeningSheet> createState() =>
      _GeneratedScreeningSheetState();
}

class _GeneratedScreeningSheetState extends State<_GeneratedScreeningSheet> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <int>{
      for (var i = 0;
          i < widget.candidates.length && i < widget.maxPick;
          i++)
        i,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.cardBorder,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          AppText.h4('AI suggested questions'),
          const SizedBox(height: 4),
          AppText.caption(
            'Tap to keep / drop. You can edit each one after adding.',
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < widget.candidates.length; i++)
            _buildCandidate(context, i, widget.candidates[i]),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _selected.isEmpty
                ? 'Pick at least one'
                : 'Add ${_selected.length} question${_selected.length == 1 ? '' : 's'}',
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(
                      _selected
                          .toList()
                          .map((i) => widget.candidates[i])
                          .toList(),
                    ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidate(BuildContext context, int i, ScreeningQuestion q) {
    final selected = _selected.contains(i);
    final canAddMore = _selected.length < widget.maxPick;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (selected) {
              _selected.remove(i);
            } else if (canAddMore) {
              _selected.add(i);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : context.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.40)
                  : context.cardBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: selected ? AppColors.primary : context.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.body(q.question, fontWeight: FontWeight.w600),
                    const SizedBox(height: 4),
                    AppText.caption(
                      [
                        q.type,
                        if (q.options.isNotEmpty)
                          '${q.options.length} options',
                        if (q.isRequired) 'required',
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int active;
  final int total;
  const _StepDots({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isOn = i <= active;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOn
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int step;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onPublish;
  final VoidCallback? onDraft;
  const _NavBar({
    required this.step,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.onPublish,
    required this.onDraft,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            if (onBack != null)
              Expanded(
                child: SecondaryButton(label: 'Back', onPressed: onBack),
              ),
            if (onBack != null) const SizedBox(width: 12),
            if (onNext != null)
              Expanded(
                flex: 2,
                child: PrimaryButton(label: 'Next', onPressed: onNext),
              ),
            if (onPublish != null) ...[
              Expanded(
                child: SecondaryButton(
                  label: 'Save draft',
                  onPressed: submitting ? null : onDraft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Publish',
                  isLoading: submitting,
                  onPressed: submitting ? null : onPublish,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScreeningQuestionDialog extends StatefulWidget {
  const _ScreeningQuestionDialog();

  @override
  State<_ScreeningQuestionDialog> createState() =>
      _ScreeningQuestionDialogState();
}

class _ScreeningQuestionDialogState extends State<_ScreeningQuestionDialog> {
  final _question = TextEditingController();
  String _type = 'text';
  bool _isRequired = false;
  final _optionInput = TextEditingController();
  final List<String> _options = [];

  @override
  void dispose() {
    _question.dispose();
    _optionInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add screening question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _question,
              hint: 'Question text',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Short text')),
                DropdownMenuItem(value: 'mcq', child: Text('Multiple choice')),
                DropdownMenuItem(value: 'yes_no', child: Text('Yes / No')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            if (_type == 'mcq') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _optionInput,
                      hint: 'Option',
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final v = _optionInput.text.trim();
                      if (v.isNotEmpty && _options.length < 10) {
                        setState(() {
                          _options.add(v);
                          _optionInput.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_options.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _options
                      .map((o) => Chip(
                            label: Text(o),
                            onDeleted: () =>
                                setState(() => _options.remove(o)),
                          ))
                      .toList(),
                ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _isRequired,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isRequired = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_question.text.trim().length < 3) return;
            if (_type == 'mcq' && _options.length < 2) return;
            Navigator.pop(
              context,
              ScreeningQuestion(
                question: _question.text.trim(),
                type: _type,
                options: _type == 'mcq' ? List.unmodifiable(_options) : const [],
                isRequired: _isRequired,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Side-by-side preview of the original JD vs the AI-polished version.
/// Hirer accepts (replaces the field) or dismisses (keeps the original).
/// Lists the changes the model applied so the hirer knows WHAT moved
/// before they accept.
class _PolishedJdSheet extends StatelessWidget {
  final String original;
  final String polished;
  final List<String> changes;
  const _PolishedJdSheet({
    required this.original,
    required this.polished,
    required this.changes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.cardBorder,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                AppText.h4('Polished description'),
              ],
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppText.label('Changes applied'),
              const SizedBox(height: 4),
              for (final c in changes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppText.body(c),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText.label('Polished version'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.20),
                        ),
                      ),
                      child: SelectableText(
                        polished,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppText.label('Original (will be replaced)'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SelectableText(
                        original,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Replace with polished',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep original'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

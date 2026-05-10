import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/interview_model.dart';
import '../../data/services/interview_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';

/// Hirer-side interview scheduler. Returns the created Interview on
/// success, null on cancel.
class ScheduleInterviewSheet extends StatefulWidget {
  final String applicationId;
  const ScheduleInterviewSheet({super.key, required this.applicationId});

  @override
  State<ScheduleInterviewSheet> createState() =>
      _ScheduleInterviewSheetState();

  static Future<Interview?> show(
    BuildContext context,
    String applicationId,
  ) {
    return showModalBottomSheet<Interview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleInterviewSheet(applicationId: applicationId),
    );
  }
}

class _ScheduleInterviewSheetState extends State<ScheduleInterviewSheet> {
  String _round = 'hr';
  String _type = 'video';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);
  int _duration = 45;
  final _meetingLink = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  static const _rounds = [
    ('hr', 'HR'),
    ('technical', 'Technical'),
    ('managerial', 'Managerial'),
    ('final', 'Final'),
    ('assessment', 'Assessment'),
  ];
  static const _types = [
    ('video', 'Video'),
    ('phone', 'Phone'),
    ('in_person', 'In-person'),
  ];

  @override
  void dispose() {
    _meetingLink.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _scheduled => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_scheduled.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a future date and time')),
      );
      return;
    }
    if (_type == 'video' && _meetingLink.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a meeting link for video interviews')),
      );
      return;
    }
    if (_type == 'in_person' && _location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a location for in-person interviews')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final iv = await InterviewService.instance.schedule(
        applicationId: widget.applicationId,
        round: _round,
        interviewType: _type,
        scheduledAt: _scheduled,
        durationMinutes: _duration,
        meetingLink: _meetingLink.text.trim(),
        meetingPlatform: _type == 'video' ? 'Custom' : null,
        location: _location.text.trim(),
        notesToCandidate: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(iv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not schedule: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
            const SizedBox(height: 16),
            const AppText.h3('Schedule interview'),
            const SizedBox(height: 16),
            _label('Round'),
            Wrap(
              spacing: 6,
              children: _rounds
                  .map((r) => ChoiceChip(
                        label: Text(r.$2),
                        selected: _round == r.$1,
                        onSelected: (_) => setState(() => _round = r.$1),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _label('Type'),
            Wrap(
              spacing: 6,
              children: _types
                  .map((t) => ChoiceChip(
                        label: Text(t.$2),
                        selected: _type == t.$1,
                        onSelected: (_) => setState(() => _type = t.$1),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    'Date',
                    DateFormat('EEE, d MMM').format(_date),
                    Icons.calendar_today_outlined,
                    _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pickerTile(
                    'Time',
                    _time.format(context),
                    Icons.access_time,
                    _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _label('Duration'),
            Wrap(
              spacing: 6,
              children: const [30, 45, 60, 90].map((d) {
                return ChoiceChip(
                  label: Text('$d min'),
                  selected: _duration == d,
                  onSelected: (_) => setState(() => _duration = d),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
            if (_type == 'video') ...[
              const SizedBox(height: 12),
              _label('Meeting link *'),
              TextField(
                controller: _meetingLink,
                keyboardType: TextInputType.url,
                decoration: _decoration('https://meet.google.com/xyz-abcd'),
              ),
            ],
            if (_type == 'in_person') ...[
              const SizedBox(height: 12),
              _label('Location *'),
              TextField(
                controller: _location,
                decoration:
                    _decoration('Office address, floor, room number'),
              ),
            ],
            const SizedBox(height: 12),
            _label('Notes to candidate (optional)'),
            TextField(
              controller: _notes,
              maxLength: 2000,
              maxLines: 3,
              decoration: _decoration(
                  'What to bring, who they\'ll meet, etc.'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Send invite',
              icon: Icons.send,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Cancel',
              onPressed:
                  _submitting ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: AppText.caption(s),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _pickerTile(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.caption(label, color: context.textTertiary),
                    AppText.body(value, fontWeight: FontWeight.w600),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/resume_profile_model.dart';
import '../../../data/services/user_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/resume_profile_provider.dart';
import '../edit_field_screen.dart';

// =============================================================
// Common helpers
// =============================================================

void _toast(BuildContext context, String msg, {Color? bg}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

InputDecoration _decoration(BuildContext context, String label,
    {String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

/// Compact anchored dropdown that opens as a small popup directly under the
/// field instead of a fullscreen-style menu. Use this in place of raw
/// `DropdownButtonFormField` so every dropdown looks and behaves the same.
Widget _appDropdown<T>(
  BuildContext context, {
  required T? value,
  required String hint,
  required List<T> items,
  required String Function(T) labelOf,
  required ValueChanged<T?> onChanged,
  String? Function(T?)? validator,
}) {
  return DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    menuMaxHeight: 320,
    borderRadius: BorderRadius.circular(12),
    icon: Icon(
      Icons.keyboard_arrow_down_rounded,
      color: context.textSecondary,
      size: 22,
    ),
    style: AppTextStyles.bodyMedium
        .copyWith(color: context.textPrimary, fontWeight: FontWeight.w500),
    decoration: _decoration(context, '', hint: hint),
    items: [
      for (final v in items)
        DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
    ],
    onChanged: onChanged,
    validator: validator,
  );
}

Future<T?> _showSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: AppTextStyles.h3)),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PrimaryScrollController(
                controller: scrollController,
                child: builder(sheetCtx),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  const _SaveBar({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text('Save', style: AppTextStyles.button),
        ),
      ),
    );
  }
}

class _CancelSaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback onCancel;
  const _CancelSaveBar({required this.onSave, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Text('Save', style: AppTextStyles.button),
            ),
          ),
        ],
      ),
    );
  }
}

// Square checkbox + label, used for multi-select option rows.
class _CheckOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CheckOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? context.textPrimary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? context.textPrimary
                      : context.textTertiary,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Picks a value from a predefined list. Preserves any existing
// custom value by injecting it into the items list.
List<String> _withCustom(List<String> base, String? value) {
  if (value == null || value.trim().isEmpty) return base;
  final v = value.trim();
  if (base.any((o) => o.toLowerCase() == v.toLowerCase())) return base;
  return [v, ...base];
}

Set<String> _csvToSet(String csv, List<String> opts) {
  final parts = csv
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  return opts.where((o) => parts.contains(o.toLowerCase())).toSet();
}

({String currency, String amount}) _splitAmount(String value) {
  final v = value.trim();
  if (v.isEmpty) return (currency: '₹', amount: '');
  for (final c in const ['₹', '\$', '€', '£']) {
    if (v.startsWith(c)) {
      return (currency: c, amount: v.substring(c.length).trim());
    }
  }
  if (v.toUpperCase().startsWith('AED')) {
    return (currency: 'AED', amount: v.substring(3).trim());
  }
  return (currency: '₹', amount: v);
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

List<int> _yearList({int back = 50, bool includeNext = false}) {
  final now = DateTime.now().year;
  final end = includeNext ? now + 1 : now;
  return [for (var y = end; y >= end - back; y--) y];
}

({String? fromMonth, int? fromYear, String? toMonth, int? toYear, bool current})
    _parsePeriod(String value) {
  final s = value.trim();
  if (s.isEmpty) {
    return (
      fromMonth: null,
      fromYear: null,
      toMonth: null,
      toYear: null,
      current: false
    );
  }
  final parts = s.split(RegExp(r'\s*[–\-—to]+\s*', caseSensitive: false));
  String? fm;
  int? fy;
  String? tm;
  int? ty;
  bool current = false;

  ({String? mo, int? yr}) parseSeg(String seg) {
    final bits = seg.trim().split(RegExp(r'\s+'));
    if (bits.length >= 2) {
      final mo = _months.firstWhere(
        (m) => m.toLowerCase() == bits[0].toLowerCase(),
        orElse: () => '',
      );
      final yr = int.tryParse(bits[1]);
      return (mo: mo.isEmpty ? null : mo, yr: yr);
    }
    if (bits.length == 1) {
      final yr = int.tryParse(bits[0]);
      if (yr != null) return (mo: null, yr: yr);
    }
    return (mo: null, yr: null);
  }

  if (parts.isNotEmpty) {
    final p = parseSeg(parts[0]);
    fm = p.mo;
    fy = p.yr;
  }
  if (parts.length >= 2) {
    final toStr = parts[1].trim().toLowerCase();
    if (toStr == 'present' || toStr == 'now' || toStr == 'current') {
      current = true;
    } else {
      final p = parseSeg(parts[1]);
      tm = p.mo;
      ty = p.yr;
    }
  }
  return (
    fromMonth: fm,
    fromYear: fy,
    toMonth: tm,
    toYear: ty,
    current: current
  );
}

String _formatPeriod({
  String? fromMonth,
  int? fromYear,
  String? toMonth,
  int? toYear,
  bool current = false,
}) {
  String fmt(String? m, int? y) {
    if (m != null && y != null) return '$m $y';
    if (y != null) return '$y';
    return '';
  }

  final from = fmt(fromMonth, fromYear);
  if (current) return from.isEmpty ? 'Present' : '$from – Present';
  final to = fmt(toMonth, toYear);
  if (from.isEmpty && to.isEmpty) return '';
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  return '$from – $to';
}

({int? fromYear, int? toYear, bool pursuing}) _parseYearRange(String value) {
  final s = value.trim();
  if (s.isEmpty) {
    return (fromYear: null, toYear: null, pursuing: false);
  }
  final parts = s.split(RegExp(r'\s*[–\-—to]+\s*', caseSensitive: false));
  int? fy;
  int? ty;
  bool pursuing = false;
  if (parts.isNotEmpty) {
    fy = int.tryParse(RegExp(r'\d{4}').firstMatch(parts[0])?.group(0) ?? '');
  }
  if (parts.length >= 2) {
    final t = parts[1].trim().toLowerCase();
    if (t == 'pursuing' || t == 'present' || t == 'ongoing' || t == 'current') {
      pursuing = true;
    } else {
      ty = int.tryParse(RegExp(r'\d{4}').firstMatch(t)?.group(0) ?? '');
    }
  }
  return (fromYear: fy, toYear: ty, pursuing: pursuing);
}

String _formatYearRange(int? fromYear, int? toYear, bool pursuing) {
  if (fromYear == null && toYear == null && !pursuing) return '';
  final from = fromYear?.toString() ?? '';
  if (pursuing) return from.isEmpty ? 'Pursuing' : '$from-Pursuing';
  final to = toYear?.toString() ?? '';
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  return '$from-$to';
}

class _MonthYearRow extends StatelessWidget {
  final String label;
  final String? month;
  final int? year;
  final bool enabled;
  final ValueChanged<String?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;
  const _MonthYearRow({
    required this.label,
    required this.month,
    required this.year,
    required this.onMonthChanged,
    required this.onYearChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final years = _yearList(back: 50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            )),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: DropdownButtonFormField<String>(
                    initialValue: month,
                    isExpanded: true,
                    decoration: _decoration(context, '', hint: 'Month'),
                    items: [
                      for (final m in _months)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: onMonthChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    isExpanded: true,
                    decoration: _decoration(context, '', hint: 'Year'),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: onYearChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================
// 1. Basic details (full form: name, work status, exp, salary,
//    location, mobile, telephone, email, availability)
// =============================================================
const List<String> _countries = [
  'United States',
  'United Kingdom',
  'United Arab Emirates',
  'Canada',
  'Australia',
  'Germany',
  'Singapore',
  'Saudi Arabia',
  'Qatar',
  'Malaysia',
  'New Zealand',
  'Ireland',
  'Netherlands',
  'France',
  'Japan',
  'Other',
];

const List<String> _availabilityOptions = [
  '15 Days or less',
  '1 Month',
  '2 Months',
  '3 Months',
  'More than 3 Months',
];

Future<void> editHeader(BuildContext context) async {
  final p = context.read<ResumeProfileProvider>().profile;
  final auth = context.read<AuthProvider>();
  final user = auth.user;

  final name = TextEditingController(
    text: user?.name.isNotEmpty == true ? user!.name : 'VINOTH R',
  );

  String workStatus = p.workStatus.isEmpty ? 'Experienced' : p.workStatus;
  int? years = p.expYears > 0 ? p.expYears : (workStatus == 'Experienced' ? 2 : null);
  int? months = p.expMonths > 0 ? p.expMonths : null;

  String currency = p.currency.isEmpty ? '₹' : p.currency;
  final salaryAmount = TextEditingController(
    text: p.salaryAmount.isNotEmpty ? p.salaryAmount : '6,00,000',
  );
  String breakdown =
      p.salaryBreakdown.isEmpty ? 'Fixed' : p.salaryBreakdown;

  String locType = p.locationType.isEmpty ? 'India' : p.locationType;
  final city = TextEditingController(text: p.locationCity);
  String? country = p.locationCountry.isEmpty ? null : p.locationCountry;

  final telCountry = TextEditingController(text: p.telephoneCountry);
  final telArea = TextEditingController(text: p.telephoneArea);
  final telPhone = TextEditingController(text: p.telephonePhone);

  String availability =
      p.availability.isEmpty ? '15 Days or less' : p.availability;
  if (!_availabilityOptions.contains(availability)) {
    availability = '15 Days or less';
  }

  final formKey = GlobalKey<FormState>();
  final eduDisplay = p.educations.isNotEmpty
      ? '${p.educations.first.degree} at ${p.educations.first.institute}'
      : '';

  final phoneText =
      user?.phone.isNotEmpty == true ? user!.phone : '9113632816';
  final emailText = user?.email.isNotEmpty == true
      ? user!.email
      : 'vinothdeveloper12@gmail.com';

  await _showSheet<void>(
    context,
    title: 'Basic details',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RequiredLabel(label: 'Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: name,
                        decoration: _decoration(context, '', hint: 'Full name'),
                        validator: (v) => v?.trim().isEmpty ?? true
                            ? 'Enter your name'
                            : null,
                      ),
                      if (eduDisplay.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(eduDisplay,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('To edit go to education section.',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: context.textSecondary)),
                      ],
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Work status',
                        subtitle:
                            'We will personalise your experience based on this',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _RadioOption<String>(
                              label: 'Fresher',
                              value: 'Fresher',
                              groupValue: workStatus,
                              onChanged: (v) {
                                setSt(() {
                                  workStatus = v;
                                  if (v == 'Fresher') {
                                    years = 0;
                                    months = 0;
                                  }
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _RadioOption<String>(
                              label: 'Experienced',
                              value: 'Experienced',
                              groupValue: workStatus,
                              onChanged: (v) =>
                                  setSt(() => workStatus = v),
                            ),
                          ),
                        ],
                      ),
                      if (workStatus == 'Experienced') ...[
                        const SizedBox(height: 14),
                        _RequiredLabel(label: 'Total experience'),
                        const SizedBox(height: 4),
                        Text(
                          'This helps recruiters know your years of experience',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: years,
                                decoration: _decoration(context, '',
                                    hint: 'Select years'),
                                items: List.generate(31, (i) {
                                  return DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                        i == 1 ? '1 Year' : '$i Years'),
                                  );
                                }),
                                onChanged: (v) => setSt(() => years = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: months,
                                decoration: _decoration(context, '',
                                    hint: 'Select month'),
                                items: List.generate(12, (i) {
                                  return DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                        i == 1 ? '1 Month' : '$i Months'),
                                  );
                                }),
                                onChanged: (v) =>
                                    setSt(() => months = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      _RequiredLabel(label: 'Current salary'),
                      const SizedBox(height: 4),
                      Text(
                        'Salary information helps us find relevant jobs for you',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: DropdownButtonFormField<String>(
                              initialValue: currency,
                              decoration: _decoration(context, ''),
                              items: const [
                                DropdownMenuItem(
                                    value: '₹', child: Text('₹')),
                                DropdownMenuItem(
                                    value: '\$', child: Text('\$')),
                                DropdownMenuItem(
                                    value: '€', child: Text('€')),
                                DropdownMenuItem(
                                    value: '£', child: Text('£')),
                                DropdownMenuItem(
                                    value: 'AED', child: Text('AED')),
                              ],
                              onChanged: (v) =>
                                  setSt(() => currency = v ?? '₹'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: salaryAmount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9,]')),
                              ],
                              decoration: _decoration(context, '',
                                  hint: 'e.g. 6,00,000'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _RequiredLabel(label: 'Salary breakdown'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: breakdown,
                        decoration: _decoration(context, ''),
                        items: const [
                          DropdownMenuItem(
                              value: 'Fixed', child: Text('Fixed')),
                          DropdownMenuItem(
                              value: 'Variable', child: Text('Variable')),
                          DropdownMenuItem(
                              value: 'Fixed + Variable',
                              child: Text('Fixed + Variable')),
                        ],
                        onChanged: (v) =>
                            setSt(() => breakdown = v ?? 'Fixed'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        breakdown == 'Fixed'
                            ? 'Your total salary has been considered as fixed component'
                            : breakdown == 'Variable'
                                ? 'Your total salary has been considered as variable component'
                                : 'Your salary includes both fixed and variable components',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SectionLabel(
                        title: 'Current location',
                        required: true,
                        subtitle: 'This helps us match you to relevant jobs',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _RadioOption<String>(
                              label: 'India',
                              value: 'India',
                              groupValue: locType,
                              onChanged: (v) {
                                setSt(() {
                                  locType = v;
                                  country = '';
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _RadioOption<String>(
                              label: 'Outside India',
                              value: 'Outside India',
                              groupValue: locType,
                              onChanged: (v) {
                                setSt(() {
                                  locType = v;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: city,
                              decoration: _decoration(context, '',
                                  hint:
                                      'Tell us about your current location'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: locType == 'India'
                                ? TextFormField(
                                    enabled: false,
                                    initialValue: 'India',
                                    decoration: _decoration(context, ''),
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue:
                                        (country?.isEmpty ?? true)
                                            ? null
                                            : country,
                                    decoration: _decoration(context, '',
                                        hint: 'Select country'),
                                    items: _countries
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setSt(() => country = v),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _RequiredLabel(label: 'Mobile number'),
                      const SizedBox(height: 4),
                      Text('Recruiters will contact you on this number',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            phoneText,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () {
                              _toast(sheetCtx,
                                  'Mobile number editing will be available soon');
                            },
                            child: Text('Change Mobile Number',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('Telephone number',
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: telCountry,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: _decoration(context, '',
                                  hint: 'Country code'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: telArea,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              decoration: _decoration(context, '',
                                  hint: 'Area code'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: telPhone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _decoration(context, '',
                                  hint: 'Phone number'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _RequiredLabel(label: 'Email address'),
                      const SizedBox(height: 4),
                      Text(
                          'We will send relevant jobs and updates to this email',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          Text(
                            emailText,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.editField,
                                arguments: const EditFieldArgs(
                                    EditFieldKind.email),
                              );
                            },
                            child: Text('Change Email',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text('Availability to join',
                          style: AppTextStyles.label
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Lets recruiters know your availability to join',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final opt in _availabilityOptions)
                            _AvailabilityChip(
                              label: opt,
                              selected: availability == opt,
                              onTap: () =>
                                  setSt(() => availability = opt),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SaveBar(
              onSave: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;

                String expDisplay;
                if (workStatus == 'Fresher') {
                  expDisplay = 'Fresher';
                } else {
                  final y = years ?? 0;
                  final m = months ?? 0;
                  final yPart = y > 0 ? '$y ${y == 1 ? 'Year' : 'Years'}' : '';
                  final mPart =
                      m > 0 ? '$m ${m == 1 ? 'Month' : 'Months'}' : '';
                  expDisplay =
                      [yPart, mPart].where((s) => s.isNotEmpty).join(' ');
                  if (expDisplay.isEmpty) expDisplay = '0 Years';
                }

                final salaryDisplay = salaryAmount.text.trim().isEmpty
                    ? ''
                    : '$currency${salaryAmount.text.trim()}';

                final cityVal = city.text.trim();
                String locationDisplay;
                if (locType == 'India') {
                  locationDisplay = cityVal.isEmpty
                      ? 'India'
                      : '$cityVal, INDIA';
                } else {
                  final countryVal = country ?? '';
                  if (cityVal.isEmpty && countryVal.isEmpty) {
                    locationDisplay = 'Outside India';
                  } else if (cityVal.isEmpty) {
                    locationDisplay = countryVal;
                  } else if (countryVal.isEmpty) {
                    locationDisplay = cityVal;
                  } else {
                    locationDisplay = '$cityVal, $countryVal';
                  }
                }

                await sheetCtx
                    .read<ResumeProfileProvider>()
                    .updateBasicDetails(
                      workStatus: workStatus,
                      expYears: years ?? 0,
                      expMonths: months ?? 0,
                      experience: expDisplay,
                      currency: currency,
                      salaryAmount: salaryAmount.text.trim(),
                      currentSalary: salaryDisplay,
                      salaryBreakdown: breakdown,
                      locationType: locType,
                      locationCity: cityVal,
                      locationCountry: country ?? '',
                      location: locationDisplay,
                      telephoneCountry: telCountry.text.trim(),
                      telephoneArea: telArea.text.trim(),
                      telephonePhone: telPhone.text.trim(),
                      availability: availability,
                    );

                final newName = name.text.trim();
                if (newName.isNotEmpty &&
                    newName != (user?.name ?? '') &&
                    sheetCtx.mounted) {
                  await sheetCtx
                      .read<AuthProvider>()
                      .updateProfile(name: newName);
                }

                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _RequiredLabel extends StatelessWidget {
  final String label;
  const _RequiredLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.label.copyWith(
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
        children: [
          TextSpan(text: label),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.urgent),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool required;
  const _SectionLabel({
    required this.title,
    this.subtitle,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          required
              ? _RequiredLabel(label: title)
              : Text(title,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  )),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _RadioOption<T> extends StatelessWidget {
  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : context.textTertiary,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? context.textPrimary
                      : context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AvailabilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.primary : context.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : context.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 2. Resume upload (real file picker)
// =============================================================
const _allowedResumeExt = {'pdf', 'doc', 'docx', 'rtf'};

Future<FilePickerResult?> _pickResumeFile() async {
  try {
    return await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedResumeExt.toList(),
      withData: false,
    );
  } on MissingPluginException {
    return await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
  } on PlatformException catch (e) {
    if (e.code == 'unimplemented' || e.message?.contains('custom') == true) {
      return await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
    }
    rethrow;
  }
}

Future<void> pickAndSaveResume(BuildContext context) async {
  try {
    final result = await _pickResumeFile();
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    if (picked.path == null) {
      if (context.mounted) _toast(context, 'Could not read file');
      return;
    }

    final ext = picked.extension?.toLowerCase() ?? '';
    if (ext.isNotEmpty && !_allowedResumeExt.contains(ext)) {
      if (context.mounted) {
        _toast(context,
            'Unsupported format. Use pdf, doc, docx or rtf.',
            bg: AppColors.urgent);
      }
      return;
    }

    if (picked.size > 2 * 1024 * 1024) {
      if (context.mounted) {
        _toast(context, 'File too large. Max 2 MB.', bg: AppColors.urgent);
      }
      return;
    }

    final source = File(picked.path!);
    final docs = await getApplicationDocumentsDirectory();
    final destDir = Directory('${docs.path}/resumes');
    if (!destDir.existsSync()) destDir.createSync(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    // Sanitise the on-disk filename — Android PdfRenderer chokes on paths
    // with spaces or other special chars even though Dart File handles
    // them. Keep the original name for display via the provider field
    // below, but write the file to a safe path.
    final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${destDir.path}/$stamp-$safeName');
    await source.copy(dest.path);

    final today = DateFormat('MMM d, yyyy').format(DateTime.now());
    if (!context.mounted) return;
    final provider = context.read<ResumeProfileProvider>();
    await provider.updateResume(
      fileName: picked.name,
      filePath: dest.path,
      sizeBytes: picked.size,
      uploadedOn: today,
    );

    // Upload to backend + parse via Claude so we can auto-populate fields.
    // Both steps run inside a non-dismissible loading overlay so the user
    // sees what's happening; on any failure we keep the local copy and
    // surface a non-blocking toast — the upload is non-essential to the
    // local profile working.
    if (!context.mounted) return;
    await _runResumeAutoPopulate(context, File(dest.path), provider);
  } on MissingPluginException {
    if (context.mounted) {
      _toast(context,
          'File picker not available. Please fully restart the app (stop and run again, not hot reload).',
          bg: AppColors.urgent);
    }
  } catch (e) {
    if (context.mounted) {
      _toast(context, 'Upload failed: $e', bg: AppColors.urgent);
    }
  }
}

Future<void> _runResumeAutoPopulate(
  BuildContext context,
  File file,
  ResumeProfileProvider provider,
) async {
  // Capture once up-front so we can dismiss the overlay safely after
  // async work, even if the originating widget has been unmounted.
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final overlayState = _ResumeAutoFillOverlayController();
  _showAutoFillOverlay(context, overlayState);

  void dismiss() {
    if (!_autoFillOverlayShown) return;
    _autoFillOverlayShown = false;
    if (navigator.canPop()) navigator.pop();
  }

  void toast(String msg, {Color? bg}) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  try {
    final userService = UserService();

    overlayState.update('Uploading resume…');
    await userService.uploadResume(file);

    overlayState.update('Reading your resume…');
    final parsed = await userService.parseResume();

    if (parsed == null) {
      dismiss();
      toast(
        'Resume saved. Couldn\'t auto-read this file — please fill the fields manually.',
      );
      return;
    }

    overlayState.update('Filling your profile…');
    final filledCount = await provider.applyParsedResume(parsed);

    dismiss();
    if (filledCount > 0) {
      toast(
        'Resume saved · auto-filled $filledCount section${filledCount == 1 ? '' : 's'} — review and edit anytime.',
        bg: AppColors.success,
      );
    } else {
      toast(
        'Resume saved. Your profile already has the details from this resume.',
        bg: AppColors.success,
      );
    }
  } catch (_) {
    dismiss();
    // The local copy + provider.updateResume already succeeded above, so
    // upload/parse failure is non-fatal — just inform the user.
    toast(
      'Resume saved on this device, but auto-fill failed. You can still edit fields manually.',
    );
  }
}

class _ResumeAutoFillOverlayController extends ChangeNotifier {
  String _label = 'Reading your resume…';
  String get label => _label;
  void update(String next) {
    _label = next;
    notifyListeners();
  }
}

bool _autoFillOverlayShown = false;

void _showAutoFillOverlay(
  BuildContext context,
  _ResumeAutoFillOverlayController controller,
) {
  _autoFillOverlayShown = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => PopScope(
      canPop: false,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: controller,
                builder: (_, __) => Text(
                  controller.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This usually takes 5–10 seconds',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


Future<void> confirmDeleteResume(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text('Delete resume?'),
      content:
          const Text('Your uploaded resume will be removed from this device.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final provider = context.read<ResumeProfileProvider>();
  final path = provider.profile.resumeFilePath;
  if (path.isNotEmpty) {
    final f = File(path);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
  await provider.deleteResume();
  if (context.mounted) {
    _toast(context, 'Resume removed', bg: AppColors.urgent);
  }
}

// =============================================================
// 3. Single text field (used by headline, summary, diversity)
// =============================================================
Future<void> editHeadline(BuildContext context) async {
  final initial = context.read<ResumeProfileProvider>().profile.resumeHeadline;
  final value = await _editLongText(
    context,
    title: 'Resume headline',
    initial: initial,
    hint: 'Add a short headline that recruiters will see first',
    minLines: 3,
    maxLength: 250,
  );
  if (value == null || !context.mounted) return;
  await context.read<ResumeProfileProvider>().updateHeadline(value);
}

Future<void> editSummary(BuildContext context) async {
  final initial = context.read<ResumeProfileProvider>().profile.profileSummary;
  final value = await _editLongText(
    context,
    title: 'Profile summary',
    initial: initial,
    hint:
        'Write a few lines about yourself, your experience, and goals.',
    minLines: 6,
    maxLength: 1500,
  );
  if (value == null || !context.mounted) return;
  await context.read<ResumeProfileProvider>().updateSummary(value);
}

Future<void> editDiversity(BuildContext context) async {
  final initial =
      context.read<ResumeProfileProvider>().profile.diversityNote;
  final value = await _editLongText(
    context,
    title: 'Diversity & inclusion',
    initial: initial,
    hint:
        'Share details to attract recruiters who value people from different backgrounds.',
    minLines: 4,
    maxLength: 600,
  );
  if (value == null || !context.mounted) return;
  await context.read<ResumeProfileProvider>().updateDiversity(value);
}

Future<String?> _editLongText(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
  int minLines = 3,
  int maxLength = 500,
}) {
  final ctrl = TextEditingController(text: initial);
  return _showSheet<String>(
    context,
    title: title,
    builder: (sheetCtx) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: ctrl,
                maxLines: null,
                minLines: minLines,
                maxLength: maxLength,
                expands: false,
                textAlignVertical: TextAlignVertical.top,
                decoration: _decoration(context, title, hint: hint),
              ),
            ),
          ),
          _SaveBar(
            onSave: () => Navigator.pop(sheetCtx, ctrl.text.trim()),
          ),
        ],
      );
    },
  );
}

// =============================================================
// 4. Key skills (chips with add/remove)
// =============================================================
Future<void> editKeySkills(BuildContext context) async {
  final initial = List<String>.from(
      context.read<ResumeProfileProvider>().profile.keySkills);
  final result = await _showSheet<List<String>>(
    context,
    title: 'Key skills',
    builder: (sheetCtx) =>
        _KeySkillsEditor(initial: initial),
  );
  if (result == null || !context.mounted) return;
  await context.read<ResumeProfileProvider>().updateKeySkills(result);
}

class _KeySkillsEditor extends StatefulWidget {
  final List<String> initial;
  const _KeySkillsEditor({required this.initial});

  @override
  State<_KeySkillsEditor> createState() => _KeySkillsEditorState();
}

class _KeySkillsEditorState extends State<_KeySkillsEditor> {
  late List<String> _skills;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _skills = List.from(widget.initial);
  }

  void _add() {
    final s = _ctrl.text.trim();
    if (s.isEmpty) return;
    if (_skills.any((e) => e.toLowerCase() == s.toLowerCase())) {
      _toast(context, 'Skill already added');
      return;
    }
    setState(() {
      _skills.add(s);
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: _decoration(context, 'Add a skill',
                      hint: 'e.g. React Native', icon: Icons.add_rounded),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _skills.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No skills yet',
                          style: AppTextStyles.bodySmall),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _skills.length; i++)
                        InputChip(
                          label: Text(_skills[i]),
                          backgroundColor: AppColors.primaryLight,
                          labelStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          deleteIcon: const Icon(Icons.close_rounded,
                              size: 16, color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: BorderSide(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25)),
                          ),
                          onDeleted: () =>
                              setState(() => _skills.removeAt(i)),
                        ),
                    ],
                  ),
          ),
        ),
        _SaveBar(
          onSave: () => Navigator.pop(context, _skills),
        ),
      ],
    );
  }
}

// =============================================================
// 5. Employment editor
// =============================================================
Future<void> manageEmployments(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _EmploymentsScreen()),
  );
}

class _EmploymentsScreen extends StatelessWidget {
  const _EmploymentsScreen();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ResumeProfileProvider>().profile.employments;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _editorAppBar(context, 'Employment'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEmploymentForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: entries.isEmpty
          ? _emptyState(context, 
              icon: Icons.business_center_outlined,
              title: 'No employment yet',
              subtitle: 'Tap "Add" to add your first work experience.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final e = entries[i];
                return _ItemCard(
                  title: e.designation,
                  subtitle: '${e.company}\n${e.period}',
                  onEdit: () => _editEmploymentForm(context, index: i),
                  onDelete: () => context
                      .read<ResumeProfileProvider>()
                      .deleteEmployment(i),
                );
              },
            ),
    );
  }
}

Future<void> _editEmploymentForm(BuildContext context, {int? index}) async {
  final provider = context.read<ResumeProfileProvider>();
  final entry = index != null
      ? provider.profile.employments[index]
      : const EmploymentEntry(designation: '', company: '', period: '');
  final designation = TextEditingController(text: entry.designation);
  final company = TextEditingController(text: entry.company);
  final parsed = _parsePeriod(entry.period);
  String? fromMonth = parsed.fromMonth;
  int? fromYear = parsed.fromYear;
  String? toMonth = parsed.toMonth;
  int? toYear = parsed.toYear;
  bool current = entry.current || parsed.current;
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: index == null ? 'Add employment' : 'Edit employment',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: designation,
                        decoration: _decoration(context, 'Designation',
                            hint: 'e.g. Front End Developer',
                            icon: Icons.badge_outlined),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: company,
                        decoration: _decoration(context, 'Company',
                            hint: 'e.g. Acme Corp',
                            icon: Icons.business_outlined),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _MonthYearRow(
                        label: 'Worked from',
                        month: fromMonth,
                        year: fromYear,
                        onMonthChanged: (v) =>
                            setSt(() => fromMonth = v),
                        onYearChanged: (v) => setSt(() => fromYear = v),
                      ),
                      const SizedBox(height: 14),
                      _MonthYearRow(
                        label: current ? 'Worked till' : 'Worked till',
                        month: toMonth,
                        year: toYear,
                        enabled: !current,
                        onMonthChanged: (v) => setSt(() => toMonth = v),
                        onYearChanged: (v) => setSt(() => toYear = v),
                      ),
                      const SizedBox(height: 6),
                      _CheckOption(
                        label: 'Currently working here',
                        selected: current,
                        onTap: () => setSt(() {
                          current = !current;
                          if (current) {
                            toMonth = null;
                            toYear = null;
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SaveBar(
              onSave: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (fromMonth == null || fromYear == null) {
                  _toast(sheetCtx, 'Please select start month and year',
                      bg: AppColors.urgent);
                  return;
                }
                if (!current && (toMonth == null || toYear == null)) {
                  _toast(sheetCtx,
                      'Select end month/year or mark as current',
                      bg: AppColors.urgent);
                  return;
                }
                final periodStr = _formatPeriod(
                  fromMonth: fromMonth,
                  fromYear: fromYear,
                  toMonth: toMonth,
                  toYear: toYear,
                  current: current,
                );
                await provider.upsertEmployment(
                  EmploymentEntry(
                    designation: designation.text.trim(),
                    company: company.text.trim(),
                    period: periodStr,
                    current: current,
                  ),
                  index: index,
                );
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================
// 6. Education editor
// =============================================================
Future<void> manageEducations(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _EducationsScreen()),
  );
}

class _EducationsScreen extends StatelessWidget {
  const _EducationsScreen();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ResumeProfileProvider>().profile.educations;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _editorAppBar(context, 'Education'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEducationForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: entries.isEmpty
          ? _emptyState(context, 
              icon: Icons.school_outlined,
              title: 'No education added',
              subtitle: 'Add your degrees, schools, and projects.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final e = entries[i];
                return _ItemCard(
                  title: e.degree,
                  subtitle:
                      '${e.institute}\n${e.period}  |  ${e.type}${e.projects.isNotEmpty ? '\nProjects: ${e.projects.join(', ')}' : ''}',
                  onEdit: () => _editEducationForm(context, index: i),
                  onDelete: () => context
                      .read<ResumeProfileProvider>()
                      .deleteEducation(i),
                );
              },
            ),
    );
  }
}

Future<void> _editEducationForm(BuildContext context, {int? index}) async {
  final provider = context.read<ResumeProfileProvider>();
  final entry = index != null
      ? provider.profile.educations[index]
      : const EducationEntry(
          degree: '', institute: '', period: '', type: 'Full Time');
  final degree = TextEditingController(text: entry.degree);
  final institute = TextEditingController(text: entry.institute);
  final yr = _parseYearRange(entry.period);
  int? fromYear = yr.fromYear;
  int? toYear = yr.toYear;
  bool pursuing = yr.pursuing;
  String type = entry.type.isNotEmpty ? entry.type : 'Full Time';
  final projectInput = TextEditingController();
  final projects = List<String>.from(entry.projects);
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: index == null ? 'Add education' : 'Edit education',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: degree,
                        decoration: _decoration(context, 'Degree',
                            hint: 'e.g. B.A - Bachelor of Arts',
                            icon: Icons.school_outlined),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: institute,
                        decoration: _decoration(context, 'Institute',
                            hint: 'e.g. Government Arts College',
                            icon: Icons.account_balance_outlined),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      Text('Course duration',
                          style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: fromYear,
                              isExpanded: true,
                              decoration: _decoration(context, '',
                                  hint: 'Starting year'),
                              items: [
                                for (final y in _yearList(back: 60))
                                  DropdownMenuItem(
                                      value: y, child: Text('$y')),
                              ],
                              onChanged: (v) =>
                                  setSt(() => fromYear = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: IgnorePointer(
                              ignoring: pursuing,
                              child: Opacity(
                                opacity: pursuing ? 0.5 : 1,
                                child: DropdownButtonFormField<int>(
                                  initialValue: toYear,
                                  isExpanded: true,
                                  decoration: _decoration(context, '',
                                      hint: 'Ending year'),
                                  items: [
                                    for (final y
                                        in _yearList(back: 60, includeNext: true))
                                      DropdownMenuItem(
                                          value: y, child: Text('$y')),
                                  ],
                                  onChanged: (v) =>
                                      setSt(() => toYear = v),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _CheckOption(
                        label: 'Currently pursuing',
                        selected: pursuing,
                        onTap: () => setSt(() {
                          pursuing = !pursuing;
                          if (pursuing) toYear = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        decoration: _decoration(context, 'Type',
                            icon: Icons.category_outlined),
                        items: const [
                          DropdownMenuItem(
                              value: 'Full Time', child: Text('Full Time')),
                          DropdownMenuItem(
                              value: 'Part Time', child: Text('Part Time')),
                          DropdownMenuItem(
                              value: 'Distance Learning',
                              child: Text('Distance Learning')),
                          DropdownMenuItem(
                              value: 'Correspondence',
                              child: Text('Correspondence')),
                        ],
                        onChanged: (v) => setSt(() => type = v ?? 'Full Time'),
                      ),
                      const SizedBox(height: 18),
                      Text('Projects', style: AppTextStyles.label),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: projectInput,
                              decoration: _decoration(context, 'Add project',
                                  icon: Icons.add_rounded),
                              onSubmitted: (v) {
                                if (v.trim().isEmpty) return;
                                setSt(() {
                                  projects.add(v.trim());
                                  projectInput.clear();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (projectInput.text.trim().isEmpty) return;
                              setSt(() {
                                projects.add(projectInput.text.trim());
                                projectInput.clear();
                              });
                            },
                            icon: const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < projects.length; i++)
                            InputChip(
                              label: Text(projects[i]),
                              onDeleted: () =>
                                  setSt(() => projects.removeAt(i)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SaveBar(
              onSave: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final periodStr =
                    _formatYearRange(fromYear, toYear, pursuing);
                await provider.upsertEducation(
                  EducationEntry(
                    degree: degree.text.trim(),
                    institute: institute.text.trim(),
                    period: periodStr,
                    type: type,
                    projects: projects,
                  ),
                  index: index,
                );
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================
// 7. IT skills editor
// =============================================================
Future<void> manageItSkills(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _ItSkillsScreen()),
  );
}

class _ItSkillsScreen extends StatelessWidget {
  const _ItSkillsScreen();

  @override
  Widget build(BuildContext context) {
    final skills = context.watch<ResumeProfileProvider>().profile.itSkills;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _editorAppBar(context, 'IT skills'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItSkillForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: skills.isEmpty
          ? _emptyState(context, 
              icon: Icons.code_rounded,
              title: 'No IT skills added',
              subtitle: 'Add the technologies you have hands-on experience with.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: skills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = skills[i];
                return _ItemCard(
                  title: s.skill,
                  subtitle:
                      '${s.version != '-' ? 'v${s.version}  •  ' : ''}Last used ${s.lastUsed}\n${s.experience}',
                  onEdit: () => _editItSkillForm(context, index: i),
                  onDelete: () => context
                      .read<ResumeProfileProvider>()
                      .deleteItSkill(i),
                );
              },
            ),
    );
  }
}

({int? years, int? months}) _parseExperience(String value) {
  final yMatch = RegExp(r'(\d+)\s*Year').firstMatch(value);
  final mMatch = RegExp(r'(\d+)\s*Month').firstMatch(value);
  return (
    years: yMatch != null ? int.tryParse(yMatch.group(1)!) : null,
    months: mMatch != null ? int.tryParse(mMatch.group(1)!) : null,
  );
}

String _formatExperience(int? years, int? months) {
  final y = years ?? 0;
  final m = months ?? 0;
  final yPart = y > 0 ? '$y ${y == 1 ? 'Year' : 'Years'}' : '';
  final mPart = m > 0 ? '$m ${m == 1 ? 'Month' : 'Months'}' : '';
  if (yPart.isEmpty && mPart.isEmpty) return '0 Year 0 Month';
  return [yPart, mPart].where((s) => s.isNotEmpty).join(' ');
}

Future<void> _editItSkillForm(BuildContext context, {int? index}) async {
  final provider = context.read<ResumeProfileProvider>();
  final entry = index != null
      ? provider.profile.itSkills[index]
      : const ITSkill(
          skill: '', version: '-', lastUsed: '', experience: '');
  final skill = TextEditingController(text: entry.skill);
  final version = TextEditingController(
    text: entry.version == '-' ? '' : entry.version,
  );
  int? lastUsed = int.tryParse(entry.lastUsed);
  final exp = _parseExperience(entry.experience);
  int? expYears = exp.years;
  int? expMonths = exp.months;
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: index == null ? 'Add IT skill' : 'Edit IT skill',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: skill,
                        decoration: _decoration(context, 'Skill',
                            hint: 'e.g. React Native',
                            icon: Icons.code_rounded),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: version,
                        decoration: _decoration(context, 'Version (optional)',
                            hint: 'e.g. 18'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: lastUsed,
                        isExpanded: true,
                        decoration: _decoration(context, 'Last used',
                            icon: Icons.access_time_rounded,
                            hint: 'Select year'),
                        items: [
                          for (final y in _yearList(back: 30))
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) => setSt(() => lastUsed = v),
                      ),
                      const SizedBox(height: 14),
                      Text('Experience',
                          style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: expYears,
                              isExpanded: true,
                              decoration: _decoration(context, '', hint: 'Years'),
                              items: [
                                for (var i = 0; i <= 30; i++)
                                  DropdownMenuItem(
                                      value: i,
                                      child: Text(i == 1
                                          ? '1 Year'
                                          : '$i Years')),
                              ],
                              onChanged: (v) => setSt(() => expYears = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: expMonths,
                              isExpanded: true,
                              decoration: _decoration(context, '', hint: 'Months'),
                              items: [
                                for (var i = 0; i < 12; i++)
                                  DropdownMenuItem(
                                      value: i,
                                      child: Text(i == 1
                                          ? '1 Month'
                                          : '$i Months')),
                              ],
                              onChanged: (v) =>
                                  setSt(() => expMonths = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SaveBar(
              onSave: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await provider.upsertItSkill(
                  ITSkill(
                    skill: skill.text.trim(),
                    version: version.text.trim().isEmpty
                        ? '-'
                        : version.text.trim(),
                    lastUsed: lastUsed?.toString() ?? '',
                    experience: _formatExperience(expYears, expMonths),
                  ),
                  index: index,
                );
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================
// 8. Projects editor
// =============================================================
Future<void> manageProjects(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _ProjectsScreen()),
  );
}

class _ProjectsScreen extends StatelessWidget {
  const _ProjectsScreen();

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ResumeProfileProvider>().profile.projects;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _editorAppBar(context, 'Projects'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProjectForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: projects.isEmpty
          ? _emptyState(context, 
              icon: Icons.folder_special_outlined,
              title: 'No projects yet',
              subtitle: 'Showcase the projects you\'ve worked on.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = projects[i];
                return _ItemCard(
                  title: p.title,
                  subtitle:
                      '${p.company}\n${p.period}  |  ${p.type}\n\n${p.description}',
                  onEdit: () => _editProjectForm(context, index: i),
                  onDelete: () => context
                      .read<ResumeProfileProvider>()
                      .deleteProject(i),
                );
              },
            ),
    );
  }
}

Future<void> _editProjectForm(BuildContext context, {int? index}) async {
  final provider = context.read<ResumeProfileProvider>();
  final entry = index != null
      ? provider.profile.projects[index]
      : const ProjectEntry(
          title: '', company: '', type: 'Full Time', period: '', description: '');
  final title = TextEditingController(text: entry.title);
  final company = TextEditingController(text: entry.company);
  final description = TextEditingController(text: entry.description);
  final parsed = _parsePeriod(entry.period);
  String? fromMonth = parsed.fromMonth;
  int? fromYear = parsed.fromYear;
  String? toMonth = parsed.toMonth;
  int? toYear = parsed.toYear;
  bool current = parsed.current;
  String type = entry.type.isNotEmpty ? entry.type : 'Full Time';
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: index == null ? 'Add project' : 'Edit project',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: title,
                        decoration: _decoration(context, 'Project title',
                            icon: Icons.folder_special_outlined),
                        validator: (v) =>
                            v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: company,
                        decoration: _decoration(context, 'Company / Client',
                            icon: Icons.business_outlined),
                      ),
                      const SizedBox(height: 18),
                      _MonthYearRow(
                        label: 'Started in',
                        month: fromMonth,
                        year: fromYear,
                        onMonthChanged: (v) =>
                            setSt(() => fromMonth = v),
                        onYearChanged: (v) => setSt(() => fromYear = v),
                      ),
                      const SizedBox(height: 14),
                      _MonthYearRow(
                        label: 'Ended in',
                        month: toMonth,
                        year: toYear,
                        enabled: !current,
                        onMonthChanged: (v) => setSt(() => toMonth = v),
                        onYearChanged: (v) => setSt(() => toYear = v),
                      ),
                      const SizedBox(height: 6),
                      _CheckOption(
                        label: 'Currently working on this project',
                        selected: current,
                        onTap: () => setSt(() {
                          current = !current;
                          if (current) {
                            toMonth = null;
                            toYear = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        isExpanded: true,
                        decoration: _decoration(context, 'Type',
                            icon: Icons.category_outlined),
                        items: const [
                          DropdownMenuItem(
                              value: 'Full Time', child: Text('Full Time')),
                          DropdownMenuItem(
                              value: 'Part Time', child: Text('Part Time')),
                          DropdownMenuItem(
                              value: 'Internship', child: Text('Internship')),
                          DropdownMenuItem(
                              value: 'Freelance', child: Text('Freelance')),
                        ],
                        onChanged: (v) => setSt(() => type = v ?? 'Full Time'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: description,
                        maxLines: 5,
                        minLines: 3,
                        decoration: _decoration(context, 'Description',
                            hint:
                                'Briefly describe what the project does and your role'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SaveBar(
              onSave: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final periodStr = _formatPeriod(
                  fromMonth: fromMonth,
                  fromYear: fromYear,
                  toMonth: toMonth,
                  toYear: toYear,
                  current: current,
                );
                await provider.upsertProject(
                  ProjectEntry(
                    title: title.text.trim(),
                    company: company.text.trim(),
                    type: type,
                    period: periodStr,
                    description: description.text.trim(),
                  ),
                  index: index,
                );
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
      );
    },
  );
}

// =============================================================
// 9. Accomplishments editor
// =============================================================
Future<void> addAccomplishment(BuildContext context, String type) async {
  final ctrl = TextEditingController();
  await _showSheet<void>(
    context,
    title: 'Add $type',
    builder: (sheetCtx) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: ctrl,
                maxLines: 5,
                minLines: 2,
                decoration: _decoration(context, type,
                    hint: _accomplishmentHint(type)),
              ),
            ),
          ),
          _SaveBar(
            onSave: () async {
              if (ctrl.text.trim().isEmpty) {
                Navigator.pop(sheetCtx);
                return;
              }
              await sheetCtx
                  .read<ResumeProfileProvider>()
                  .upsertAccomplishment(
                    Accomplishment(
                      type: type,
                      label: type,
                      value: ctrl.text.trim(),
                    ),
                  );
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            },
          ),
        ],
      );
    },
  );
}

String _accomplishmentHint(String type) {
  switch (type) {
    case 'Online profile':
      return 'e.g. https://linkedin.com/in/yourname';
    case 'Work sample':
      return 'e.g. https://github.com/yourname';
    case 'White paper / Research publication / Journal entry':
      return 'Add link or title of your publication';
    case 'Presentation':
      return 'e.g. https://slideshare.net/your-deck';
    case 'Patent':
      return 'Patent number, title, status';
    case 'Certification':
      return 'e.g. AWS Certified Developer — 2024';
    default:
      return '';
  }
}

Future<void> deleteAccomplishment(BuildContext context, int index) async {
  await context.read<ResumeProfileProvider>().deleteAccomplishment(index);
  if (context.mounted) _toast(context, 'Removed');
}

// =============================================================
// 10. Career profile editor
// =============================================================
const List<String> _industries = [
  'IT Services & Consulting',
  'Software Product',
  'IT-Hardware & Networking',
  'BPO / Call Centre',
  'Banking & Financial Services',
  'Education / Training',
  'Healthcare / Pharma',
  'Manufacturing',
  'Retail',
  'Telecom',
  'Media & Entertainment',
  'Real Estate',
  'Travel & Hospitality',
  'E-commerce / Internet',
  'Other',
];

const List<String> _departments = [
  'IT & Information Security',
  'Engineering - Software & QA',
  'Engineering - Hardware & Networks',
  'Sales & Business Development',
  'Marketing & Communication',
  'Human Resources',
  'Finance & Accounting',
  'Customer Success, Service & Operations',
  'Product Management',
  'UX, Design & Architecture',
  'Data Science & Analytics',
  'Production, Manufacturing & Engineering',
  'Other',
];

const List<String> _roleCategories = [
  'IT & Information Security - Other',
  'Software Development - Frontend',
  'Software Development - Backend',
  'Software Development - Fullstack',
  'Mobile / App Development',
  'DevOps / Cloud',
  'QA & Testing',
  'Data Engineering',
  'Data Science / AI / ML',
  'Cybersecurity',
  'Product Management',
  'UI / UX Design',
  'Other',
];

const List<String> _jobRoles = [
  'IT & Information Security - Other',
  'Frontend Developer',
  'Backend Developer',
  'Full Stack Developer',
  'Mobile App Developer',
  'DevOps Engineer',
  'QA / Test Engineer',
  'Data Engineer',
  'Data Scientist',
  'ML Engineer',
  'Security Engineer',
  'UI / UX Designer',
  'Product Manager',
  'Other',
];

const List<String> _jobTypes = [
  'Permanent',
  'Contractual',
  'Internship',
  'Freelance',
];

const List<String> _employmentTypes = [
  'Full time',
  'Part time',
  'Temporary',
  'Seasonal',
];

const List<String> _shifts = ['Day', 'Night', 'Flexible'];

const List<String> _locationSuggestions = [
  'Bengaluru', 'Chennai', 'Hyderabad', 'Pune', 'Mumbai',
  'Delhi', 'Noida', 'Gurgaon', 'Kolkata', 'Ahmedabad',
  'Salem', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Tirupur',
  'Thiruvananthapuram', 'Kochi', 'Jaipur', 'Lucknow', 'Indore',
  'Bhopal', 'Vadodara', 'Surat', 'Nagpur', 'Visakhapatnam',
];

Future<void> editCareer(BuildContext context) async {
  final c = context.read<ResumeProfileProvider>().profile.careerProfile;

  String? industry =
      c.currentIndustry.trim().isEmpty ? null : c.currentIndustry.trim();
  String? department =
      c.department.trim().isEmpty ? null : c.department.trim();
  String? roleCategory =
      c.roleCategory.trim().isEmpty ? null : c.roleCategory.trim();
  String? jobRole = c.jobRole.trim().isEmpty ? null : c.jobRole.trim();

  Set<String> jobTypes = _csvToSet(c.desiredJobType, _jobTypes);
  Set<String> empTypes = _csvToSet(c.desiredEmploymentType, _employmentTypes);
  String shift = _shifts.firstWhere(
    (s) => s.toLowerCase() == c.preferredShift.trim().toLowerCase(),
    orElse: () => 'Flexible',
  );

  final List<String> locations = c.preferredLocation
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final salaryParts = _splitAmount(c.expectedSalary);
  String currency = salaryParts.currency;
  final amountCtrl = TextEditingController(text: salaryParts.amount);
  final locInput = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: 'Career profile',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) {
          final industryItems = _withCustom(_industries, industry);
          final departmentItems = _withCustom(_departments, department);
          final roleCategoryItems = _withCustom(_roleCategories, roleCategory);
          final jobRoleItems = _withCustom(_jobRoles, jobRole);

          void addLocation(String raw) {
            final v = raw.trim();
            if (v.isEmpty) return;
            if (locations.length >= 10) {
              _toast(sheetCtx, 'You can add up to 10 locations');
              return;
            }
            if (locations.any((l) => l.toLowerCase() == v.toLowerCase())) {
              _toast(sheetCtx, 'Already added');
              return;
            }
            setSt(() {
              locations.add(v);
              locInput.clear();
            });
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add details about your current and preferred job profile. This helps us personalise your job recommendations.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _RequiredLabel(label: 'Current industry'),
                        const SizedBox(height: 6),
                        _appDropdown<String>(context, 
                          value: industry,
                          hint: 'Select industry',
                          items: industryItems,
                          labelOf: (v) => v,
                          onChanged: (v) => setSt(() => industry = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _RequiredLabel(label: 'Department'),
                        const SizedBox(height: 6),
                        _appDropdown<String>(context, 
                          value: department,
                          hint: 'Select department',
                          items: departmentItems,
                          labelOf: (v) => v,
                          onChanged: (v) => setSt(() => department = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _RequiredLabel(label: 'Role category'),
                        const SizedBox(height: 6),
                        _appDropdown<String>(context, 
                          value: roleCategory,
                          hint: 'Select role category',
                          items: roleCategoryItems,
                          labelOf: (v) => v,
                          onChanged: (v) => setSt(() => roleCategory = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _RequiredLabel(label: 'Job role'),
                        const SizedBox(height: 6),
                        _appDropdown<String>(context, 
                          value: jobRole,
                          hint: 'Select job role',
                          items: jobRoleItems,
                          labelOf: (v) => v,
                          onChanged: (v) => setSt(() => jobRole = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 22),
                        Text('Desired job type',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        _MultiSelectGrid(
                          options: _jobTypes,
                          selected: jobTypes,
                          onToggle: (opt) => setSt(() {
                            jobTypes.contains(opt)
                                ? jobTypes.remove(opt)
                                : jobTypes.add(opt);
                          }),
                        ),
                        const SizedBox(height: 18),
                        Text('Desired employment type',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        _MultiSelectGrid(
                          options: _employmentTypes,
                          selected: empTypes,
                          onToggle: (opt) => setSt(() {
                            empTypes.contains(opt)
                                ? empTypes.remove(opt)
                                : empTypes.add(opt);
                          }),
                        ),
                        const SizedBox(height: 18),
                        Text('Preferred shift',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            for (final s in _shifts)
                              Expanded(
                                child: _RadioOption<String>(
                                  label: s,
                                  value: s,
                                  groupValue: shift,
                                  onChanged: (v) =>
                                      setSt(() => shift = v),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text('Preferred work location (Max 10)',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 6),
                        Autocomplete<String>(
                          optionsBuilder: (value) {
                            final q = value.text.trim().toLowerCase();
                            if (q.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _locationSuggestions.where((s) =>
                                s.toLowerCase().contains(q) &&
                                !locations.any((l) =>
                                    l.toLowerCase() == s.toLowerCase()));
                          },
                          onSelected: addLocation,
                          fieldViewBuilder:
                              (ctx, ctrl, focus, onSubmit) {
                            // Sync locInput so Save handler sees latest text.
                            locInput.value = ctrl.value;
                            ctrl.addListener(() => locInput.text = ctrl.text);
                            return TextField(
                              controller: ctrl,
                              focusNode: focus,
                              decoration: _decoration(context, '',
                                  hint:
                                      'Tell us your location preferences to work'),
                              onSubmitted: (v) {
                                addLocation(v);
                                ctrl.clear();
                              },
                            );
                          },
                        ),
                        if (locations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < locations.length; i++)
                                _LocationChip(
                                  label: locations[i],
                                  onRemove: () => setSt(
                                      () => locations.removeAt(i)),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                        Text('Expected salary',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: _appDropdown<String>(context, 
                                value: currency,
                                hint: '',
                                items: const ['₹', '\$', '€', '£', 'AED'],
                                labelOf: (v) => v,
                                onChanged: (v) =>
                                    setSt(() => currency = v ?? '₹'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9,]')),
                                ],
                                decoration: _decoration(context, '',
                                    hint: 'e.g. 9,00,000'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _CancelSaveBar(
                onCancel: () => Navigator.pop(sheetCtx),
                onSave: () async {
                  // Add typed-but-not-pressed-enter location.
                  final remaining = locInput.text.trim();
                  if (remaining.isNotEmpty) {
                    addLocation(remaining);
                  }
                  if (!(formKey.currentState?.validate() ?? false)) return;

                  final salaryDisplay = amountCtrl.text.trim().isEmpty
                      ? ''
                      : '$currency${amountCtrl.text.trim()}';

                  await sheetCtx
                      .read<ResumeProfileProvider>()
                      .updateCareer(
                        CareerProfile(
                          currentIndustry: industry ?? '',
                          department: department ?? '',
                          roleCategory: roleCategory ?? '',
                          jobRole: jobRole ?? '',
                          desiredJobType: jobTypes.join(', '),
                          desiredEmploymentType: empTypes.join(', '),
                          preferredShift: shift,
                          preferredLocation: locations.join(', '),
                          expectedSalary: salaryDisplay,
                        ),
                      );
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

class _MultiSelectGrid extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _MultiSelectGrid({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Two-column flex layout.
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      final left = options[i];
      final right = i + 1 < options.length ? options[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: _CheckOption(
                label: left,
                selected: selected.contains(left),
                onTap: () => onToggle(left),
              ),
            ),
            if (right != null)
              Expanded(
                child: _CheckOption(
                  label: right,
                  selected: selected.contains(right),
                  onTap: () => onToggle(right),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _LocationChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 11. Personal details editor
// =============================================================
const List<String> _categoryOptions = [
  'General',
  'OBC - Creamy',
  'OBC - Non-creamy',
  'SC',
  'ST',
  'EWS',
  'Prefer not to say',
];

const List<String> _workPermitCountries = [
  'USA',
  'UK',
  'Canada',
  'Australia',
  'Germany',
  'Singapore',
  'UAE',
  'Saudi Arabia',
  'Qatar',
  'New Zealand',
  'Ireland',
  'Netherlands',
];

Future<void> editPersonal(BuildContext context) async {
  final p = context.read<ResumeProfileProvider>().profile.personalDetails;
  String gender = p.gender.isNotEmpty ? p.gender : 'Male';
  String marital =
      p.maritalStatus.isNotEmpty ? p.maritalStatus : 'Single / unmarried';
  final dob = TextEditingController(text: p.dob);
  String? category = p.category.trim().isEmpty ? null : p.category.trim();
  final Set<String> workPermits = p.workPermit
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final address = TextEditingController(text: p.address);
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: 'Personal details',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) {
          final categoryItems = _withCustom(_categoryOptions, category);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: gender,
                          isExpanded: true,
                          decoration: _decoration(context, 'Gender',
                              icon: Icons.wc_outlined),
                          items: const [
                            DropdownMenuItem(
                                value: 'Male', child: Text('Male')),
                            DropdownMenuItem(
                                value: 'Female', child: Text('Female')),
                            DropdownMenuItem(
                                value: 'Other', child: Text('Other')),
                            DropdownMenuItem(
                                value: 'Prefer not to say',
                                child: Text('Prefer not to say')),
                          ],
                          onChanged: (v) =>
                              setSt(() => gender = v ?? 'Male'),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: marital,
                          isExpanded: true,
                          decoration: _decoration(context, 'Marital status',
                              icon: Icons.favorite_border_rounded),
                          items: const [
                            DropdownMenuItem(
                                value: 'Single / unmarried',
                                child: Text('Single / unmarried')),
                            DropdownMenuItem(
                                value: 'Married',
                                child: Text('Married')),
                            DropdownMenuItem(
                                value: 'Divorced',
                                child: Text('Divorced')),
                            DropdownMenuItem(
                                value: 'Widowed',
                                child: Text('Widowed')),
                            DropdownMenuItem(
                                value: 'Prefer not to say',
                                child: Text('Prefer not to say')),
                          ],
                          onChanged: (v) => setSt(
                              () => marital = v ?? 'Single / unmarried'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: dob,
                          readOnly: true,
                          decoration: _decoration(context, 'Date of birth',
                              hint: 'Tap to pick',
                              icon: Icons.cake_outlined),
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: sheetCtx,
                              initialDate: DateTime(now.year - 25),
                              firstDate: DateTime(1950),
                              lastDate: now,
                            );
                            if (picked != null) {
                              dob.text =
                                  DateFormat('d MMM yyyy').format(picked);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          isExpanded: true,
                          decoration: _decoration(context, 'Category',
                              hint: 'Select category',
                              icon: Icons.flag_outlined),
                          items: [
                            for (final v in categoryItems)
                              DropdownMenuItem(value: v, child: Text(v)),
                          ],
                          onChanged: (v) => setSt(() => category = v),
                        ),
                        const SizedBox(height: 18),
                        Text('Work permit',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                            'Select countries you have permission to work in',
                            style: AppTextStyles.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in _workPermitCountries)
                              _SelectableChip(
                                label: c,
                                selected: workPermits.contains(c),
                                onTap: () => setSt(() {
                                  workPermits.contains(c)
                                      ? workPermits.remove(c)
                                      : workPermits.add(c);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: address,
                          maxLines: 3,
                          decoration: _decoration(context, 'Address',
                              icon: Icons.home_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _SaveBar(
                onSave: () async {
                  await sheetCtx
                      .read<ResumeProfileProvider>()
                      .updatePersonal(
                        PersonalDetails(
                          gender: gender,
                          maritalStatus: marital,
                          dob: dob.text.trim(),
                          category: category ?? '',
                          workPermit: workPermits.join(', '),
                          address: address.text.trim(),
                        ),
                      );
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.primary : context.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected ? AppColors.primary : context.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 12. Languages editor
// =============================================================
Future<void> manageLanguages(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const _LanguagesScreen()),
  );
}

class _LanguagesScreen extends StatelessWidget {
  const _LanguagesScreen();

  @override
  Widget build(BuildContext context) {
    final langs = context.watch<ResumeProfileProvider>().profile.languages;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _editorAppBar(context, 'Languages'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editLanguageForm(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: langs.isEmpty
          ? _emptyState(context, 
              icon: Icons.translate_rounded,
              title: 'No languages added',
              subtitle: 'Add the languages you can read, write or speak.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: langs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final l = langs[i];
                final caps = <String>[];
                if (l.read) caps.add('Read');
                if (l.write) caps.add('Write');
                if (l.speak) caps.add('Speak');
                return _ItemCard(
                  title: l.language,
                  subtitle:
                      '${l.proficiency}\n${caps.isEmpty ? 'No proficiency' : caps.join(' · ')}',
                  onEdit: () => _editLanguageForm(context, index: i),
                  onDelete: () => context
                      .read<ResumeProfileProvider>()
                      .deleteLanguage(i),
                );
              },
            ),
    );
  }
}

const List<String> _languages = [
  'English',
  'Hindi',
  'Tamil',
  'Telugu',
  'Kannada',
  'Malayalam',
  'Marathi',
  'Bengali',
  'Gujarati',
  'Punjabi',
  'Urdu',
  'Odia',
  'Assamese',
  'Sanskrit',
  'Arabic',
  'French',
  'German',
  'Spanish',
  'Mandarin',
  'Japanese',
  'Other',
];

Future<void> _editLanguageForm(BuildContext context, {int? index}) async {
  final provider = context.read<ResumeProfileProvider>();
  final entry = index != null
      ? provider.profile.languages[index]
      : const LanguageProficiency(
          language: '',
          proficiency: 'Beginner',
          read: false,
          write: false,
          speak: false);
  String? language =
      entry.language.trim().isEmpty ? null : entry.language.trim();
  String proficiency = entry.proficiency;
  bool read = entry.read;
  bool write = entry.write;
  bool speak = entry.speak;
  final formKey = GlobalKey<FormState>();

  await _showSheet<void>(
    context,
    title: index == null ? 'Add language' : 'Edit language',
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (_, setSt) {
          final languageItems = _withCustom(_languages, language);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: language,
                          isExpanded: true,
                          decoration: _decoration(context, 'Language',
                              hint: 'Select a language',
                              icon: Icons.translate_rounded),
                          items: [
                            for (final l in languageItems)
                              DropdownMenuItem(value: l, child: Text(l)),
                          ],
                          onChanged: (v) => setSt(() => language = v),
                          validator: (v) =>
                              v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: proficiency,
                          isExpanded: true,
                          decoration: _decoration(context, 'Proficiency',
                              icon: Icons.star_outline_rounded),
                          items: const [
                            DropdownMenuItem(
                                value: 'Beginner',
                                child: Text('Beginner')),
                            DropdownMenuItem(
                                value: 'Proficient',
                                child: Text('Proficient')),
                            DropdownMenuItem(
                                value: 'Expert', child: Text('Expert')),
                            DropdownMenuItem(
                                value: 'Native', child: Text('Native')),
                          ],
                          onChanged: (v) => setSt(
                              () => proficiency = v ?? 'Beginner'),
                        ),
                        const SizedBox(height: 18),
                        Text('Capabilities',
                            style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _CheckOption(
                                label: 'Read',
                                selected: read,
                                onTap: () => setSt(() => read = !read),
                              ),
                            ),
                            Expanded(
                              child: _CheckOption(
                                label: 'Write',
                                selected: write,
                                onTap: () => setSt(() => write = !write),
                              ),
                            ),
                            Expanded(
                              child: _CheckOption(
                                label: 'Speak',
                                selected: speak,
                                onTap: () => setSt(() => speak = !speak),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _SaveBar(
                onSave: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  await provider.upsertLanguage(
                    LanguageProficiency(
                      language: language ?? '',
                      proficiency: proficiency,
                      read: read,
                      write: write,
                      speak: speak,
                    ),
                    index: index,
                  );
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
              ),
            ],
          );
        },
      );
    },
  );
}

// =============================================================
// Shared list-screen widgets
// =============================================================
PreferredSizeWidget _editorAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: context.scaffoldBg,
    surfaceTintColor: Colors.white,
    elevation: 0,
    foregroundColor: context.textPrimary,
    title: Text(title, style: AppTextStyles.h4),
    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_rounded),
    ),
  );
}

Widget _emptyState(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: context.textTertiary),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete?'),
                      content: const Text('This entry will be removed.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.urgent),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) onDelete();
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.urgent, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

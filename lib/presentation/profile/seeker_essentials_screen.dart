import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_client.dart';
import '../../data/services/locations_data_service.dart';
import '../../data/services/user_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_text.dart';
import '../widgets/auth/staggered_reveal.dart';
import '../widgets/custom_text_field.dart';
import 'resume_pdf_viewer_screen.dart';

// Backend enums for these two fields are lowercase + no spaces; the UI
// pills are Title-Case for readability. These maps translate at the
// boundary so the PATCH passes Zod and incoming values from /auth/me
// render as selected.
const Map<String, String> _kJobTypeApiToLabel = {
  'full-time': 'Full-Time',
  'part-time': 'Part-Time',
  'contract': 'Contract',
  'internship': 'Internship',
  'temporary': 'Temporary',
};
final Map<String, String> _kJobTypeLabelToApi = {
  for (final e in _kJobTypeApiToLabel.entries) e.value: e.key,
};

const Map<String, String> _kWorkModeApiToLabel = {
  'onsite': 'On-site',
  'remote': 'Remote',
  'hybrid': 'Hybrid',
};
final Map<String, String> _kWorkModeLabelToApi = {
  for (final e in _kWorkModeApiToLabel.entries) e.value: e.key,
};

List<String> _toLabels(List<String> apiValues, Map<String, String> map) =>
    apiValues.map((v) => map[v] ?? v).toList();

List<String> _toApi(List<String> labels, Map<String, String> map) =>
    labels.map((l) => map[l] ?? l.toLowerCase()).toList();

/// Standalone "Resume & Essentials" screen. Pushed from the Profile tab
/// — keeps the inline editing experience but off the main Profile so
/// settings, subscription, and other account chrome stay uncluttered.
///
/// All edits go through [UserService.updateProfile] which round-trips
/// `/auth/me` so the auth provider picks up the change immediately.
class SeekerEssentialsScreen extends StatelessWidget {
  const SeekerEssentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: AppText.h3('Resume & Essentials', fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.gradientTop, context.gradientBottom],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: user == null
              ? const Center(child: CircularProgressIndicator())
              : _SeekerEssentialsView(user: user),
        ),
      ),
    );
  }
}

class _SeekerEssentialsView extends StatefulWidget {
  final UserModel user;
  const _SeekerEssentialsView({required this.user});

  @override
  State<_SeekerEssentialsView> createState() => _SeekerEssentialsViewState();
}

class _SeekerEssentialsViewState extends State<_SeekerEssentialsView> {
  final UserService _userService = UserService();
  bool _busy = false;
  String? _busyKey;

  /// Lazily-loaded city/state dataset for the current user's country.
  /// Null until [LocationsDataService.datasetForCurrentUser] resolves;
  /// when null, the locations chip editor falls back to free-text
  /// (no suggestion dropdown) which the user can still manually add.
  LocationsDataset? _locationsDataset;

  @override
  void initState() {
    super.initState();
    // Kick off the dataset load eagerly so the autocomplete is ready
    // by the time the user opens the locations editor. Failures are
    // swallowed — the editor just renders without a dropdown.
    LocationsDataService.instance.datasetForCurrentUser().then((ds) {
      if (!mounted || ds == null) return;
      setState(() => _locationsDataset = ds);
    }).catchError((_) {/* fall through to free-text mode */});
  }

  List<String> _searchLocations(String query, {int max = 8}) {
    final ds = _locationsDataset;
    if (ds == null) return const [];
    return LocationsDataService.search(ds, query, max: max);
  }

  Future<T?> _withBusy<T>(String key, Future<T> Function() fn) async {
    if (_busy) return null;
    setState(() {
      _busy = true;
      _busyKey = key;
    });
    try {
      return await fn();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyKey = null;
        });
      }
    }
  }

  Future<void> _patch({
    String? fullName,
    String? headline,
    List<String>? skills,
    int? experienceYears,
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    List<String>? preferredJobTypes,
    List<String>? preferredRemote,
    int? expectedSalaryMin,
    String? phone,
  }) async {
    await _userService.updateProfile(
      fullName: fullName,
      headline: headline,
      skills: skills,
      experienceYears: experienceYears,
      preferredRoles: preferredRoles,
      preferredLocations: preferredLocations,
      preferredJobTypes: preferredJobTypes,
      preferredRemote: preferredRemote,
      expectedSalaryMin: expectedSalaryMin,
      phone: phone,
    );
    if (mounted) await context.read<AuthProvider>().refreshMe();
  }

  Future<void> _pickAndImportResume() async {
    await _withBusy('resume', () async {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) return;
      final file = File(path);

      try {
        await _userService.uploadResume(file);
      } catch (e) {
        _snack('Upload failed: $e', isError: true);
        return;
      }

      Map<String, dynamic>? parsed;
      try {
        parsed = await _userService.parseResume();
      } catch (_) {
        parsed = null;
      }

      if (parsed == null || parsed.isEmpty) {
        if (!mounted) return;
        await context.read<AuthProvider>().refreshMe();
        _snack('Resume uploaded. Couldn\'t auto-fill — text was empty.');
        return;
      }

      // Map parsed JSON → flat profile fields. The parser returns a
      // Naukri-shaped object; we cherry-pick the keys the matcher uses
      // and skip the rest. Each non-empty parsed value *overrides* the
      // existing profile value so a Replace / delete-then-upload flow
      // fully refreshes the essentials from the new resume.
      final headline = (parsed['headline'] as String?)?.trim();
      final skillsRaw = parsed['skills'];
      final skills = skillsRaw is List
          ? skillsRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : null;
      final experienceYearsRaw = (parsed['experienceYears'] as num?)?.toInt();
      final location = (parsed['location'] as String?)?.trim();
      final phone = (parsed['phone'] as String?)?.trim();
      final preferredLocations = (location != null && location.isNotEmpty)
          ? <String>[location]
          : null;

      // Only count + send fields that actually came back from the parser.
      // experienceYears guarded against 0 — a "didn't find it" answer
      // should never clobber a manually-set years value.
      int filled = 0;
      final headlineToSend =
          (headline != null && headline.isNotEmpty) ? headline : null;
      if (headlineToSend != null) filled++;
      final skillsToSend =
          (skills != null && skills.isNotEmpty) ? skills : null;
      if (skillsToSend != null) filled++;
      final yearsToSend =
          (experienceYearsRaw != null && experienceYearsRaw > 0)
              ? experienceYearsRaw
              : null;
      if (yearsToSend != null) filled++;
      if (preferredLocations != null) filled++;
      final phoneToSend = (phone != null && phone.isNotEmpty) ? phone : null;
      if (phoneToSend != null) filled++;

      if (filled == 0) {
        // Parse returned something but the cherry-picked matcher-fields
        // are all empty (resume had only education/projects, no
        // headline/skills section). The file IS on the server though,
        // so refresh /auth/me to flip the card from "Upload" → "Active"
        // and only THEN show the "nothing new" snackbar. Without this
        // refresh, the screen stays stuck on the empty-upload CTA
        // because Flutter's cached User still has empty resumeText.
        if (mounted) await context.read<AuthProvider>().refreshMe();
        _snack(
          'Resume uploaded — but we couldn\'t extract any essentials. Tap Re-parse with AI to try again.',
        );
        return;
      }

      await _patch(
        headline: headlineToSend,
        skills: skillsToSend,
        experienceYears: yearsToSend,
        preferredLocations: preferredLocations,
        phone: phoneToSend,
      );

      _snack(
        'Resume uploaded — refilled $filled ${filled == 1 ? 'field' : 'fields'} from it.',
      );
    });
  }

  /// Manual "Re-parse" affordance. Sometimes the LLM has a bad first
  /// pass (truncated extraction, partial JSON) — running the parser
  /// again against the already-stored resume text gives the user a
  /// retry that doesn't require re-picking the file. No upload, just
  /// re-parse + re-patch.
  Future<void> _reparseResume() async {
    await _withBusy('reparse', () async {
      Map<String, dynamic>? parsed;
      try {
        parsed = await _userService.parseResume();
      } catch (e) {
        _snack('Re-parse failed: $e', isError: true);
        return;
      }
      if (parsed == null || parsed.isEmpty) {
        _snack('Nothing to re-parse — your resume text looks empty.');
        return;
      }

      final headline = (parsed['headline'] as String?)?.trim();
      final skillsRaw = parsed['skills'];
      final skills = skillsRaw is List
          ? skillsRaw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : null;
      final experienceYears = (parsed['experienceYears'] as num?)?.toInt();
      final location = (parsed['location'] as String?)?.trim();
      final phone = (parsed['phone'] as String?)?.trim();

      int filled = 0;
      final headlineToSend =
          (headline != null && headline.isNotEmpty) ? headline : null;
      if (headlineToSend != null) filled++;
      final skillsToSend =
          (skills != null && skills.isNotEmpty) ? skills : null;
      if (skillsToSend != null) filled++;
      final yearsToSend =
          (experienceYears != null && experienceYears > 0)
              ? experienceYears
              : null;
      if (yearsToSend != null) filled++;
      final locsToSend = (location != null && location.isNotEmpty)
          ? <String>[location]
          : null;
      if (locsToSend != null) filled++;
      final phoneToSend = (phone != null && phone.isNotEmpty) ? phone : null;
      if (phoneToSend != null) filled++;

      if (filled == 0) {
        _snack('Re-parse done — but nothing new came back.');
        return;
      }

      await _patch(
        headline: headlineToSend,
        skills: skillsToSend,
        experienceYears: yearsToSend,
        preferredLocations: locsToSend,
        phone: phoneToSend,
      );
      _snack(
        'Re-parsed — refilled $filled ${filled == 1 ? 'field' : 'fields'}.',
      );
    });
  }

  /// Opens the user's stored resume in an in-app PDF viewer. We render
  /// via pdfx (PDFium) rather than handing the bytes off to the OS —
  /// `launchUrl(Uri.file)` silently failed on iOS (sandboxed file://)
  /// and on Android devices without a default PDF handler installed.
  Future<void> _previewResume() async {
    await _withBusy('preview', () async {
      try {
        final bytes = await _userService.downloadResume();
        if (bytes.isEmpty) {
          _snack('Resume file is empty.', isError: true);
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResumePdfViewerScreen(
              bytes: Uint8List.fromList(bytes),
            ),
          ),
        );
      } on ApiException catch (e) {
        await _handleMissingResume(e, action: 'view');
      } catch (e) {
        _snack('Failed to open: $e', isError: true);
      }
    });
  }

  /// Save the resume PDF to the app's documents directory (visible in
  /// Files app on iOS, accessible via Android `Android/data/<pkg>/files`).
  /// Cross-platform without extra dependencies — no permission prompts
  /// either. Future enhancement: add `share_plus` so a Share sheet lets
  /// the user route the file to Drive, email, or the system Downloads.
  Future<void> _downloadResume() async {
    await _withBusy('download', () async {
      try {
        final bytes = await _userService.downloadResume();
        if (bytes.isEmpty) {
          _snack('Resume file is empty.', isError: true);
          return;
        }
        final dir = await getApplicationDocumentsDirectory();
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/resume_$stamp.pdf');
        await file.writeAsBytes(bytes, flush: true);
        _snack('Saved to ${file.path}');
      } on ApiException catch (e) {
        await _handleMissingResume(e, action: 'download');
      } catch (e) {
        _snack('Download failed: $e', isError: true);
      }
    });
  }

  /// Shared 404/410 handler for the View / Download paths. When the
  /// server says "no resume on file" but the local UI still thinks the
  /// resume is active (because resumeText survived without resumeFile
  /// in some legacy upload state), refresh /auth/me so the next render
  /// matches reality and surface a friendly "re-upload" prompt instead
  /// of leaking the raw 404.
  Future<void> _handleMissingResume(
    ApiException e, {
    required String action,
  }) async {
    if (e.statusCode == 404 || e.statusCode == 410) {
      if (mounted) await context.read<AuthProvider>().refreshMe();
      _snack(
        'Resume file isn\'t on our servers — please upload again.',
        isError: true,
      );
      return;
    }
    _snack('Failed to $action: ${e.message}', isError: true);
  }

  Future<void> _deleteResume() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove resume?'),
        content: const Text(
          'You\'ll need to re-upload to apply for jobs and enable auto-apply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _withBusy('resume', () async {
      try {
        await _userService.deleteResume();
        if (mounted) await context.read<AuthProvider>().refreshMe();
        _snack('Resume removed.');
      } on ApiException catch (e) {
        // 404 = server already lost track of the file (legacy state
        // where resumeText survived without resumeFile). The backend
        // delete handler now sweeps every resume-related field even on
        // partial state, so we treat both 200 and 404 as success: pull
        // fresh /auth/me so the UI catches up.
        if (e.statusCode == 404 || e.statusCode == 410) {
          if (mounted) await context.read<AuthProvider>().refreshMe();
          _snack('Resume cleared.');
          return;
        }
        _snack('Failed to remove: ${e.message}', isError: true);
      } catch (e) {
        _snack('Failed to remove: $e', isError: true);
      }
    });
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? AppColors.urgent : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2200),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final hasResume = (u.resumeText ?? '').trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(
            duration: const Duration(milliseconds: 520),
            child: _ResumeCard(
              hasResume: hasResume,
              busy: _busy && _busyKey == 'resume',
              previewBusy: _busy && _busyKey == 'preview',
              reparseBusy: _busy && _busyKey == 'reparse',
              downloadBusy: _busy && _busyKey == 'download',
              onUpload: _busy ? null : _pickAndImportResume,
              onPreview: (_busy || !hasResume) ? null : _previewResume,
              onDownload: (_busy || !hasResume) ? null : _downloadResume,
              onReparse: (_busy || !hasResume) ? null : _reparseResume,
              onRemove: _busy ? null : _deleteResume,
            ),
          ),
          const SizedBox(height: 22),
          _SectionLabel(label: 'Essentials', icon: Icons.tune_rounded),
          const SizedBox(height: 10),
          StaggeredReveal(
            delay: const Duration(milliseconds: 80),
            child: _EssentialRow(
              icon: Icons.badge_outlined,
              label: 'Headline',
              value: u.headline.isEmpty ? null : u.headline,
              placeholder: 'e.g. Senior Flutter Developer',
              onEdit: () => _openTextEditor(
                title: 'Headline',
                hint: 'e.g. Senior Flutter Developer',
                initial: u.headline,
                max: 80,
                onSave: (v) => _patch(headline: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 130),
            child: _ChipsRow(
              icon: Icons.star_outline_rounded,
              label: 'Skills',
              values: u.skills,
              placeholder: 'Add the tech you know',
              onEdit: () => _openChipsEditor(
                title: 'Skills',
                hint: 'e.g. Flutter, Dart, REST',
                initial: u.skills,
                onSave: (v) => _patch(skills: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 180),
            child: _NumberRow(
              icon: Icons.timeline_rounded,
              label: 'Experience',
              valueText: u.experienceYears == 0
                  ? null
                  : '${u.experienceYears} ${u.experienceYears == 1 ? 'year' : 'years'}',
              placeholder: 'How many years?',
              onEdit: () => _openNumberEditor(
                title: 'Experience (years)',
                initial: u.experienceYears,
                onSave: (v) => _patch(experienceYears: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 230),
            child: _ChipsRow(
              icon: Icons.work_outline_rounded,
              label: 'Roles you want',
              values: u.preferredRoles,
              placeholder: 'e.g. Mobile Developer',
              onEdit: () => _openChipsEditor(
                title: 'Roles you want',
                hint: 'e.g. Mobile Developer',
                initial: u.preferredRoles,
                onSave: (v) => _patch(preferredRoles: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 280),
            child: _ChipsRow(
              icon: Icons.location_on_outlined,
              label: 'Locations',
              values: u.preferredLocations,
              placeholder: 'Cities, states or "Remote"',
              onEdit: () => _openChipsEditor(
                title: 'Preferred locations',
                hint: 'Type at least 3 letters…',
                initial: u.preferredLocations,
                suggestions: _searchLocations,
                minCharsForSuggestions: 3,
                onSave: (v) => _patch(preferredLocations: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 330),
            child: _MultiPickRow(
              icon: Icons.schedule_rounded,
              label: 'Job type',
              options: const ['Full-Time', 'Part-Time', 'Contract', 'Internship'],
              selected: _toLabels(u.preferredJobTypes, _kJobTypeApiToLabel),
              onChanged: (v) => _patch(
                preferredJobTypes: _toApi(v, _kJobTypeLabelToApi),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 380),
            child: _MultiPickRow(
              icon: Icons.home_work_outlined,
              label: 'Work mode',
              options: const ['On-site', 'Remote', 'Hybrid'],
              selected: _toLabels(u.preferredRemote, _kWorkModeApiToLabel),
              onChanged: (v) => _patch(
                preferredRemote: _toApi(v, _kWorkModeLabelToApi),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 430),
            child: _NumberRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Expected salary',
              valueText: u.expectedSalaryMin == null
                  ? null
                  : '₹ ${_formatLakhs(u.expectedSalaryMin!)}',
              placeholder: 'Minimum CTC (optional)',
              onEdit: () => _openNumberEditor(
                title: 'Minimum expected salary',
                initial: u.expectedSalaryMin ?? 0,
                hint: 'Annual, in ₹',
                onSave: (v) => _patch(expectedSalaryMin: v),
              ),
            ),
          ),
          const _RowGap(),
          StaggeredReveal(
            delay: const Duration(milliseconds: 480),
            child: _EssentialRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: u.phone.isEmpty ? null : u.phone,
              placeholder: 'For recruiter contact',
              onEdit: () => _openTextEditor(
                title: 'Phone number',
                hint: '+91 98765 43210',
                initial: u.phone,
                keyboardType: TextInputType.phone,
                max: 20,
                onSave: (v) => _patch(phone: v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTextEditor({
    required String title,
    required String hint,
    required String initial,
    required Future<void> Function(String) onSave,
    TextInputType? keyboardType,
    int max = 100,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditorSheet(
        title: title,
        onSave: () async {
          final v = ctrl.text.trim();
          if (v == initial) return true;
          try {
            await onSave(v);
            return true;
          } catch (e) {
            _snack('Save failed: $e', isError: true);
            return false;
          }
        },
        child: CustomTextField(
          controller: ctrl,
          label: title,
          hint: hint,
          keyboardType: keyboardType ?? TextInputType.text,
          maxLength: max,
        ),
      ),
    );
    ctrl.dispose();
    if (saved == true) _snack('$title saved.');
  }

  Future<void> _openNumberEditor({
    required String title,
    required int initial,
    String? hint,
    required Future<void> Function(int) onSave,
  }) async {
    final ctrl =
        TextEditingController(text: initial == 0 ? '' : initial.toString());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditorSheet(
        title: title,
        onSave: () async {
          final v = int.tryParse(ctrl.text.trim()) ?? 0;
          if (v == initial) return true;
          try {
            await onSave(v);
            return true;
          } catch (e) {
            _snack('Save failed: $e', isError: true);
            return false;
          }
        },
        child: CustomTextField(
          controller: ctrl,
          label: title,
          hint: hint ?? 'Enter a number',
          keyboardType: TextInputType.number,
        ),
      ),
    );
    ctrl.dispose();
    if (saved == true) _snack('$title saved.');
  }

  Future<void> _openChipsEditor({
    required String title,
    required String hint,
    required List<String> initial,
    required Future<void> Function(List<String>) onSave,
    List<String> Function(String query, {int max})? suggestions,
    int minCharsForSuggestions = 3,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChipsEditorSheet(
        title: title,
        hint: hint,
        initial: List<String>.from(initial),
        suggestions: suggestions,
        minCharsForSuggestions: minCharsForSuggestions,
        onSave: (next) async {
          try {
            await onSave(next);
            return true;
          } catch (e) {
            _snack('Save failed: $e', isError: true);
            return false;
          }
        },
      ),
    );
    if (saved == true) _snack('$title saved.');
  }
}

// ---------------------------------------------------------------------------
//  Resume card
// ---------------------------------------------------------------------------

class _ResumeCard extends StatelessWidget {
  final bool hasResume;
  final bool busy;
  final bool previewBusy;
  final bool reparseBusy;
  final bool downloadBusy;
  final VoidCallback? onUpload;
  final VoidCallback? onPreview;
  final VoidCallback? onDownload;
  final VoidCallback? onReparse;
  final VoidCallback? onRemove;
  const _ResumeCard({
    required this.hasResume,
    required this.busy,
    required this.previewBusy,
    required this.reparseBusy,
    required this.downloadBusy,
    required this.onUpload,
    required this.onPreview,
    required this.onDownload,
    required this.onReparse,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) return _buildBusy(context);
    return hasResume ? _buildPresent(context) : _buildEmpty(context);
  }

  Widget _buildBusy(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: _baseDecoration(context),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h4('Reading your resume…',
                    fontWeight: FontWeight.w800),
                const SizedBox(height: 2),
                AppText.caption(
                  'Uploading + extracting your details with AI.',
                  color: context.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return PressScale(
      onTap: onUpload,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.14),
              AppColors.primary.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.h4(
                    'Upload your resume',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                  const SizedBox(height: 2),
                  AppText.caption(
                    'PDF, DOC or DOCX. We\'ll auto-fill the rest.',
                    color: context.textSecondary,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary.withValues(alpha: 0.8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _baseDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon tile + title + Active badge inline (no wrap)
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppText.body(
                  'Your resume',
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 11, color: AppColors.success),
                    const SizedBox(width: 3),
                    AppText.caption(
                      'Active',
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Primary CTA — View resume. People hit View 10x more than any
          // other action, so it gets full-width gradient prominence.
          _ResumePrimaryButton(
            icon: Icons.visibility_rounded,
            label: 'View resume',
            busy: previewBusy,
            onTap: onPreview,
          ),
          const SizedBox(height: 8),
          // Secondary inline row — compact pills with icon + label so
          // each affordance is self-explanatory without taking space.
          // Remove sits at the right as the destructive outlier.
          Row(
            children: [
              Expanded(
                child: _ResumeSecondaryButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  busy: downloadBusy,
                  onTap: onDownload,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ResumeSecondaryButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Replace',
                  onTap: onUpload,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ResumeSecondaryButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Re-parse',
                  busy: reparseBusy,
                  onTap: onReparse,
                ),
              ),
              const SizedBox(width: 6),
              _ResumeSecondaryButton(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                destructive: true,
                onTap: onRemove,
                iconOnly: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _baseDecoration(BuildContext context) => BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

/// Full-width primary CTA for the resume card. Filled with the brand
/// gradient — anchors the card visually and signals "this is the thing
/// you came here to do" (View resume is hit ~10× more than any other
/// action on this screen).
class _ResumePrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  const _ResumePrimaryButton({
    required this.icon,
    required this.label,
    this.busy = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return PressScale(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action — icon + short label by default, or pure
/// icon with tooltip when [iconOnly] is true (used for Remove so the
/// destructive tone reads without dominating the row width). Disabled
/// state dims both icon and text uniformly.
class _ResumeSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final bool busy;
  final bool iconOnly;
  final VoidCallback? onTap;
  const _ResumeSecondaryButton({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.busy = false,
    this.iconOnly = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.urgent : AppColors.primary;
    final enabled = onTap != null && !busy;
    return Tooltip(
      message: iconOnly ? label : '',
      child: PressScale(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 9 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.22 : 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 15,
                  color: color.withValues(alpha: enabled ? 1 : 0.5),
                ),
              if (!iconOnly) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color.withValues(alpha: enabled ? 1 : 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Essential rows (text, chips, number, multi-pick)
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: context.textTertiary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowGap extends StatelessWidget {
  const _RowGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

String _formatLakhs(int n) {
  if (n <= 0) return '0';
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final restWithCommas = rest.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
    (m) => '${m.group(1)},',
  );
  return '$restWithCommas,$last3';
}

class _EssentialRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onEdit;
  const _EssentialRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.trim().isNotEmpty;
    return PressScale(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: _rowDecoration(context),
        child: Row(
          children: [
            _RowIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filled ? value! : placeholder,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          filled ? FontWeight.w600 : FontWeight.w500,
                      color: filled
                          ? context.textPrimary
                          : context.textTertiary,
                      fontStyle:
                          filled ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              filled ? Icons.edit_outlined : Icons.add_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;
  final String placeholder;
  final VoidCallback onEdit;
  const _ChipsRow({
    required this.icon,
    required this.label,
    required this.values,
    required this.placeholder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final filled = values.isNotEmpty;
    return PressScale(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: _rowDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RowIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (filled)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in values.take(8)) _ValueChip(label: v),
                        if (values.length > 8)
                          _ValueChip(label: '+${values.length - 8}'),
                      ],
                    )
                  else
                    Text(
                      placeholder,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: context.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                filled ? Icons.edit_outlined : Icons.add_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  const _ValueChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? valueText;
  final String placeholder;
  final VoidCallback onEdit;
  const _NumberRow({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.placeholder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _EssentialRow(
      icon: icon,
      label: label,
      value: valueText,
      placeholder: placeholder,
      onEdit: onEdit,
    );
  }
}

class _MultiPickRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<String> options;
  final List<String> selected;
  final Future<void> Function(List<String>) onChanged;
  const _MultiPickRow({
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_MultiPickRow> createState() => _MultiPickRowState();
}

class _MultiPickRowState extends State<_MultiPickRow> {
  /// Optimistic copy of the selection. Tapping a chip flips this *first*
  /// so the pill animates to its selected state instantly; the network
  /// PATCH + refreshMe runs in the background. Without this, every tap
  /// has a 200-600ms lag where the chip looks unchanged and the user
  /// concludes the row is read-only.
  late List<String> _local;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _local = List<String>.from(widget.selected);
  }

  @override
  void didUpdateWidget(covariant _MultiPickRow old) {
    super.didUpdateWidget(old);
    // Sync from props whenever the backend echo lands — but skip while a
    // save is in flight so we don't briefly snap back to the pre-PATCH
    // value between optimistic flip and refreshMe completing.
    if (!_saving && !_listEq(old.selected, widget.selected)) {
      _local = List<String>.from(widget.selected);
    }
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _toggle(String opt) async {
    final next = List<String>.from(_local);
    if (next.contains(opt)) {
      next.remove(opt);
    } else {
      next.add(opt);
    }
    setState(() {
      _local = next;
      _saving = true;
    });
    try {
      await widget.onChanged(next);
    } catch (_) {
      // Roll back the optimistic flip if the save fails — the parent
      // already surfaces the error via its own snackbar.
      if (mounted) {
        setState(() => _local = List<String>.from(widget.selected));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: _rowDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIcon(icon: widget.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· tap to choose',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textSecondary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    if (_saving)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final opt in widget.options)
                      _SelectableChip(
                        label: opt,
                        selected: _local.contains(opt),
                        onTap: () => _toggle(opt),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.22),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  const _RowIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: AppColors.primary),
    );
  }
}

BoxDecoration _rowDecoration(BuildContext context) => BoxDecoration(
      color: context.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: context.cardBorder),
    );

// ---------------------------------------------------------------------------
//  Editor bottom sheets
// ---------------------------------------------------------------------------

class _EditorSheet extends StatefulWidget {
  final String title;
  final Widget child;
  final Future<bool> Function() onSave;
  const _EditorSheet({
    required this.title,
    required this.child,
    required this.onSave,
  });

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppText.h3(widget.title, fontWeight: FontWeight.w800),
              const SizedBox(height: 16),
              widget.child,
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chips editor with optional autocomplete. When [suggestions] is non-null
/// and the typed query is >= [minCharsForSuggestions], a dropdown of
/// matching values appears below the input — tapping one adds it as a
/// chip without typing the whole name.
class _ChipsEditorSheet extends StatefulWidget {
  final String title;
  final String hint;
  final List<String> initial;
  final Future<bool> Function(List<String>) onSave;
  final List<String> Function(String query, {int max})? suggestions;
  final int minCharsForSuggestions;
  const _ChipsEditorSheet({
    required this.title,
    required this.hint,
    required this.initial,
    required this.onSave,
    this.suggestions,
    this.minCharsForSuggestions = 3,
  });

  @override
  State<_ChipsEditorSheet> createState() => _ChipsEditorSheetState();
}

class _ChipsEditorSheetState extends State<_ChipsEditorSheet> {
  late final List<String> _items = List<String>.from(widget.initial);
  final TextEditingController _ctrl = TextEditingController();
  bool _saving = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final next = _ctrl.text;
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addValue(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (_items.contains(v)) {
      _ctrl.clear();
      return;
    }
    setState(() {
      _items.add(v);
      _ctrl.clear();
    });
  }

  void _add() => _addValue(_ctrl.text);

  void _remove(String v) => setState(() => _items.remove(v));

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_items);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  List<String> _activeSuggestions() {
    final fn = widget.suggestions;
    if (fn == null) return const [];
    final q = _query.trim();
    if (q.length < widget.minCharsForSuggestions) return const [];
    final raw = fn(q, max: 8);
    return raw.where((s) => !_items.contains(s)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final suggestions = _activeSuggestions();
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppText.h3(widget.title, fontWeight: FontWeight.w800),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _ctrl,
                      hint: widget.hint,
                      onSubmitted: (_) => _add(),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              // Autocomplete dropdown — only when the caller supplied a
              // suggestion source AND the query is long enough.
              if (widget.suggestions != null)
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: suggestions.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _SuggestionsDropdown(
                            options: suggestions,
                            onPick: _addValue,
                          ),
                        ),
                ),
              const SizedBox(height: 14),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    widget.suggestions != null
                        ? 'Type at least ${widget.minCharsForSuggestions} letters to see matches, or add your own.'
                        : 'Add one by one. Tap × on a chip to remove it.',
                    style: TextStyle(
                      color: context.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        for (final v in _items)
                          _EditableChip(
                            label: v,
                            onRemove: () => _remove(v),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Save ${_items.length}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionsDropdown extends StatelessWidget {
  final List<String> options;
  final ValueChanged<String> onPick;
  const _SuggestionsDropdown({required this.options, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: options.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            color: context.divider.withValues(alpha: 0.5),
          ),
          itemBuilder: (_, i) {
            final v = options[i];
            return InkWell(
              onTap: () => onPick(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _EditableChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/resume_profile_model.dart';
import '../data/models/user_model.dart';
import '../data/services/storage_service.dart';
import '../data/services/user_service.dart';

/// Result of an end-to-end resume upload + auto-fill attempt.
class ResumeImportResult {
  /// True iff the upload succeeded. Auto-fill failure is non-fatal and
  /// still returns ok=true with [fieldsFilled] = 0.
  final bool ok;

  /// Number of profile sections that got new data from the parser. Zero
  /// when the resume couldn't be read (scanned PDF) or all fields were
  /// already filled — the UI should render different copy in each case.
  final int fieldsFilled;

  /// True when the parser ran but returned nothing (e.g. scanned PDF).
  final bool parseEmpty;

  /// Error string for upload failures only — auto-fill failures are
  /// swallowed so the user still keeps their successfully-uploaded resume.
  final String? error;

  const ResumeImportResult({
    required this.ok,
    this.fieldsFilled = 0,
    this.parseEmpty = false,
    this.error,
  });
}

class ResumeProfileProvider extends ChangeNotifier {
  ResumeProfile _profile = ResumeProfile.initial;
  bool _loaded = false;
  bool _syncing = false;

  ResumeProfile get profile => _profile;
  bool get loaded => _loaded;

  Future<void> load() async {
    final stored = StorageService.getResumeProfile();
    _profile = stored ?? ResumeProfile.initial;
    _loaded = true;
    notifyListeners();
  }

  /// Pull whatever the authenticated user has filled in on the backend
  /// (onboarding answers, parsed resume) into the local resume profile —
  /// but only into fields that are still empty here. Never overwrites a
  /// value the user has already edited locally. Safe to call repeatedly.
  void seedFromUserIfEmpty(UserModel? user) {
    if (user == null) return;
    var next = _profile;
    var changed = false;

    if (next.resumeHeadline.isEmpty && user.headline.isNotEmpty) {
      next = next.copyWith(resumeHeadline: user.headline);
      changed = true;
    }
    if (next.keySkills.isEmpty && user.skills.isNotEmpty) {
      next = next.copyWith(keySkills: List.unmodifiable(user.skills));
      changed = true;
    }
    if (next.experience.isEmpty && user.experienceYears > 0) {
      final y = user.experienceYears;
      next = next.copyWith(
        experience: '$y ${y == 1 ? 'Year' : 'Years'}',
        expYears: y,
      );
      changed = true;
    }
    if (next.location.isEmpty && user.preferredLocations.isNotEmpty) {
      next = next.copyWith(location: user.preferredLocations.first);
      changed = true;
    }
    final salary = user.expectedSalaryMin ?? 0;
    if (next.careerProfile.expectedSalary.isEmpty && salary > 0) {
      next = next.copyWith(
        careerProfile: next.careerProfile.copyWith(
          expectedSalary: '₹${_formatIndianNumber(salary)}',
        ),
      );
      changed = true;
    }
    if (next.careerProfile.preferredLocation.isEmpty &&
        user.preferredLocations.isNotEmpty) {
      next = next.copyWith(
        careerProfile: next.careerProfile.copyWith(
          preferredLocation: user.preferredLocations.join(', '),
        ),
      );
      changed = true;
    }

    if (changed) _persist(next);
  }

  /// Pull resume metadata + parsed fields from the backend on screen open.
  ///
  /// Two reasons this exists despite onboarding already calling
  /// [importResume]:
  ///   1. Local app storage can be wiped (reinstall, fresh device, "clear
  ///      data") while the backend still holds the resume in Cloudinary —
  ///      without this sync, the "My Resume" card would show empty even
  ///      though the file is on the server.
  ///   2. The Claude parse result is only ever applied to local state.
  ///      If the parse failed at upload time but text-extraction
  ///      succeeded server-side, opening this screen later gets a fresh
  ///      shot at filling employments / educations / IT skills / projects
  ///      / summary from the same stored resume text.
  ///
  /// Re-entry guarded — the screen can call this on every initState
  /// without thrashing the network.
  Future<void> syncFromBackend() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final userService = UserService();

      Map<String, dynamic>? meta;
      try {
        meta = await userService.getResumeMeta();
      } catch (_) {
        meta = null;
      }
      final fileMeta = meta?['file'];
      if (fileMeta is! Map<String, dynamic>) return;

      final originalName = (fileMeta['originalName'] as String? ?? '').trim();
      final size = (fileMeta['size'] as num?)?.toInt() ?? 0;
      final uploadedAtIso =
          (fileMeta['uploadedAt'] as String? ?? '').trim();

      // Sync local meta + downloaded copy when missing. We deliberately
      // don't overwrite a fresher local copy — the picker flow writes the
      // file to disk and updates these fields synchronously, so a sync
      // racing alongside it should leave them alone.
      if (_profile.resumeFileName.isEmpty && originalName.isNotEmpty) {
        String formattedDate = '';
        if (uploadedAtIso.isNotEmpty) {
          try {
            final dt = DateTime.parse(uploadedAtIso).toLocal();
            formattedDate = DateFormat('MMM d, yyyy').format(dt);
          } catch (_) {}
        }

        // Best-effort: download the file so the View button works. A
        // failure here shouldn't block meta + auto-fill below.
        String localPath = '';
        try {
          final bytes = await userService.downloadResume();
          if (bytes.isNotEmpty) {
            final docs = await getApplicationDocumentsDirectory();
            final destDir = Directory('${docs.path}/resumes');
            if (!destDir.existsSync()) destDir.createSync(recursive: true);
            final stamp = DateTime.now().millisecondsSinceEpoch;
            final safeName =
                originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
            final dest = File('${destDir.path}/$stamp-$safeName');
            await dest.writeAsBytes(bytes);
            localPath = dest.path;
          }
        } catch (_) {}

        await _persist(_profile.copyWith(
          resumeFileName: originalName,
          resumeFilePath: localPath,
          resumeSizeBytes: size > 0 ? size : _profile.resumeSizeBytes,
          resumeUploadedOn: formattedDate,
        ));
      }

      // Trigger backend parse only when there's something to fill.
      // applyParsedResume is itself idempotent — it only writes into
      // empty fields — but skipping the network call when everything is
      // already populated saves a Claude round-trip on every screen open.
      final needsAutoFill = _profile.resumeHeadline.isEmpty ||
          _profile.profileSummary.isEmpty ||
          _profile.keySkills.isEmpty ||
          _profile.employments.isEmpty ||
          _profile.educations.isEmpty ||
          _profile.itSkills.isEmpty ||
          _profile.projects.isEmpty;
      if (!needsAutoFill) return;

      Map<String, dynamic>? parsed;
      try {
        parsed = await userService.parseResume();
      } catch (_) {
        parsed = null;
      }
      if (parsed != null && parsed.isNotEmpty) {
        await applyParsedResume(parsed);
      }
    } finally {
      _syncing = false;
    }
  }

  /// Merge structured fields returned by the backend resume parser into
  /// the local profile. Like [seedFromUserIfEmpty], this only writes into
  /// fields the user hasn't already filled. List fields (employments,
  /// educations, etc.) are only written when the local list is empty —
  /// we don't try to merge by identity, since the parser has no concept
  /// of which entries the user already typed.
  ///
  /// Returns the count of fields actually populated, so the UI can tell
  /// the user "Auto-filled 7 fields from your resume".
  Future<int> applyParsedResume(Map<String, dynamic> parsed) async {
    var next = _profile;
    var filled = 0;

    String s(String key) {
      final v = parsed[key];
      return v is String ? v.trim() : '';
    }

    List<String> sList(String key) {
      final v = parsed[key];
      if (v is! List) return const [];
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    List<Map<String, dynamic>> mList(String key) {
      final v = parsed[key];
      if (v is! List) return const [];
      return v.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    final headline = s('headline');
    if (next.resumeHeadline.isEmpty && headline.isNotEmpty) {
      next = next.copyWith(resumeHeadline: headline);
      filled++;
    }

    final summary = s('summary');
    if (next.profileSummary.isEmpty && summary.isNotEmpty) {
      next = next.copyWith(profileSummary: summary);
      filled++;
    }

    final skills = sList('skills');
    if (next.keySkills.isEmpty && skills.isNotEmpty) {
      next = next.copyWith(keySkills: List.unmodifiable(skills));
      filled++;
    }

    final yearsRaw = parsed['experienceYears'];
    final years = yearsRaw is num ? yearsRaw.toInt() : 0;
    if (next.experience.isEmpty && years > 0) {
      next = next.copyWith(
        experience: '$years ${years == 1 ? 'Year' : 'Years'}',
        expYears: years,
      );
      filled++;
    }

    final location = s('location');
    if (next.location.isEmpty && location.isNotEmpty) {
      next = next.copyWith(location: location);
      filled++;
    }

    final employments = mList('employments');
    if (next.employments.isEmpty && employments.isNotEmpty) {
      next = next.copyWith(
        employments: employments
            .map((e) => EmploymentEntry(
                  designation: (e['designation'] as String? ?? '').trim(),
                  company: (e['company'] as String? ?? '').trim(),
                  period: (e['period'] as String? ?? '').trim(),
                  current: e['current'] == true,
                ))
            .where((e) =>
                e.designation.isNotEmpty || e.company.isNotEmpty)
            .toList(),
      );
      filled++;
    }

    final educations = mList('educations');
    if (next.educations.isEmpty && educations.isNotEmpty) {
      next = next.copyWith(
        educations: educations
            .map((e) => EducationEntry(
                  degree: (e['degree'] as String? ?? '').trim(),
                  institute: (e['institute'] as String? ?? '').trim(),
                  period: (e['period'] as String? ?? '').trim(),
                  type: ((e['type'] as String?)?.trim().isNotEmpty ?? false)
                      ? (e['type'] as String).trim()
                      : 'Full Time',
                ))
            .where((e) => e.degree.isNotEmpty || e.institute.isNotEmpty)
            .toList(),
      );
      filled++;
    }

    final itSkills = mList('itSkills');
    if (next.itSkills.isEmpty && itSkills.isNotEmpty) {
      next = next.copyWith(
        itSkills: itSkills
            .map((e) => ITSkill(
                  skill: (e['skill'] as String? ?? '').trim(),
                  version: '-',
                  lastUsed: (e['lastUsed'] as String? ?? '').trim(),
                  experience: (e['experience'] as String? ?? '').trim(),
                ))
            .where((e) => e.skill.isNotEmpty)
            .toList(),
      );
      filled++;
    }

    final projects = mList('projects');
    if (next.projects.isEmpty && projects.isNotEmpty) {
      next = next.copyWith(
        projects: projects
            .map((e) => ProjectEntry(
                  title: (e['title'] as String? ?? '').trim(),
                  company: (e['company'] as String? ?? '').trim(),
                  type: ((e['type'] as String?)?.trim().isNotEmpty ?? false)
                      ? (e['type'] as String).trim()
                      : 'Full Time',
                  period: (e['period'] as String? ?? '').trim(),
                  description: (e['description'] as String? ?? '').trim(),
                ))
            .where((e) => e.title.isNotEmpty)
            .toList(),
      );
      filled++;
    }

    final languages = mList('languages');
    if (next.languages.isEmpty && languages.isNotEmpty) {
      next = next.copyWith(
        languages: languages
            .map((e) => LanguageProficiency(
                  language: (e['language'] as String? ?? '').trim(),
                  proficiency: (e['proficiency'] as String? ?? '').trim().isEmpty
                      ? 'Intermediate'
                      : (e['proficiency'] as String).trim(),
                  read: true,
                  write: true,
                  speak: true,
                ))
            .where((e) => e.language.isNotEmpty)
            .toList(),
      );
      filled++;
    }

    final personal = parsed['personalDetails'];
    if (personal is Map<String, dynamic>) {
      final cur = next.personalDetails;
      final dob = (personal['dob'] as String? ?? '').trim();
      final address = (personal['address'] as String? ?? '').trim();
      final gender = (personal['gender'] as String? ?? '').trim();
      final marital = (personal['maritalStatus'] as String? ?? '').trim();
      var personalChanged = false;
      var updated = cur;
      if (cur.dob.isEmpty && dob.isNotEmpty) {
        updated = updated.copyWith(dob: dob);
        personalChanged = true;
      }
      if (cur.address.isEmpty && address.isNotEmpty) {
        updated = updated.copyWith(address: address);
        personalChanged = true;
      }
      if (cur.gender.isEmpty && gender.isNotEmpty) {
        updated = updated.copyWith(gender: gender);
        personalChanged = true;
      }
      if (cur.maritalStatus.isEmpty && marital.isNotEmpty) {
        updated = updated.copyWith(maritalStatus: marital);
        personalChanged = true;
      }
      if (personalChanged) {
        next = next.copyWith(personalDetails: updated);
        filled++;
      }
    }

    if (filled > 0) await _persist(next);
    return filled;
  }

  /// One-shot upload + parse + auto-fill, used by both the onboarding
  /// flow and the profile editor. Centralised so both call sites get
  /// identical behaviour: resume saved on the server, structured fields
  /// merged into the local profile only when they're empty.
  ///
  /// Auto-fill is best-effort — a parse failure or empty parse never
  /// fails the upload itself, since the resume PDF is still useful for
  /// applications even if the AI couldn't read it.
  Future<ResumeImportResult> importResume(File file) async {
    final userService = UserService();
    try {
      await userService.uploadResume(file);
    } catch (e) {
      return ResumeImportResult(ok: false, error: e.toString());
    }

    // Persist a local copy + meta so the "My Resume" card renders
    // immediately after onboarding upload. The picker flow in
    // resume_editors.dart updates these fields itself before reaching
    // here, but onboarding calls us directly — without this, the card
    // stayed empty until the next syncFromBackend round-trip.
    try {
      final originalName = file.path.split(Platform.pathSeparator).last;
      final docs = await getApplicationDocumentsDirectory();
      final destDir = Directory('${docs.path}/resumes');
      if (!destDir.existsSync()) destDir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final safeName =
          originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final dest = File('${destDir.path}/$stamp-$safeName');
      // Skip the copy when the picker already wrote into our docs/resumes
      // dir (the My-Profile flow does that itself).
      final alreadyLocal = file.path.startsWith(destDir.path);
      final stored = alreadyLocal ? file : await file.copy(dest.path);
      final size = await stored.length();
      final today = DateFormat('MMM d, yyyy').format(DateTime.now());
      await _persist(_profile.copyWith(
        resumeFileName: originalName,
        resumeFilePath: stored.path,
        resumeSizeBytes: size,
        resumeUploadedOn: today,
      ));
    } catch (_) {
      // Non-fatal — the upload itself succeeded and syncFromBackend will
      // recover the meta on the next screen open.
    }

    Map<String, dynamic>? parsed;
    try {
      parsed = await userService.parseResume();
    } catch (_) {
      parsed = null;
    }

    if (parsed == null || parsed.isEmpty) {
      return const ResumeImportResult(ok: true, parseEmpty: true);
    }

    final filled = await applyParsedResume(parsed);
    return ResumeImportResult(ok: true, fieldsFilled: filled);
  }

  // Indian-grouping comma formatter: 600000 → 6,00,000
  String _formatIndianNumber(int n) {
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

  Future<void> _persist(ResumeProfile next) async {
    _profile = next;
    notifyListeners();
    await StorageService.saveResumeProfile(next);
  }

  Future<void> updateHeader({
    String? location,
    String? experience,
    String? currentSalary,
    String? availability,
  }) {
    return _persist(_profile.copyWith(
      location: location,
      experience: experience,
      currentSalary: currentSalary,
      availability: availability,
    ));
  }

  Future<void> updateBasicDetails({
    required String workStatus,
    required int expYears,
    required int expMonths,
    required String experience,
    required String currency,
    required String salaryAmount,
    required String currentSalary,
    required String salaryBreakdown,
    required String locationType,
    required String locationCity,
    required String locationCountry,
    required String location,
    required String telephoneCountry,
    required String telephoneArea,
    required String telephonePhone,
    required String availability,
  }) {
    return _persist(_profile.copyWith(
      workStatus: workStatus,
      expYears: expYears,
      expMonths: expMonths,
      experience: experience,
      currency: currency,
      salaryAmount: salaryAmount,
      currentSalary: currentSalary,
      salaryBreakdown: salaryBreakdown,
      locationType: locationType,
      locationCity: locationCity,
      locationCountry: locationCountry,
      location: location,
      telephoneCountry: telephoneCountry,
      telephoneArea: telephoneArea,
      telephonePhone: telephonePhone,
      availability: availability,
    ));
  }

  Future<void> updateResume({
    required String fileName,
    required String filePath,
    required int sizeBytes,
    required String uploadedOn,
  }) {
    return _persist(_profile.copyWith(
      resumeFileName: fileName,
      resumeFilePath: filePath,
      resumeSizeBytes: sizeBytes,
      resumeUploadedOn: uploadedOn,
    ));
  }

  Future<void> deleteResume() {
    return _persist(_profile.copyWith(
      resumeFileName: '',
      resumeFilePath: '',
      resumeSizeBytes: 0,
      resumeUploadedOn: '',
    ));
  }

  Future<void> updateHeadline(String headline) {
    return _persist(_profile.copyWith(resumeHeadline: headline));
  }

  Future<void> updateSummary(String summary) {
    return _persist(_profile.copyWith(profileSummary: summary));
  }

  Future<void> updateKeySkills(List<String> skills) {
    return _persist(_profile.copyWith(keySkills: List.unmodifiable(skills)));
  }

  Future<void> upsertEmployment(EmploymentEntry entry, {int? index}) {
    final list = List<EmploymentEntry>.from(_profile.employments);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return _persist(_profile.copyWith(employments: list));
  }

  Future<void> deleteEmployment(int index) {
    final list = List<EmploymentEntry>.from(_profile.employments)
      ..removeAt(index);
    return _persist(_profile.copyWith(employments: list));
  }

  Future<void> upsertEducation(EducationEntry entry, {int? index}) {
    final list = List<EducationEntry>.from(_profile.educations);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = entry;
    } else {
      list.add(entry);
    }
    return _persist(_profile.copyWith(educations: list));
  }

  Future<void> deleteEducation(int index) {
    final list = List<EducationEntry>.from(_profile.educations)
      ..removeAt(index);
    return _persist(_profile.copyWith(educations: list));
  }

  Future<void> upsertItSkill(ITSkill skill, {int? index}) {
    final list = List<ITSkill>.from(_profile.itSkills);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = skill;
    } else {
      list.add(skill);
    }
    return _persist(_profile.copyWith(itSkills: list));
  }

  Future<void> deleteItSkill(int index) {
    final list = List<ITSkill>.from(_profile.itSkills)..removeAt(index);
    return _persist(_profile.copyWith(itSkills: list));
  }

  Future<void> upsertProject(ProjectEntry project, {int? index}) {
    final list = List<ProjectEntry>.from(_profile.projects);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = project;
    } else {
      list.add(project);
    }
    return _persist(_profile.copyWith(projects: list));
  }

  Future<void> deleteProject(int index) {
    final list = List<ProjectEntry>.from(_profile.projects)..removeAt(index);
    return _persist(_profile.copyWith(projects: list));
  }

  Future<void> upsertAccomplishment(Accomplishment item, {int? index}) {
    final list = List<Accomplishment>.from(_profile.accomplishments);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = item;
    } else {
      list.add(item);
    }
    return _persist(_profile.copyWith(accomplishments: list));
  }

  Future<void> deleteAccomplishment(int index) {
    final list = List<Accomplishment>.from(_profile.accomplishments)
      ..removeAt(index);
    return _persist(_profile.copyWith(accomplishments: list));
  }

  Future<void> updateCareer(CareerProfile career) {
    return _persist(_profile.copyWith(careerProfile: career));
  }

  Future<void> updatePersonal(PersonalDetails personal) {
    return _persist(_profile.copyWith(personalDetails: personal));
  }

  Future<void> upsertLanguage(LanguageProficiency lang, {int? index}) {
    final list = List<LanguageProficiency>.from(_profile.languages);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = lang;
    } else {
      list.add(lang);
    }
    return _persist(_profile.copyWith(languages: list));
  }

  Future<void> deleteLanguage(int index) {
    final list = List<LanguageProficiency>.from(_profile.languages)
      ..removeAt(index);
    return _persist(_profile.copyWith(languages: list));
  }

  Future<void> updateDiversity(String note) {
    return _persist(_profile.copyWith(diversityNote: note));
  }
}

import 'dart:io';

import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Profile, resume, avatar, and account endpoints under `/api/v1/users`.
class UserService {
  final ApiClient _api = ApiClient.instance;

  /// Patches the user's profile.
  ///
  /// IMPORTANT: the backend returns only the `profile` subdocument
  /// (`{ fullName, headline, skills, ... }`) — no email, no _id. Parsing
  /// that as a full user wiped email/id from local state. So we PATCH
  /// for the side-effect, then re-fetch the canonical user via
  /// `GET /auth/me` so every field stays consistent.
  Future<UserModel> updateProfile({
    String? fullName,
    String? headline,
    List<String>? skills,
    int? experienceYears,
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    List<String>? preferredJobTypes,
    List<String>? preferredRemote,
    int? expectedSalaryMin,
    String? resumeText,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      body[key] = value;
    }

    put('fullName', fullName);
    put('headline', headline);
    put('skills', skills);
    put('experienceYears', experienceYears);
    put('preferredRoles', preferredRoles);
    put('preferredLocations', preferredLocations);
    put('preferredJobTypes', preferredJobTypes);
    put('preferredRemote', preferredRemote);
    put('expectedSalaryMin', expectedSalaryMin);
    put('resumeText', resumeText);
    put('phone', phone);

    await _api.patch('users/profile', body: body);

    final raw = await _api.get('auth/me');
    final data = ApiClient.unwrapMap(raw);
    final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
    final user = UserModel.fromApiJson(userJson);
    await StorageService.saveUser(user);
    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw 'New password must be at least 6 characters';
    }
    await _api.post('users/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<String> switchRole(String role) async {
    final raw =
        await _api.post('users/switch-role', body: {'role': role});
    final data = ApiClient.unwrapMap(raw);
    return (data['activeRole'] as String?) ?? role;
  }

  Future<Map<String, dynamic>> updateNotificationPrefs({
    bool? push,
    bool? email,
    bool? whatsapp,
    bool? jobAlerts,
    bool? applicationUpdates,
    bool? autoApplySummary,
    bool? aiPolish,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) async {
    final body = <String, dynamic>{
      if (push != null) 'push': push,
      if (email != null) 'email': email,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (jobAlerts != null) 'jobAlerts': jobAlerts,
      if (applicationUpdates != null) 'applicationUpdates': applicationUpdates,
      if (autoApplySummary != null) 'autoApplySummary': autoApplySummary,
      if (aiPolish != null) 'aiPolish': aiPolish,
      if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
      if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
    };
    final raw = await _api.put('users/notification-prefs', body: body);
    return ApiClient.unwrapMap(raw);
  }

  Future<Map<String, dynamic>> uploadResume(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
    final raw = await _api.uploadFromFile(
      'users/resume',
      field: 'resume',
      file: file,
      contentType: contentType,
    );
    return ApiClient.unwrapMap(raw);
  }

  /// Asks the backend to run the user's stored resume text through the LLM
  /// parser and return structured fields (headline, skills, employments…)
  /// the client can merge into the local resume profile. Returns null if
  /// the backend has nothing to parse (no resume uploaded yet, or the file
  /// had no extractable text — e.g. a scanned PDF).
  Future<Map<String, dynamic>?> parseResume() async {
    final raw = await _api.post('users/resume/parse');
    // Backend may return { success, data: null } when there's no resume
    // text (scanned PDF, etc.) — guard the unwrap explicitly.
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  /// Pushes the long-form resume profile (employments, educations, career
  /// profile, accomplishments, personal details, etc.) to the backend so
  /// it survives reinstalls and follows the user across devices.
  ///
  /// Fire-and-forget at most call sites — failure shouldn't block local
  /// edits. The provider keeps the canonical local state regardless.
  Future<void> pushResumeProfile(Map<String, dynamic> body) async {
    if (body.isEmpty) return;
    await _api.patch('users/resume-profile', body: body);
  }

  Future<Map<String, dynamic>?> getResumeMeta() async {
    try {
      final raw = await _api.get('users/resume/meta');
      return ApiClient.unwrapMap(raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<int>> downloadResume() async {
    final res = await _api.getRaw('users/resume');
    return res.bodyBytes;
  }

  /// Branded resume PDF. Server renders the structured profile through
  /// the Job Hunter template (Puppeteer headless) — returns raw PDF
  /// bytes the caller writes to disk. No AI cost, but the user must
  /// have at least a summary/skills/experience filled in or the server
  /// 400s.
  Future<({List<int> bytes, String filename})> downloadBrandedResumePdf() async {
    final res = await _api.getRaw('users/resume/branded-pdf');
    final disposition =
        res.headers['content-disposition'] ?? res.headers['Content-Disposition'];
    String filename = 'resume_jobhunter.pdf';
    if (disposition != null) {
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      if (m != null) filename = m.group(1)!;
    }
    return (bytes: res.bodyBytes, filename: filename);
  }

  Future<void> deleteResume() async {
    await _api.delete('users/resume');
  }

  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
    final raw = await _api.uploadFromFile(
      'users/avatar',
      field: 'avatar',
      file: file,
      contentType: contentType,
    );
    return ApiClient.unwrapMap(raw);
  }

  Future<List<int>> downloadAvatar({String? userId}) async {
    final path = userId == null ? 'users/avatar' : 'users/avatar/$userId';
    final res = await _api.getRaw(path);
    return res.bodyBytes;
  }

  Future<void> deleteAvatar() async {
    await _api.delete('users/avatar');
  }

  Future<void> deleteAccount() async {
    await _api.delete('users/account');
    await StorageService.logout();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/resume_profile_model.dart';
import '../models/user_model.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveUser(UserModel user) async {
    await init();
    await _prefs!.setString(AppConstants.keyUserData, jsonEncode(user.toJson()));
    await _prefs!.setBool(AppConstants.keyIsLoggedIn, true);
  }

  static UserModel? getUser() {
    final data = _prefs?.getString(AppConstants.keyUserData);
    if (data == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static bool isLoggedIn() {
    return _prefs?.getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    await init();
    await _prefs!.remove(AppConstants.keyUserData);
    await _prefs!.remove(AppConstants.keyAccessToken);
    await _prefs!.remove(AppConstants.keyRefreshToken);
    await _prefs!.setBool(AppConstants.keyIsLoggedIn, false);
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await init();
    await _prefs!.setString(AppConstants.keyAccessToken, accessToken);
    await _prefs!.setString(AppConstants.keyRefreshToken, refreshToken);
  }

  static String? getAccessToken() =>
      _prefs?.getString(AppConstants.keyAccessToken);

  static String? getRefreshToken() =>
      _prefs?.getString(AppConstants.keyRefreshToken);

  static Future<void> clearTokens() async {
    await init();
    await _prefs!.remove(AppConstants.keyAccessToken);
    await _prefs!.remove(AppConstants.keyRefreshToken);
  }

  static Future<void> saveSavedJobs(List<String> jobIds) async {
    await init();
    await _prefs!.setStringList(AppConstants.keySavedJobs, jobIds);
  }

  static List<String> getSavedJobs() {
    return _prefs?.getStringList(AppConstants.keySavedJobs) ?? [];
  }

  static Future<void> saveResumeProfile(ResumeProfile profile) async {
    await init();
    await _prefs!.setString(
        AppConstants.keyResumeProfile, jsonEncode(profile.toJson()));
  }

  static ResumeProfile? getResumeProfile() {
    final data = _prefs?.getString(AppConstants.keyResumeProfile);
    if (data == null) return null;
    try {
      return ResumeProfile.fromJson(
          jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveThemeMode(String mode) async {
    await init();
    await _prefs!.setString(AppConstants.keyThemeMode, mode);
  }

  static String? getThemeMode() {
    return _prefs?.getString(AppConstants.keyThemeMode);
  }

  /// Persisted set of job ids the seeker has already been alerted about
  /// for "70%+ match" pushes. Drives dedup so a job that was relevant
  /// last refresh doesn't re-trigger the toast on the next 2-hour tick.
  static Future<void> saveAlertedHighMatchJobIds(Set<String> ids) async {
    await init();
    await _prefs!
        .setStringList(AppConstants.keyAlertedHighMatchJobIds, ids.toList());
  }

  static Set<String> getAlertedHighMatchJobIds() {
    final raw =
        _prefs?.getStringList(AppConstants.keyAlertedHighMatchJobIds) ?? const [];
    return raw.toSet();
  }

  /// Persistent flag — set to true the first time the user reaches the
  /// end of the seeker onboarding wizard (finish OR skip). The role-
  /// switch flow reads this to avoid re-asking "Make it yours" every
  /// time the user comes back to seeker mode after a hirer detour.
  static Future<void> setSeekerOnboardingSeen() async {
    await init();
    await _prefs!.setBool(AppConstants.keySeekerOnboardingSeen, true);
  }

  static bool hasSeekerOnboardingSeen() {
    return _prefs?.getBool(AppConstants.keySeekerOnboardingSeen) ?? false;
  }

  /// Persistent flag — set after the user dismisses the AI features
  /// tour. Drives the auto-show on first home-screen visit.
  static Future<void> setAiTourSeen() async {
    await init();
    await _prefs!.setBool(AppConstants.keyAiTourSeen, true);
  }

  static bool hasAiTourSeen() {
    return _prefs?.getBool(AppConstants.keyAiTourSeen) ?? false;
  }

  /// Mark the resume parser auto-fill as having run at least once. Once
  /// this is set, [ResumeProfileProvider.syncFromBackend] stops calling
  /// `parseResume` on screen re-entry — otherwise a section the user
  /// emptied by deleting all its rows would be silently refilled from
  /// the parser output on the next open.
  static Future<void> setResumeParserApplied() async {
    await init();
    await _prefs!.setBool(AppConstants.keyResumeParserApplied, true);
  }

  static Future<void> clearResumeParserApplied() async {
    await init();
    await _prefs!.remove(AppConstants.keyResumeParserApplied);
  }

  static bool hasResumeParserApplied() {
    return _prefs?.getBool(AppConstants.keyResumeParserApplied) ?? false;
  }
}

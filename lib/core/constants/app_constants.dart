import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'Job Hunter';
  static const String appVersion = '1.0.0';

  // Asset paths
  static const String appLogoAsset = 'assets/images/app_logo.png';

  // Storage keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserData = 'user_data';
  static const String keySavedJobs = 'saved_jobs';
  static const String keyAppliedJobs = 'applied_jobs';
  static const String keyResumeProfile = 'resume_profile_v2';
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyIsGuest = 'is_guest_mode';
  static const String keyRecentSearches = 'recent_searches_v1';
  static const String keySavedSearches = 'saved_searches_v1';
  static const String keyThemeMode = 'theme_mode_v1';
  static const String keyAlertedHighMatchJobIds = 'alerted_high_match_jobs_v1';
  // Marks whether the seeker has been shown the onboarding wizard at
  // least once (finished OR skipped). Lets the role-switch flow stop
  // re-prompting "Make it yours" every time the user toggles back to
  // seeker after a stint in hirer mode.
  static const String keySeekerOnboardingSeen = 'seeker_onboarding_seen_v1';

  static const String _devApiBaseUrl = 'http://localhost:4000/api/v1';
  static const String _prodApiBaseUrl =
      'https://job-hunter-backend-mcc4.onrender.com/api/v1';
  static String get apiBaseUrl =>
      kReleaseMode ? _prodApiBaseUrl : _devApiBaseUrl;

  // Web (type 3) client from android/app/google-services.json — must
  // match Firebase project 'job-hunter-63fdc' so Google Sign-In on
  // Android receives an ID token Firebase Auth will accept.
  static const String googleWebClientId =
      '309121341037-jvjq5gdooel5ojc41vb8h8ineupe8olb.apps.googleusercontent.com';
  static bool get googleAuthConfigured => googleWebClientId.isNotEmpty;

  // Categories
  static const List<String> jobCategories = [
    'All',
    'Marketing',
    'Design',
    'Administration',
    'Programming',
    'Finance',
    'Sales',
    'HR',
  ];

  // Job types
  static const List<String> jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Remote',
  ];

  // Experience levels
  static const List<String> experienceLevels = [
    '0-1 years',
    '1-3 years',
    '3-5 years',
    '5-8 years',
    '8+ years',
  ];
}

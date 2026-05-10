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

  static const String apiBaseUrl = 'http://localhost:4000/api/v1';
  // static const String apiBaseUrl =
  //     'https://job-hunter-backend-mcc4.onrender.com/api/v1';

  // matches the backend's expectation.
  static const String googleWebClientId =
      '189382197401-ga6r49pivbrdsr1kgpjmq01nfq6bllb1.apps.googleusercontent.com';
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

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String emailAuth = '/email-auth';
  // Recruiter (hirer) signup / login entry point. Distinct from the
  // seeker /login route so the post-auth flow can route new accounts
  // through hirer profile setup + activeRole switch before /main.
  static const String recruiterLogin = '/recruiter-login';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  static const String search = '/search';
  static const String jobDetail = '/job-detail';
  // Variant of [jobDetail] entered from a push tap or a deep link where
  // we only have the job id, not the full Job model. The handler screen
  // fetches the job from the API and forwards to [jobDetail].
  static const String jobDetailById = '/job-detail-by-id';
  static const String editField = '/edit-field';
  static const String helpSupport = '/help-support';
  static const String about = '/about';
  static const String subscription = '/subscription';
  static const String alerts = '/alerts';
  static const String hirerProfileSetup = '/hirer-profile-setup';
  static const String hirerDashboard = '/hirer-dashboard';
  static const String hirerPostJob = '/hirer-post-job';
  static const String hirerManageJobs = '/hirer-manage-jobs';
  static const String hirerApplicants = '/hirer-applicants';
  static const String hirerKanban = '/hirer-kanban';
  static const String hirerTeam = '/hirer-team';
  static const String savedJobs = '/saved-jobs';
  static const String autoApply = '/auto-apply';
  static const String autoApplyLog = '/auto-apply-log';
  static const String conversations = '/conversations';
  static const String chat = '/chat';
  static const String myInterviews = '/my-interviews';
  static const String companyProfile = '/company-profile';
  static const String profileOptimizer = '/profile-optimizer';
  static const String skillGap = '/skill-gap';
  static const String atsScore = '/ats-score';
  static const String aiAssistant = '/ai-assistant';
  static const String aiUsageHistory = '/ai-usage-history';
  static const String skillAssessments = '/skill-assessments';
  static const String assessmentQuiz = '/assessment-quiz';
  static const String assessmentResult = '/assessment-result';
  static const String mockInterview = '/mock-interview';
  static const String badges = '/badges';
  static const String coins = '/coins';
  static const String hirerAnalytics = '/hirer-analytics';
  static const String notifications = '/notifications';
  static const String notificationPrefs = '/notification-prefs';
}

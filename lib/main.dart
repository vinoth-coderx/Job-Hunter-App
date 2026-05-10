import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/models/job_model.dart';
import 'data/services/api_client.dart';
import 'data/services/push_service.dart';
import 'data/services/storage_service.dart';
import 'presentation/alerts/alerts_screen.dart';
import 'presentation/auth/email_auth_screen.dart';
import 'presentation/auth/forgot_password_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/onboarding_screen.dart';
import 'presentation/auth/role_picker_screen.dart';
import 'presentation/auth/splash_screen.dart';
import 'presentation/auto_apply/auto_apply_log_screen.dart';
import 'presentation/ai/badges_screen.dart';
import 'presentation/coins/coins_screen.dart';
import 'presentation/widgets/coin_burst_overlay.dart';
import 'presentation/ai/hirer_analytics_screen.dart';
import 'presentation/ai/profile_optimizer_screen.dart';
import 'presentation/ai/skill_gap_screen.dart';
import 'presentation/assessments/skill_assessments_screen.dart';
import 'presentation/auto_apply/auto_apply_setup_screen.dart';
import 'presentation/chat/chat_screen.dart';
import 'presentation/chat/conversations_screen.dart';
import 'presentation/company/company_profile_screen.dart';
import 'presentation/interviews/mock_interview_screen.dart';
import 'presentation/interviews/my_interviews_screen.dart';
import 'presentation/hirer/applicants_kanban_screen.dart';
import 'presentation/hirer/applicants_screen.dart';
import 'presentation/hirer/hirer_dashboard_screen.dart';
import 'presentation/hirer/hirer_profile_setup_screen.dart';
import 'presentation/hirer/manage_jobs_screen.dart';
import 'presentation/hirer/post_job_screen.dart';
import 'presentation/hirer/team_management_screen.dart';
import 'presentation/job_detail/job_detail_screen.dart';
import 'presentation/main_navigation/role_aware_main_screen.dart';
import 'presentation/notifications/notifications_screen.dart';
import 'presentation/profile/about_screen.dart';
import 'presentation/profile/edit_field_screen.dart';
import 'presentation/profile/help_support_screen.dart';
import 'presentation/profile/notification_prefs_screen.dart';
import 'presentation/profile/profile_information_screen.dart';
import 'presentation/profile/resume_profile_screen.dart';
import 'presentation/profile/subscription_screen.dart';
import 'presentation/saved/saved_jobs_screen.dart';
import 'presentation/search/search_screen.dart';
import 'providers/ai_quota_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/applicants_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/auto_apply_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/coins_provider.dart';
import 'providers/hirer_jobs_provider.dart';
import 'providers/hirer_provider.dart';
import 'providers/job_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/resume_profile_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for the mobile-first design
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Draw behind the system bars so screens can go edge-to-edge.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Make status bar transparent so our gradient screens look correct.
  // On Android Q+ the system applies a contrast scrim (visible as a
  // solid black bar over the status / nav area) unless we explicitly
  // opt out via *ContrastEnforced: false — without these flags the
  // gradient gets masked even though statusBarColor is transparent.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Initialize local storage
  await StorageService.init();

  // Firebase — picks up google-services.json (Android) and
  // GoogleService-Info.plist (iOS) from the platform folders. If those
  // files aren't present yet, we swallow the error so dev builds still
  // launch; PushService.init() will become a no-op until they're added.
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed (push disabled): $e\n$st');
  }

  // Wire FCM + local notifications. Idempotent — also re-called after
  // sign-in so the device token can be registered against the new user.
  // Safe to call before the user is authenticated; it'll silently skip
  // the backend register and retry on the next init().
  await PushService.init();

  runApp(const JobHunterApp());
}

class JobHunterApp extends StatelessWidget {
  const JobHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
        ChangeNotifierProvider(create: (_) => ResumeProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => HirerProvider()),
        ChangeNotifierProvider(create: (_) => HirerJobsProvider()),
        ChangeNotifierProvider(create: (_) => ApplicantsProvider()),
        ChangeNotifierProvider(create: (_) => AutoApplyProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CoinsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AiQuotaProvider()..startBackgroundRefresh()),
      ],
      child: const _UnauthorizedRedirectGate(child: _AppRoot()),
    );
  }
}

/// Wires `ApiClient.onUnauthorized` once the provider tree is mounted so
/// any 401 from the backend (expired/invalid token) immediately tears
/// down the chat socket + job feed + auth state and bounces the user to
/// the login screen — no refresh-token dance, no waiting on the next
/// screen to notice.
class _UnauthorizedRedirectGate extends StatefulWidget {
  final Widget child;
  const _UnauthorizedRedirectGate({required this.child});

  @override
  State<_UnauthorizedRedirectGate> createState() =>
      _UnauthorizedRedirectGateState();
}

class _UnauthorizedRedirectGateState extends State<_UnauthorizedRedirectGate> {
  @override
  void initState() {
    super.initState();
    ApiClient.instance.onUnauthorized = _onUnauthorized;
  }

  @override
  void dispose() {
    if (ApiClient.instance.onUnauthorized == _onUnauthorized) {
      ApiClient.instance.onUnauthorized = null;
    }
    super.dispose();
  }

  void _onUnauthorized() {
    final nav = PushService.navigatorKey.currentState;
    final ctx = PushService.navigatorKey.currentContext;
    if (ctx != null) {
      // Match the explicit-logout teardown order so a forced redirect
      // doesn't leave a socket authed as the now-stale user.
      try {
        ctx.read<ChatProvider>().signOut();
      } catch (_) {}
      try {
        ctx.read<JobProvider>().signOut();
      } catch (_) {}
      try {
        // Auth provider's signOut also clears tokens — safe to call even
        // though ApiClient already wiped them; it's idempotent.
        ctx.read<AuthProvider>().signOut();
      } catch (_) {}
    }
    nav?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'Job Hunter',
        debugShowCheckedModeBanner: false,
        navigatorKey: PushService.navigatorKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeProvider.mode,
        // Wrap every screen in the coin-burst overlay so the "+N 🪙"
        // animation can play from any earn event regardless of which
        // screen triggered it.
        builder: (_, child) => CoinBurstOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
              );
            case AppRoutes.login:
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
            case AppRoutes.emailAuth:
              final initialSignUp = settings.arguments == 'signup';
              return MaterialPageRoute(
                builder: (_) =>
                    EmailAuthScreen(initialSignUp: initialSignUp),
              );
            case AppRoutes.forgotPassword:
              final initialEmail = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) =>
                    ForgotPasswordScreen(initialEmail: initialEmail),
              );
            case AppRoutes.rolePicker:
              return MaterialPageRoute(
                builder: (_) => const RolePickerScreen(),
              );
            case AppRoutes.onboarding:
              return MaterialPageRoute(
                builder: (_) => const OnboardingScreen(),
              );
            case AppRoutes.main:
              return MaterialPageRoute(
                builder: (_) => const RoleAwareMainScreen(),
              );
            case AppRoutes.search:
              final autoStartVoice = settings.arguments == 'voice';
              final prefill = settings.arguments is AlertSearchArgs
                  ? settings.arguments as AlertSearchArgs
                  : null;
              return MaterialPageRoute(
                builder: (_) => SearchScreen(
                  autoStartVoice: autoStartVoice,
                  prefill: prefill,
                ),
              );
            case AppRoutes.jobDetail:
              final job = settings.arguments as Job;
              return MaterialPageRoute(
                builder: (_) => JobDetailScreen(job: job),
              );
            case AppRoutes.profileInformation:
              return MaterialPageRoute(
                builder: (_) => const ProfileInformationScreen(),
              );
            case AppRoutes.resumeProfile:
              return MaterialPageRoute(
                builder: (_) => const ResumeProfileScreen(),
              );
            case AppRoutes.editField:
              final args = settings.arguments as EditFieldArgs;
              return MaterialPageRoute(
                builder: (_) => EditFieldScreen(kind: args.kind),
              );
            case AppRoutes.helpSupport:
              return MaterialPageRoute(
                builder: (_) => const HelpSupportScreen(),
              );
            case AppRoutes.about:
              return MaterialPageRoute(
                builder: (_) => const AboutScreen(),
              );
            case AppRoutes.subscription:
              return MaterialPageRoute(
                builder: (_) => const SubscriptionScreen(),
              );
            case AppRoutes.alerts:
              return MaterialPageRoute(
                builder: (_) => const AlertsScreen(),
              );
            case AppRoutes.hirerProfileSetup:
              return MaterialPageRoute(
                builder: (_) => const HirerProfileSetupScreen(),
              );
            case AppRoutes.hirerPostJob:
              return MaterialPageRoute(
                builder: (_) => const PostJobScreen(),
              );
            case AppRoutes.hirerDashboard:
              return MaterialPageRoute(
                builder: (_) => const HirerDashboardScreen(),
              );
            case AppRoutes.hirerManageJobs:
              return MaterialPageRoute(
                builder: (_) => const ManageJobsScreen(),
              );
            case AppRoutes.hirerApplicants:
              final jobId = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) => ApplicantsScreen(jobId: jobId),
              );
            case AppRoutes.hirerKanban:
              final jobId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => ApplicantsKanbanScreen(jobId: jobId),
              );
            case AppRoutes.hirerTeam:
              return MaterialPageRoute(
                builder: (_) => const TeamManagementScreen(),
              );
            case AppRoutes.savedJobs:
              return MaterialPageRoute(
                builder: (_) => const SavedJobsScreen(),
              );
            case AppRoutes.autoApply:
              return MaterialPageRoute(
                builder: (_) => const AutoApplySetupScreen(),
              );
            case AppRoutes.autoApplyLog:
              return MaterialPageRoute(
                builder: (_) => const AutoApplyLogScreen(),
              );
            case AppRoutes.conversations:
              return MaterialPageRoute(
                builder: (_) => const ConversationsScreen(),
              );
            case AppRoutes.chat:
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: id),
              );
            case AppRoutes.myInterviews:
              final hirerMode = settings.arguments == 'hirer';
              return MaterialPageRoute(
                builder: (_) => MyInterviewsScreen(hirerMode: hirerMode),
              );
            case AppRoutes.companyProfile:
              final id = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => CompanyProfileScreen(companyId: id),
              );
            case AppRoutes.profileOptimizer:
              return MaterialPageRoute(
                builder: (_) => const ProfileOptimizerScreen(),
              );
            case AppRoutes.skillGap:
              return MaterialPageRoute(
                builder: (_) => const SkillGapScreen(),
              );
            case AppRoutes.skillAssessments:
              return MaterialPageRoute(
                builder: (_) => const SkillAssessmentsScreen(),
              );
            case AppRoutes.mockInterview:
              final args =
                  (settings.arguments as Map<String, String>?) ?? const {};
              return MaterialPageRoute(
                builder: (_) => MockInterviewScreen(
                  initialType: args['type'],
                  roleHint: args['role'],
                ),
              );
            case AppRoutes.badges:
              return MaterialPageRoute(
                builder: (_) => const BadgesScreen(),
              );
            case AppRoutes.coins:
              return MaterialPageRoute(
                builder: (_) => const CoinsScreen(),
              );
            case AppRoutes.hirerAnalytics:
              return MaterialPageRoute(
                builder: (_) => const HirerAnalyticsScreen(),
              );
            case AppRoutes.notifications:
              return MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              );
            case AppRoutes.notificationPrefs:
              return MaterialPageRoute(
                builder: (_) => const NotificationPrefsScreen(),
              );
            default:
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
              );
          }
        },
      ),
    );
  }
}

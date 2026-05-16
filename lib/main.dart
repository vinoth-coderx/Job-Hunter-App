import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'data/models/job_model.dart';
import 'data/services/api_client.dart';
import 'data/services/deep_link_service.dart';
import 'data/services/push_service.dart';
import 'data/services/storage_service.dart';
import 'presentation/alerts/alerts_screen.dart';
import 'presentation/auth/email_auth_screen.dart';
import 'presentation/auth/forgot_password_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/recruiter_login_screen.dart';
import 'presentation/auth/splash_screen.dart';
import 'presentation/auto_apply/auto_apply_log_screen.dart';
import 'presentation/ai/badges_screen.dart';
import 'presentation/coins/coins_screen.dart';
import 'presentation/widgets/coin_burst_overlay.dart';
import 'presentation/ai/hirer_analytics_screen.dart';
import 'presentation/ai/profile_optimizer_screen.dart';
import 'presentation/ai/skill_gap_screen.dart';
import 'presentation/ai/ats_score_screen.dart';
import 'presentation/ai/ai_assistant_screen.dart';
import 'presentation/ai/ai_usage_history_screen.dart';
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
import 'presentation/job_detail/job_detail_by_id_screen.dart';
import 'presentation/job_detail/job_detail_screen.dart';
import 'presentation/main_navigation/role_aware_main_screen.dart';
import 'presentation/notifications/notifications_screen.dart';
import 'presentation/profile/about_screen.dart';
import 'presentation/profile/edit_field_screen.dart';
import 'presentation/profile/help_support_screen.dart';
import 'presentation/profile/notification_prefs_screen.dart';
import 'presentation/profile/subscription_screen.dart';
import 'presentation/saved/saved_jobs_screen.dart';
import 'presentation/search/search_screen.dart';
import 'providers/ai_assistant_provider.dart';
import 'providers/ai_quota_provider.dart';
import 'providers/ats_provider.dart';
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
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Replace Flutter's default red "yellow text on red" error screen with
  // a calm fallback the user can recover from. The original error still
  // hits FlutterError.onError below, so devs see it in the console and
  // crash reporters keep their stack traces; only the *visible* widget
  // changes. Without this, an InheritedWidget assertion or a stray
  // build-time exception paints a giant red banner over the whole app.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _FriendlyErrorFallback(details: details);
  };

  // Pipe framework errors to debugPrint so the Logcat / Xcode console
  // still shows them — important for diagnosing the same bug we just
  // hid from the user above.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

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

  // Firebase — uses DefaultFirebaseOptions.currentPlatform so web,
  // Android, and iOS all initialize from the FlutterFire-generated
  // firebase_options.dart. Wrapped in try/catch so dev builds still
  // launch if config is missing on a platform; PushService.init() will
  // then become a no-op.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed (push disabled): $e\n$st');
  }

  // Wire FCM + local notifications. Idempotent — also re-called after
  // sign-in so the device token can be registered against the new user.
  // Safe to call before the user is authenticated; it'll silently skip
  // the backend register and retry on the next init(). Fire-and-forget
  // so a slow FCM token round-trip doesn't delay the first splash frame
  // on cold start — push permission prompts can wait one extra tick.
  unawaited(PushService.init());

  // Android App Links / iOS Universal Links / jobhunter:// custom
  // scheme. Captures the cold-start URI (terminated-state launch from a
  // tapped email or push link) so the right screen opens after the
  // navigator mounts; also subscribes to live link arrivals.
  unawaited(DeepLinkService.init());

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
        ChangeNotifierProvider(create: (_) => AtsProvider()),
        ChangeNotifierProvider(create: (_) => AiAssistantProvider()),
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
            case AppRoutes.recruiterLogin:
              return MaterialPageRoute(
                builder: (_) => const RecruiterLoginScreen(),
              );
            case AppRoutes.emailAuth:
              // The argument string carries two orthogonal bits:
              //   - `signup` / `signin` → which mode the form opens in
              //   - `-hirer` suffix     → the caller is the recruiter
              //                            flow, which expects a `pop(true)`
              //                            on success instead of pushing
              //                            straight to /main.
              final arg = settings.arguments as String? ?? '';
              final initialSignUp = arg.startsWith('signup');
              final forHirer = arg.endsWith('-hirer');
              return MaterialPageRoute(
                builder: (_) => EmailAuthScreen(
                  initialSignUp: initialSignUp,
                  forHirer: forHirer,
                ),
              );
            case AppRoutes.forgotPassword:
              final initialEmail = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) =>
                    ForgotPasswordScreen(initialEmail: initialEmail),
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
            case AppRoutes.jobDetailById:
              final jobId = (settings.arguments as String?) ?? '';
              return MaterialPageRoute(
                builder: (_) => JobDetailByIdScreen(jobId: jobId),
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
            case AppRoutes.atsScore:
              final args =
                  (settings.arguments as Map<String, String>?) ?? const {};
              return MaterialPageRoute(
                builder: (_) => AtsScoreScreen(
                  jobId: args['jobId'],
                  jobTitle: args['jobTitle'],
                ),
              );
            case AppRoutes.aiAssistant:
              return MaterialPageRoute(
                builder: (_) => const AiAssistantScreen(),
              );
            case AppRoutes.aiUsageHistory:
              return MaterialPageRoute(
                builder: (_) => const AiUsageHistoryScreen(),
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

/// Drop-in replacement for Flutter's default red error widget. Shows a
/// neutral surface with a "Something went wrong" message instead of the
/// raw yellow-on-red stack trace. The underlying error still hits
/// `FlutterError.onError` so devs see it in the console and any
/// connected crash reporter records it — only the *visible* widget is
/// replaced. Tappable hint to restart the app via a hot-reload prompt
/// or to navigate back if a parent Navigator is reachable.
class _FriendlyErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _FriendlyErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FA),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  size: 48,
                  color: Color(0xFF8A94A6),
                ),
                SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This screen ran into a problem. Go back and try again — '
                  'if it keeps happening, please try restarting the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF6B7280),
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

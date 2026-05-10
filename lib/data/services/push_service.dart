import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/routes/app_routes.dart';
import '../services/api_client.dart';
import '../services/device_service.dart';

/// Push-notification entry point. Initialised once from `main()` after
/// `Firebase.initializeApp(...)` has resolved.
///
/// Responsibilities:
///   - Request permission (iOS / web; Android grants by default).
///   - Acquire the current FCM token + register it with the backend so
///     the alert cron can target this device.
///   - Listen for token rotation (re-register).
///   - Show foreground notifications via flutter_local_notifications,
///     since FCM does not display them on its own when the app is open.
///   - Provide an Android notification channel (`job_alerts`) — the
///     backend's FCM payload references this channel id.
///   - Route taps (FCM background, local notif, terminated-state launch)
///     to the relevant in-app screen using the global [navigatorKey].
class PushService {
  PushService._();

  /// Global navigator key wired into [MaterialApp] so we can navigate
  /// from outside the widget tree (notification tap callbacks fire
  /// without a `BuildContext`).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const _androidChannel = AndroidNotificationChannel(
    'job_alerts',
    'Job alerts',
    description: 'New job matches and application updates.',
    importance: Importance.high,
  );

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;

  static String _platformId() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  /// Idempotent — safe to call after every login or app resume.
  static Future<void> init() async {
    if (_initialised) {
      // Already wired; just refresh the token (covers a fresh login on
      // top of a still-warm process where the token is unchanged).
      await _registerCurrentToken();
      return;
    }
    _initialised = true;

    try {
      await _setupLocalNotifications();
      await _setupFirebaseMessaging();
    } catch (e, st) {
      _initialised = false; // allow retry on next call
      debugPrint('PushService.init failed: $e\n$st');
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) =>
          _handleTapPayload(resp.payload),
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerCurrentToken();

    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground messages — FCM doesn't surface a banner while the app
    // is open, so we re-show via flutter_local_notifications. Encode the
    // FCM `data` map as JSON in the payload so the tap handler can
    // route the user to the right screen.
    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif == null) return;
      showLocal(
        title: notif.title ?? '',
        body: notif.body ?? '',
        data: msg.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    });

    // Tap on an FCM notification while app is backgrounded — navigate.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _navigateForData(
        msg.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    });

    // Tap that launched the app from a fully terminated state.
    final initialMsg = await messaging.getInitialMessage();
    if (initialMsg != null) {
      // Defer one frame so MaterialApp's navigator is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateForData(
          initialMsg.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        );
      });
    }
  }

  /// Show a local banner from anywhere in the app. Used by the FCM
  /// foreground listener, and by socket-driven providers when a live
  /// `notification:new` / `message:new` arrives while the app is open
  /// (the backend already sent FCM, but FCM is silent in foreground —
  /// and on web/desktop it may not run at all).
  ///
  /// [data] is JSON-encoded into the local-notif payload so the tap
  /// callback can route to the right screen.
  static Future<void> showLocal({
    required String title,
    required String body,
    Map<String, String> data = const {},
    int? id,
  }) async {
    final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _local.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: data.isEmpty ? null : jsonEncode(data),
    );
  }

  static Future<void> _registerCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      await DeviceService().registerToken(
        token: token,
        platform: _platformId(),
      );
    } on ApiException {
      // User likely not authenticated yet — silently skip; the next
      // call to `init()` after login will succeed.
    } catch (e) {
      debugPrint('PushService.registerToken failed: $e');
    }
  }

  // ── Tap routing ───────────────────────────────────────────────────

  static void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _navigateForData(
          decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
        );
      }
    } catch (_) {
      // Malformed payload — drop silently.
    }
  }

  /// Pick a destination route from the FCM `data` map.
  ///
  /// Backend convention:
  ///   - chat / new-message: `{ type: 'new_message', conversationId: '…' }`
  ///   - everything else (application status, interview, job match,
  ///     applicant, system): falls through to the notifications inbox.
  static void _navigateForData(Map<String, String> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] ?? '';
    final convId = data['conversationId'];

    if (type == 'new_message' && convId != null && convId.isNotEmpty) {
      nav.pushNamed(AppRoutes.chat, arguments: convId);
      return;
    }

    nav.pushNamed(AppRoutes.notifications);
  }
}

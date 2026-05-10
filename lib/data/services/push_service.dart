import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
///
/// Backend setup is already done; once google-services.json /
/// GoogleService-Info.plist are in place and FIREBASE_SERVICE_ACCOUNT_*
/// env vars are populated, pushes flow end-to-end.
class PushService {
  PushService._();

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
    await _local.initialize(initSettings);

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

    FirebaseMessaging.onMessage.listen((msg) {
      final notif = msg.notification;
      if (notif == null) return;
      _local.show(
        notif.hashCode,
        notif.title,
        notif.body,
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
        payload: msg.data.isEmpty ? null : msg.data.toString(),
      );
    });
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
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/routes/app_routes.dart';
import 'push_service.dart';

/// Routes Android App Links / iOS Universal Links / custom-scheme
/// (jobhunter://) taps into in-app navigation.
///
/// Supported URL shapes (host or scheme either way):
///   `https://jobhunter.app/job/<id>`       → /job-detail-by-id
///   `jobhunter://job/<id>`                 → /job-detail-by-id
///   `https://jobhunter.app/chat/<id>`      → /chat
///   `https://jobhunter.app/notifications`  → /notifications
///
/// Anything else falls through to the home screen — the link still
/// opened the app, so we don't want to leave the user on a blank route.
///
/// Wired in [main] before `runApp` so the cold-start initial link
/// (terminated-state tap from email / push / browser) is captured and
/// applied on the next frame after MaterialApp mounts.
class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static bool _initialised = false;

  /// Idempotent — safe to call from main() AND from anywhere that
  /// wants to ensure the listener is up (e.g., post-login).
  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Cold-start: app launched FROM a deep link while previously
    // terminated. Defer one frame so the navigator is mounted before
    // we push.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _scheduleRoute(initial);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink getInitialLink failed: $e');
    }

    // Warm-state: app already running, OS handed us a fresh link.
    _sub = _appLinks.uriLinkStream.listen(
      _scheduleRoute,
      onError: (Object e) {
        if (kDebugMode) debugPrint('DeepLink stream error: $e');
      },
    );
  }

  static void _scheduleRoute(Uri uri) {
    // Push on the next tick so the navigator state has been mounted by
    // the time we call it (handles the cold-start case where init()
    // returns before runApp's first frame).
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(uri));
  }

  static void _route(Uri uri) {
    final nav = PushService.navigatorKey.currentState;
    if (nav == null) return;

    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      nav.pushNamed(AppRoutes.main);
      return;
    }

    switch (segments.first) {
      case 'job':
        final id = segments.length >= 2 ? segments[1] : '';
        if (id.isNotEmpty) {
          nav.pushNamed(AppRoutes.jobDetailById, arguments: id);
          return;
        }
        break;
      case 'chat':
        final id = segments.length >= 2 ? segments[1] : '';
        if (id.isNotEmpty) {
          nav.pushNamed(AppRoutes.chat, arguments: id);
          return;
        }
        break;
      case 'notifications':
        nav.pushNamed(AppRoutes.notifications);
        return;
      case 'alerts':
        nav.pushNamed(AppRoutes.alerts);
        return;
    }

    nav.pushNamed(AppRoutes.main);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialised = false;
  }
}

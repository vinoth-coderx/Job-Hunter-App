import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/ai_quota_model.dart';
import '../data/services/ai_service.dart';

/// Tracks the user's AI quota and broadcasts changes to the banner /
/// CTA widgets. Two write paths:
///   1. `refresh()` — explicit poll (called on app resume + periodically).
///   2. `update(snapshot)` — every AI endpoint returns a fresh quota,
///      and AiService callers feed it back here so we don't poll between
///      every action.
///
/// The provider also exposes a 1-second ticker (`countdownStream`) so the
/// banner's "resets in HH:MM:SS" text updates without each widget owning
/// its own Timer.
class AiQuotaProvider extends ChangeNotifier {
  AiQuota? _quota;
  bool _loading = false;
  Timer? _refreshTimer;
  Timer? _tickTimer;
  final _tickController = StreamController<DateTime>.broadcast();

  AiQuota? get quota => _quota;
  bool get isLoading => _loading;
  bool get isExhausted => _quota?.isExhausted ?? false;
  bool get isLow => _quota?.isLow ?? false;

  /// Stream that fires every 1s while a banner is mounted. Banner widgets
  /// listen instead of owning their own Timer; the provider stops the
  /// ticker when no listeners remain.
  Stream<DateTime> get countdownStream => _tickController.stream;

  void update(AiQuota? snapshot) {
    if (snapshot == null) return;
    _quota = snapshot;
    _ensureTicker();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final snap = await AiService.instance.quotaStatus();
      _quota = snap;
      _ensureTicker();
    } catch (_) {
      // Quota is best-effort — silently keep stale snapshot.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Start a 5-minute background poller. Cheap (one GET) and keeps the
  /// banner accurate even if the user idles on a screen that doesn't
  /// itself trigger AI calls.
  void startBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  void stopBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _ensureTicker() {
    // No need to tick if there's no exhausted state to count down to.
    final shouldTick = _quota != null && (_quota!.isExhausted || _quota!.isLow);
    if (!shouldTick) {
      _tickTimer?.cancel();
      _tickTimer = null;
      return;
    }
    if (_tickTimer != null) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickController.add(DateTime.now());
    });
  }

  /// Returns "HH:MM:SS" until the quota resets. Empty string when no
  /// quota loaded.
  String formatTimeUntilReset() {
    final q = _quota;
    if (q == null) return '';
    final now = DateTime.now();
    final remainingMs = q.resetsAt.difference(now).inMilliseconds;
    if (remainingMs <= 0) return '00:00:00';
    final secs = remainingMs ~/ 1000;
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickTimer?.cancel();
    _tickController.close();
    super.dispose();
  }
}

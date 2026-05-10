import 'package:flutter/foundation.dart';

import '../data/services/gamification_service.dart';

/// Owns the seeker's coin balance for header pill + future coins screen.
///
/// Two write paths:
///   1. `refresh()` — explicit poll. Called on login + on app resume so
///      the pill catches up to anything earned while we were backgrounded.
///   2. `setBalance(n)` — direct write for endpoints that return the
///      post-action balance (apply / checkin / etc. once those land).
///      Avoids a round-trip after every earn action.
class CoinsProvider extends ChangeNotifier {
  int _balance = 0;
  bool _loading = false;
  bool _hasLoaded = false;
  // Last positive change to the balance. The global coin-burst overlay
  // reads this, plays its animation, and then `consumeLastEarnDelta()`
  // clears it. We only emit positive deltas — coin spends (e.g. plan
  // redemption) shouldn't trigger a "you earned!" burst.
  int? _lastEarnDelta;

  int get balance => _balance;
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;
  int? get lastEarnDelta => _lastEarnDelta;

  void _maybeStashDelta(int next) {
    // Suppress on first load — the jump from 0 → 150 (existing wallet)
    // isn't an earn event, just the initial sync.
    if (!_hasLoaded) return;
    if (next > _balance) _lastEarnDelta = next - _balance;
  }

  void setBalance(int next) {
    if (next < 0) return;
    if (next == _balance) return;
    _maybeStashDelta(next);
    _balance = next;
    _hasLoaded = true;
    notifyListeners();
  }

  /// Called by the burst overlay after it consumes the delta so the
  /// animation only fires once per earn event.
  void consumeLastEarnDelta() {
    if (_lastEarnDelta == null) return;
    _lastEarnDelta = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final next = await GamificationService.instance.getCoinsBalance();
      _maybeStashDelta(next);
      _balance = next;
      _hasLoaded = true;
    } catch (_) {
      // Best-effort — keep the last-known balance if the call fails.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _balance = 0;
    _hasLoaded = false;
    _lastEarnDelta = null;
    notifyListeners();
  }
}

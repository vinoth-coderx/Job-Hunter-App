import 'package:flutter/widgets.dart';

/// Drop-on-State mixin that guards tap handlers against repeat fires.
///
/// Two flavours, picked per use-site:
///
/// * [guard] — for ASYNC actions (network, db, file io). Holds an in-flight
///   flag while the future runs and drops any repeat call until it settles.
///   Triggers a rebuild so [isBusy] flips both ways and the button can
///   render a spinner / disabled style.
///
/// * [debounceTap] — for SYNC actions that complete instantly but still
///   shouldn't fire twice (Navigator pushes, sheet/dialog opens, popping a
///   route). Adds a short cooldown window per [key].
///
/// Multiple independent guards on the same State are supported via [key]
/// (e.g. one screen with separate save and delete buttons can share the
/// mixin and use `key: 'save'` vs `key: 'delete'`).
mixin TapGuardMixin<T extends StatefulWidget> on State<T> {
  final Set<String> _inFlight = <String>{};
  final Map<String, DateTime> _lastFired = <String, DateTime>{};

  bool isBusy([String key = 'default']) => _inFlight.contains(key);

  Future<R?> guard<R>(
    Future<R> Function() action, {
    String key = 'default',
  }) async {
    if (_inFlight.contains(key)) return null;
    if (mounted) setState(() => _inFlight.add(key));
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _inFlight.remove(key));
      } else {
        _inFlight.remove(key);
      }
    }
  }

  void debounceTap(
    VoidCallback action, {
    String key = 'default',
    Duration cooldown = const Duration(milliseconds: 700),
  }) {
    final last = _lastFired[key];
    final now = DateTime.now();
    if (last != null && now.difference(last) < cooldown) return;
    _lastFired[key] = now;
    action();
  }
}

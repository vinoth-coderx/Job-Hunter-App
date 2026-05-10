import 'dart:async';

import 'package:flutter/widgets.dart';
import '../data/models/notification_model.dart';
import '../data/services/chat_service.dart';
import '../data/services/notification_service.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  final NotificationService _service = NotificationService.instance;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  NotificationProvider() {
    // Live banner: prepend whenever the server pushes a notification over
    // the socket, so the bell badge + list update without a manual refresh.
    _socketSub = ChatService.instance.onNotification.listen(_onPushed);
    // App resume → re-pull unread count so the bell badge is correct
    // even if the socket missed a push while the app was suspended.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshUnread();
    }
  }

  List<AppNotification> _items = const [];
  int _unread = 0;
  bool _loading = false;
  String? _error;

  List<AppNotification> get items => _items;
  int get unread => _unread;
  bool get loading => _loading;
  String? get error => _error;

  void _onPushed(Map<String, dynamic> raw) {
    try {
      final n = AppNotification.fromJson(raw);
      // Skip duplicates if the REST list already pulled this id.
      if (_items.any((existing) => existing.id == n.id)) return;
      _items = [n, ..._items];
      if (!n.isRead) _unread = _unread + 1;
      notifyListeners();
    } catch (_) {
      // Malformed payload — wait for the next refresh cycle.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _service.list(page: 1, limit: 50);
      _items = r.items;
      _unread = r.unread;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnread() async {
    try {
      _unread = await _service.unreadCount();
      notifyListeners();
    } catch (_) {
      // Silently ignore — bell badge is non-critical.
    }
  }

  Future<void> markRead(String id) async {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    final n = _items[idx];
    if (n.isRead) return;
    // Optimistic — flip locally, decrement unread, then call API.
    _items = [..._items]..[idx] = n.copyWith(isRead: true);
    _unread = (_unread - 1).clamp(0, 1 << 30);
    notifyListeners();
    try {
      await _service.markRead(id);
    } catch (_) {
      // On failure, refresh to resync truth.
      await load();
    }
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    final prev = _items;
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    _unread = 0;
    notifyListeners();
    try {
      await _service.markAllRead();
    } catch (_) {
      _items = prev;
      await load();
    }
  }

  Future<void> remove(String id) async {
    final prev = _items;
    final removed = _items.firstWhere(
      (n) => n.id == id,
      orElse: () => AppNotification(
        id: '',
        kind: NotificationKind.system,
        role: 'seeker',
        title: '',
        body: '',
        data: const {},
        isRead: true,
        createdAt: DateTime.now(),
      ),
    );
    if (removed.id.isEmpty) return;
    _items = _items.where((n) => n.id != id).toList();
    if (!removed.isRead) {
      _unread = (_unread - 1).clamp(0, 1 << 30);
    }
    notifyListeners();
    try {
      await _service.remove(id);
    } catch (_) {
      _items = prev;
      notifyListeners();
    }
  }
}

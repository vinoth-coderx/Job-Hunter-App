import '../models/notification_model.dart';
import 'api_client.dart';

/// Wraps `/api/v1/notifications` — the unified inbox for application
/// status changes, interview invites, message pings, profile views, and
/// auto-apply summaries.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final ApiClient _api = ApiClient.instance;

  Future<({List<AppNotification> items, int unread, int total})> list({
    int page = 1,
    int limit = 30,
    bool unreadOnly = false,
    String? role,
  }) async {
    final qs = <String, dynamic>{
      'page': '$page',
      'limit': '$limit',
      if (unreadOnly) 'unread': 'true',
      if (role != null) 'role': role,
    };
    final raw = await _api.get('notifications', query: qs);
    final items = ApiClient.unwrapList(raw)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    // Backend returns `{ success, data: [...], meta: { unread, total, ... } }`.
    // ApiClient only exposes data unwrappers; pull meta directly off the
    // outer envelope when present.
    int unread = 0;
    int total = items.length;
    if (raw is Map<String, dynamic> && raw['meta'] is Map) {
      final meta = raw['meta'] as Map;
      unread = (meta['unread'] as num?)?.toInt() ?? 0;
      total = (meta['total'] as num?)?.toInt() ?? items.length;
    }
    return (items: items, unread: unread, total: total);
  }

  Future<int> unreadCount() async {
    final raw = await _api.get('notifications/unread-count');
    final m = ApiClient.unwrapMap(raw);
    return (m['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.put('notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.put('notifications/read-all');
  }

  Future<void> remove(String id) async {
    await _api.delete('notifications/$id');
  }
}

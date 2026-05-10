import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models/conversation_model.dart';
import '../data/services/api_client.dart';
import '../data/services/chat_service.dart';

class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ChatService _service = ChatService.instance;
  bool _lifecycleAttached = false;

  List<Conversation> _conversations = [];
  // Messages keyed by conversation id, ascending sentAt.
  final Map<String, List<ChatMessage>> _messages = {};
  final Set<String> _typingPeers = {};
  bool _loadingConversations = false;
  String? _error;

  StreamSubscription<({String conversationId, ChatMessage message})>?
      _msgSub;
  StreamSubscription<({String? conversationId, String userId, bool typing})>?
      _typingSub;
  StreamSubscription<({String conversationId, String readerUserId})>?
      _readSub;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get loadingConversations => _loadingConversations;
  String? get error => _error;

  List<ChatMessage> messagesFor(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? const []);

  bool isPeerTyping(String userId) => _typingPeers.contains(userId);

  /// Total unread across every conversation. Drives the chat tab badge.
  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  // ── Lifecycle ────────────────────────────────────────────────────

  /// Wires socket + REST; safe to call repeatedly. Caller (typically
  /// `RoleAwareMainScreen`) should call this after sign-in. Also registers
  /// this provider as an app-lifecycle observer so the socket is forced
  /// to reconnect when the user pulls the app back from background — the
  /// OS routinely tears down idle sockets, and without this handshake the
  /// chat list would only refresh after the user navigates away and back
  /// (i.e. the "vella poittu ulla vantha thaa varuthu" behaviour).
  void start() {
    final base = _socketBase();
    if (base != null) _service.connect(baseUrl: base);

    if (!_lifecycleAttached) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleAttached = true;
    }

    _msgSub ??= _service.onMessage.listen((evt) {
      final list = _messages[evt.conversationId] ?? <ChatMessage>[];
      // Drop dupes — server fans the same message back to the sender too.
      if (list.any((m) => m.id == evt.message.id)) return;
      // Role gate — the socket is authenticated per user, not per role,
      // so an account that wears both hats receives events for both
      // sides. If the conversation isn't in the current role's list,
      // refetch (server filters by role) and bail. This stops a hirer-
      // side message from polluting the seeker inbox cache (or vice
      // versa) on dual-role accounts.
      final inCurrentRole =
          _conversations.any((c) => c.id == evt.conversationId);
      if (!inCurrentRole) {
        loadConversations();
        return;
      }
      _messages[evt.conversationId] = [...list, evt.message];
      // bumpUnread=true: this code path only runs for genuinely new
      // messages (the dedup above filters out our own optimistic copies),
      // so the bottom-nav / header chat badge should update live without
      // waiting for a manual refresh.
      _bumpConversationFor(evt.message, bumpUnread: true);
      notifyListeners();
    });

    _typingSub ??= _service.onTyping.listen((evt) {
      if (evt.typing) {
        _typingPeers.add(evt.userId);
      } else {
        _typingPeers.remove(evt.userId);
      }
      notifyListeners();
    });

    _readSub ??= _service.onReadReceipt.listen((evt) {
      // Mark all my outgoing messages in this conversation as read.
      final list = _messages[evt.conversationId];
      if (list == null) return;
      _messages[evt.conversationId] = [
        for (final m in list)
          m.senderId != evt.readerUserId
              ? ChatMessage(
                  id: m.id,
                  conversationId: m.conversationId,
                  senderId: m.senderId,
                  receiverId: m.receiverId,
                  type: m.type,
                  content: m.content,
                  isRead: true,
                  readAt: m.readAt ?? DateTime.now(),
                  sentAt: m.sentAt,
                )
              : m,
      ];
      notifyListeners();
    });
  }

  /// Convert the REST base URL ("http://host/api/v1") into the socket
  /// origin ("http://host"). Returns null if the URL can't be parsed,
  /// in which case the socket is silently skipped (REST still works).
  ///
  /// Built manually rather than via `Uri.replace` because socket_io_client
  /// 2.0.3+1's parseqs.decode crashes on an empty query string, and any
  /// stray `?` in the URL trips that path. Manually concatenating
  /// scheme/host/port guarantees no query component.
  String? _socketBase() {
    final raw = ApiClient.instance.baseUrl;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Active role the chat list is scoped to. Drives the `?role=…` query
  /// when fetching from the server, the local filter on every getter,
  /// and the unread-badge aggregation. Set via [setActiveRole] when the
  /// user toggles between seeker and hirer mode so the inbox immediately
  /// shows only the threads relevant to that role.
  String _activeRole = 'seeker';
  String get activeRole => _activeRole;

  /// Switch the chat scope to [role]. Re-fetches the list so the next
  /// emission contains only conversations the server tagged with this
  /// `viewerRole`. Cheap no-op when the role is already current.
  Future<void> setActiveRole(String role) async {
    final next = role == 'hirer' ? 'hirer' : 'seeker';
    if (_activeRole == next) return;
    _activeRole = next;
    // Drop cached threads + cached messages from the previous role so
    // neither the inbox list nor an open chat surfaces the other side
    // of a dual-role account. Without this, a socket message tagged
    // for the hirer side could remain in `_messages` and bleed into
    // the seeker view (or vice-versa).
    _conversations = const [];
    _messages.clear();
    _typingPeers.clear();
    notifyListeners();
    await loadConversations();
  }

  Future<void> loadConversations() async {
    _loadingConversations = true;
    _error = null;
    notifyListeners();
    try {
      _conversations = await _service.listConversations(role: _activeRole);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingConversations = false;
      notifyListeners();
    }
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final list = await _service.listMessages(conversationId);
    _messages[conversationId] = list;
    notifyListeners();
    return list;
  }

  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return null;
    try {
      final m = await _service.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
      );
      // Optimistic placement — socket fanout will dedupe via the id check
      // in the message subscription.
      final list = _messages[conversationId] ?? <ChatMessage>[];
      if (!list.any((x) => x.id == m.id)) {
        _messages[conversationId] = [...list, m];
      }
      _bumpConversationFor(m);
      notifyListeners();
      return m;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Conversation> openConversationWith({
    required String otherUserId,
    String? jobId,
    String? applicationId,
  }) async {
    final c = await _service.startConversation(
      otherUserId: otherUserId,
      jobId: jobId,
      applicationId: applicationId,
    );
    if (!_conversations.any((x) => x.id == c.id)) {
      _conversations = [c, ..._conversations];
    }
    notifyListeners();
    return c;
  }

  Future<void> markConversationRead(String conversationId) async {
    try {
      await _service.markRead(conversationId);
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0) {
        final c = _conversations[idx];
        _conversations[idx] = Conversation(
          id: c.id,
          participants: c.participants,
          applicationId: c.applicationId,
          jobId: c.jobId,
          lastMessage: c.lastMessage,
          unreadCount: 0,
          updatedAt: c.updatedAt,
          companyName: c.companyName,
          companyLogo: c.companyLogo,
          jobTitle: c.jobTitle,
          viewerRole: c.viewerRole,
        );
        notifyListeners();
      }
    } catch (_) {
      // best-effort — UI already collapsed the badge optimistically.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume → force a socket re-handshake. ChatService.connect is
    // idempotent (no-op if the socket is still connected on the same
    // token), but an OS-suspended socket reports as connected locally
    // until the next ping fails — a cheap reconnect dispose/rebuild is
    // safer than waiting for socket.io's own keepalive to time out.
    // Also re-fetches the conversation list so the badge is right
    // even if events were dropped while suspended.
    if (state == AppLifecycleState.resumed) {
      final base = _socketBase();
      if (base != null) _service.connect(baseUrl: base);
      loadConversations();
    }
  }

  /// Tear down the socket + clear cached state on logout. AuthProvider
  /// calls this so the next user doesn't inherit the previous user's
  /// conversations/messages, and the stale socket (auth'd as the old
  /// user) doesn't keep emitting events.
  void signOut() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _msgSub = null;
    _typingSub = null;
    _readSub = null;
    _service.disconnect();
    _conversations = [];
    _messages.clear();
    _typingPeers.clear();
    _loadingConversations = false;
    _error = null;
    notifyListeners();
  }

  void emitTypingStart({String? conversationId, required String otherUserId}) =>
      _service.emitTypingStart(
          conversationId: conversationId, otherUserId: otherUserId);

  void emitTypingStop({String? conversationId, required String otherUserId}) =>
      _service.emitTypingStop(
          conversationId: conversationId, otherUserId: otherUserId);

  /// Move the conversation to the top of the list and update its
  /// `lastMessage` to [m]. When [bumpUnread] is true, also increment the
  /// local unread counter — used by the socket listener for genuinely
  /// new incoming messages so the chat badge updates live.
  ///
  /// If the conversation isn't in the local cache yet (e.g. someone
  /// started a fresh thread with us), trigger a full reload so it shows
  /// up rather than being silently dropped.
  void _bumpConversationFor(ChatMessage m, {bool bumpUnread = false}) {
    final idx = _conversations.indexWhere((c) => c.id == m.conversationId);
    if (idx < 0) {
      // Unknown conversation — fall back to a fresh fetch so the new
      // thread appears in the list and the badge updates.
      loadConversations();
      return;
    }
    final old = _conversations[idx];
    final updated = Conversation(
      id: old.id,
      participants: old.participants,
      applicationId: old.applicationId,
      jobId: old.jobId,
      lastMessage: ChatLastMessage(
        content: m.content,
        sentAt: m.sentAt,
        senderId: m.senderId,
      ),
      unreadCount: bumpUnread ? old.unreadCount + 1 : old.unreadCount,
      updatedAt: m.sentAt,
      companyName: old.companyName,
      companyLogo: old.companyLogo,
      jobTitle: old.jobTitle,
      viewerRole: old.viewerRole,
    );
    _conversations
      ..removeAt(idx)
      ..insert(0, updated);
  }

  @override
  void dispose() {
    if (_lifecycleAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleAttached = false;
    }
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _service.disconnect();
    super.dispose();
  }
}

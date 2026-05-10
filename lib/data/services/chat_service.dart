import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/conversation_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Combined REST + Socket.IO surface for chat. Socket connection is
/// optional — REST works on its own; the socket layer adds real-time
/// fan-out for incoming messages, typing indicators, and read receipts.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final ApiClient _api = ApiClient.instance;

  // ── REST ─────────────────────────────────────────────────────────

  Future<List<Conversation>> listConversations({String? role}) async {
    final query = (role == 'seeker' || role == 'hirer') ? {'role': role} : null;
    final raw = await _api.get('conversations', query: query);
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList();
  }

  Future<Conversation> startConversation({
    required String otherUserId,
    String? jobId,
    String? applicationId,
  }) async {
    final raw = await _api.post('conversations', body: {
      'otherUserId': otherUserId,
      if (jobId != null) 'jobId': jobId,
      if (applicationId != null) 'applicationId': applicationId,
    });
    return Conversation.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<List<ChatMessage>> listMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final raw = await _api.get('conversations/$conversationId/messages',
        query: {'page': page, 'limit': limit});
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
  }) async {
    final raw = await _api.post(
      'conversations/$conversationId/messages',
      body: {'content': content, 'type': type},
    );
    return ChatMessage.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<void> markRead(String conversationId) =>
      _api.put('conversations/$conversationId/read');

  // ── Socket.IO ───────────────────────────────────────────────────

  io.Socket? _socket;
  String? _connectedWithToken;

  // Broadcast streams the UI listens to. The socket is one connection per
  // user — we surface every server-pushed event the app cares about as a
  // dedicated typed stream so providers can subscribe in isolation.
  final _messageController = StreamController<({String conversationId, ChatMessage message})>.broadcast();
  final _typingController = StreamController<({String? conversationId, String userId, bool typing})>.broadcast();
  final _readReceiptController = StreamController<({String conversationId, String readerUserId})>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _applicationStatusController = StreamController<
      ({String applicationId, String jobId, String status})>.broadcast();
  final _applicantNewController = StreamController<
      ({String applicationId, String jobId, double? matchScore})>.broadcast();

  Stream<({String conversationId, ChatMessage message})> get onMessage =>
      _messageController.stream;
  Stream<({String? conversationId, String userId, bool typing})> get onTyping =>
      _typingController.stream;
  Stream<({String conversationId, String readerUserId})> get onReadReceipt =>
      _readReceiptController.stream;
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;
  Stream<({String applicationId, String jobId, String status})>
      get onApplicationStatus => _applicationStatusController.stream;
  Stream<({String applicationId, String jobId, double? matchScore})>
      get onApplicantNew => _applicantNewController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects the socket using the stored access token. Idempotent while
  /// the same auth token is in use; if the token has rotated (e.g. after
  /// logout/re-login), tears down the stale socket and reconnects.
  void connect({required String baseUrl}) {
    final token = StorageService.getAccessToken();
    if (token == null || token.isEmpty) return;
    if (_socket != null &&
        _socket!.connected &&
        _connectedWithToken == token) {
      return;
    }
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }
    _connectedWithToken = token;

    // Auto-reconnect explicitly enabled with bounded backoff so a
    // mobile-network blip (or backend cold-start on Render) recovers
    // without forcing the user to restart the app. Default would already
    // reconnect, but the explicit settings keep it predictable.
    final s = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(8000)
          .setTimeout(15000)
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      // connected — no-op, listeners report state via isConnected.
    });
    s.onDisconnect((_) {});
    s.onError((_) {});

    s.on('message:new', (data) {
      if (data is Map) {
        final conversationId = (data['conversationId'] ?? '').toString();
        final m = data['message'];
        if (m is Map<String, dynamic>) {
          _messageController.add((
            conversationId: conversationId,
            message: ChatMessage.fromJson(m),
          ));
        }
      }
    });
    s.on('typing:start', (data) {
      if (data is Map) {
        _typingController.add((
          conversationId: data['conversationId']?.toString(),
          userId: (data['userId'] ?? '').toString(),
          typing: true,
        ));
      }
    });
    s.on('typing:stop', (data) {
      if (data is Map) {
        _typingController.add((
          conversationId: data['conversationId']?.toString(),
          userId: (data['userId'] ?? '').toString(),
          typing: false,
        ));
      }
    });
    s.on('read:receipt', (data) {
      if (data is Map) {
        _readReceiptController.add((
          conversationId: (data['conversationId'] ?? '').toString(),
          readerUserId: (data['readerUserId'] ?? '').toString(),
        ));
      }
    });
    s.on('notification:new', (data) {
      if (data is Map) {
        _notificationController.add(Map<String, dynamic>.from(data));
      }
    });
    s.on('application:status', (data) {
      if (data is Map) {
        _applicationStatusController.add((
          applicationId: (data['applicationId'] ?? '').toString(),
          jobId: (data['jobId'] ?? '').toString(),
          status: (data['status'] ?? '').toString(),
        ));
      }
    });
    s.on('applicant:new', (data) {
      if (data is Map) {
        final score = data['matchScore'];
        _applicantNewController.add((
          applicationId: (data['applicationId'] ?? '').toString(),
          jobId: (data['jobId'] ?? '').toString(),
          matchScore: score is num ? score.toDouble() : null,
        ));
      }
    });

    s.connect();
    _socket = s;
  }

  void emitTypingStart({String? conversationId, required String otherUserId}) {
    _socket?.emit('typing:start', {
      if (conversationId != null) 'conversationId': conversationId,
      'otherUserId': otherUserId,
    });
  }

  void emitTypingStop({String? conversationId, required String otherUserId}) {
    _socket?.emit('typing:stop', {
      if (conversationId != null) 'conversationId': conversationId,
      'otherUserId': otherUserId,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectedWithToken = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _readReceiptController.close();
    _notificationController.close();
    _applicationStatusController.close();
    _applicantNewController.close();
  }
}

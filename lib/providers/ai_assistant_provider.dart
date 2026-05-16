import 'package:flutter/foundation.dart';

import '../data/models/ai_combined_models.dart';
import '../data/models/ai_quota_model.dart';
import '../data/services/ai_service.dart';

/// State for the AI Career Assistant chat. Holds the running history,
/// the in-flight "model is typing…" flag, and the last failed send so
/// the UI can show a retry button without losing the message text.
///
/// History is loaded lazily on first open and persisted server-side via
/// /ai/chat — so jumping out of the screen and back in restores the
/// conversation. Clear() wipes both local + server.
class AiAssistantProvider extends ChangeNotifier {
  final List<AiChatTurn> _history = [];
  bool _loadingHistory = false;
  bool _sending = false;
  /// Set when the most recent send failed; carries the unsent text so
  /// the UI can offer a one-tap retry.
  String? _pendingFailedMessage;
  String? _error;
  AiQuotaExceededException? _quotaError;
  bool _historyLoaded = false;

  List<AiChatTurn> get history => List.unmodifiable(_history);
  bool get isLoadingHistory => _loadingHistory;
  bool get isSending => _sending;
  bool get hasHistory => _history.isNotEmpty;
  String? get pendingFailedMessage => _pendingFailedMessage;
  String? get error => _error;
  AiQuotaExceededException? get quotaError => _quotaError;
  bool get historyLoaded => _historyLoaded;

  Future<void> ensureLoaded() async {
    if (_historyLoaded || _loadingHistory) return;
    _loadingHistory = true;
    notifyListeners();
    try {
      final h = await AiService.instance.chatHistory();
      _history
        ..clear()
        ..addAll(h);
      _historyLoaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  /// Live-streaming partial reply. Set while the model is producing
  /// the next bubble — the chat screen reads this to render an
  /// ephemeral bubble that grows as deltas arrive, then clears once
  /// the final turn is appended to [_history].
  String _streamingReply = '';
  String get streamingReply => _streamingReply;
  bool get isStreaming => _sending && _streamingReply.isNotEmpty;

  /// Send a message. Tries the SSE streaming path first; on any
  /// non-quota failure, falls back to the non-streaming `/ai/chat`
  /// endpoint so the chat keeps working when streaming isn't
  /// available (Gemini key missing, infra blocking SSE, etc).
  Future<AiQuota?> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return null;
    _sending = true;
    _streamingReply = '';
    _error = null;
    _quotaError = null;
    _pendingFailedMessage = null;
    final tsNow = DateTime.now().millisecondsSinceEpoch;
    _history.add(AiChatTurn(role: 'user', content: trimmed, ts: tsNow));
    notifyListeners();

    AiQuota? lastQuota;
    var streamProducedReply = false;

    try {
      await for (final ev in AiService.instance.chatStream(trimmed)) {
        if (ev is StreamChatChunk) {
          _streamingReply += ev.delta;
          notifyListeners();
        } else if (ev is StreamChatQuota) {
          lastQuota = ev.quota;
        } else if (ev is StreamChatDone) {
          streamProducedReply = ev.reply.trim().isNotEmpty;
          if (streamProducedReply) {
            _history.add(AiChatTurn(
              id: ev.turnId,
              role: 'model',
              content: ev.reply.trim(),
              ts: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        } else if (ev is StreamChatError) {
          throw Exception(ev.message);
        }
      }
      return lastQuota;
    } on AiQuotaExceededException catch (e) {
      _rollbackLastUser(trimmed);
      _quotaError = e;
      _pendingFailedMessage = trimmed;
      return e.quota;
    } catch (streamErr) {
      // Streaming failed mid-flight (or never opened). Fall back to
      // the non-streaming endpoint — the user shouldn't lose their
      // message just because SSE flaked. We DON'T rollback here yet;
      // the fallback call below replaces or rolls back accordingly.
      try {
        final res = await AiService.instance.chatSend(trimmed);
        final reply = res.data?.reply.trim();
        if (reply != null && reply.isNotEmpty) {
          _history.add(AiChatTurn(
            role: 'model',
            content: reply,
            ts: DateTime.now().millisecondsSinceEpoch,
          ));
        }
        return res.quota ?? lastQuota;
      } on AiQuotaExceededException catch (e) {
        _rollbackLastUser(trimmed);
        _quotaError = e;
        _pendingFailedMessage = trimmed;
        return e.quota;
      } catch (_) {
        _rollbackLastUser(trimmed);
        _error = streamErr.toString();
        _pendingFailedMessage = trimmed;
        return lastQuota;
      }
    } finally {
      _sending = false;
      _streamingReply = '';
      notifyListeners();
    }
  }

  void _rollbackLastUser(String content) {
    if (_history.isNotEmpty &&
        _history.last.role == 'user' &&
        _history.last.content == content) {
      _history.removeLast();
    }
  }

  Future<AiQuota?> retry() async {
    final pending = _pendingFailedMessage;
    if (pending == null) return null;
    return send(pending);
  }

  void dismissError() {
    _error = null;
    _quotaError = null;
    _pendingFailedMessage = null;
    notifyListeners();
  }

  Future<void> clear() async {
    try {
      await AiService.instance.chatClear();
    } catch (_) {
      // best effort — clear local even if remote clear fails so the user
      // isn't stuck staring at a chat they think they cleared.
    }
    _history.clear();
    _pendingFailedMessage = null;
    _error = null;
    _quotaError = null;
    notifyListeners();
  }
}

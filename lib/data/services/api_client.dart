import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/app_constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => message;
}

/// Convert any error thrown from an HTTP call (network, timeout, parse,
/// or an `ApiException` from a non-2xx response) into a single short
/// user-readable sentence. Use this anywhere a raw exception would
/// otherwise leak through to a snackbar — `'Upload failed: $e'` style
/// strings should pass `e` through here first.
///
/// Rules:
///   • `ApiException` with 5xx  → server is busy / try later
///   • `ApiException` with 401/403 → session expired
///   • `ApiException` with 0      → backend unreachable (set by [_send])
///   • Any other `ApiException`   → use the backend's own message
///                                  (already passes through Zod / domain
///                                  validation — safe to show)
///   • SocketException / ClientException / "connection refused" /
///     "failed host lookup" / "network is unreachable" → unreachable
///   • TimeoutException / "timed out"          → slow / try again
///   • Anything else                           → generic fallback
String friendlyMessage(Object error) {
  if (error is ApiException) {
    if (error.statusCode >= 500) {
      return 'Our servers are taking a break. Please try again in a minute.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'Your session expired. Please sign in again.';
    }
    if (error.statusCode == 0) {
      return "Can't reach the server. Check your connection and try again in a minute.";
    }
    // 4xx with a backend message that's already user-facing (Zod /
    // controller-side validation messages, "Email already in use", …).
    return error.message;
  }
  final s = error.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('connection refused') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection closed') ||
      s.contains('handshake')) {
    return "Can't reach the server. Check your connection and try again in a minute.";
  }
  if (s.contains('timeoutexception') ||
      s.contains('timed out') ||
      s.contains('deadline exceeded')) {
    return 'Server is taking too long to respond. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

typedef _Sender = Future<http.Response> Function(String accessToken);

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final http.Client _http = http.Client();

  /// Fired the first time an authenticated request comes back 401 — the
  /// token is either expired, revoked, or otherwise unusable. Wired in
  /// main.dart to wipe local auth state and bounce the user to the login
  /// screen so a stale session can't sit on a privileged screen.
  ///
  /// One-shot per session: when many in-flight requests race and all 401
  /// at once, only the first triggers the redirect. Reset the latch via
  /// [resetUnauthorizedFlag] after a fresh successful sign-in.
  void Function()? onUnauthorized;
  bool _unauthorizedFired = false;

  void resetUnauthorizedFlag() {
    _unauthorizedFired = false;
  }

  String get baseUrl => _rewriteForPlatform(AppConstants.apiBaseUrl);

  /// Loopback hosts mean different things on different devices:
  ///   - iOS simulator / macOS / web    → localhost = the dev machine ✓
  ///   - Android emulator               → localhost = the emulator itself ✗
  ///                                       (use 10.0.2.2 to reach host)
  ///   - Physical device                → localhost = the device itself ✗
  ///                                       (configure a LAN URL instead)
  /// Auto-rewrite the loopback host so the same constant works across
  /// iOS sim + Android emulator without the dev thinking about it.
  String _rewriteForPlatform(String url) {
    if (kIsWeb) return url;
    if (!Platform.isAndroid) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host;
    if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return url;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final fullBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final raw = '$fullBase$cleanPath';
    final uri = Uri.parse(raw);
    if (query == null || query.isEmpty) return uri;
    final cleanQuery = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is Iterable) {
        cleanQuery[k] = v.join(',');
      } else {
        cleanQuery[k] = v.toString();
      }
    });
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...cleanQuery,
    });
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _send(
      (token) => _http.get(_uri(path, query), headers: _headers(token, auth)),
      auth: auth,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _send(
      (token) => _http.post(
        _uri(path, query),
        headers: _headers(token, auth, json: true),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _send(
      (token) => _http.patch(
        _uri(path, query),
        headers: _headers(token, auth, json: true),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _send(
      (token) => _http.put(
        _uri(path, query),
        headers: _headers(token, auth, json: true),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _send(
      (token) =>
          _http.delete(_uri(path, query), headers: _headers(token, auth)),
      auth: auth,
    );
  }

  Future<dynamic> uploadFile(
    String path, {
    required String field,
    String? filePath,
    List<int>? bytes,
    String? filename,
    Map<String, String>? fields,
    String method = 'POST',
    String? contentType,
    bool auth = true,
  }) {
    assert(
      filePath != null || bytes != null,
      'uploadFile needs either filePath or bytes',
    );
    return _send(
      (token) async {
        final req = http.MultipartRequest(method, _uri(path));
        if (auth && token.isNotEmpty) {
          req.headers['Authorization'] = 'Bearer $token';
        }
        if (fields != null) req.fields.addAll(fields);
        if (filePath != null) {
          req.files.add(
            await http.MultipartFile.fromPath(
              field,
              filePath,
              contentType:
                  contentType != null ? MediaType.parse(contentType) : null,
            ),
          );
        } else {
          req.files.add(
            http.MultipartFile.fromBytes(
              field,
              bytes!,
              filename: filename,
              contentType:
                  contentType != null ? MediaType.parse(contentType) : null,
            ),
          );
        }
        final streamed = await _http.send(req);
        return http.Response.fromStream(streamed);
      },
      auth: auth,
    );
  }

  Future<http.Response> getRaw(String path, {bool auth = true}) async {
    final res = await _runWithAuth(
      (token) => _http.get(_uri(path), headers: _headers(token, auth)),
      auth: auth,
    );
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _safeMessage(res));
    }
    return res;
  }

  /// POST that returns the raw response — used when the server replies
  /// with a binary body (e.g. PDF download) rather than JSON. The same
  /// auth-refresh wrapper applies.
  Future<http.Response> postRaw(
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final res = await _runWithAuth(
      (token) => _http.post(
        _uri(path),
        headers: _headers(token, auth, json: true),
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    );
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _safeMessage(res));
    }
    return res;
  }

  Map<String, String> _headers(String token, bool auth, {bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    if (auth && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<dynamic> _send(_Sender sender, {required bool auth}) async {
    try {
      final res = await _runWithAuth(sender, auth: auth);
      return _decode(res);
    } on ApiException {
      // Backend-side error with a known status; already user-friendly.
      rethrow;
    } catch (e) {
      // SocketException / ClientException / TimeoutException / DNS /
      // TLS handshake — none of these belong in a UI snackbar verbatim.
      // Wrap with status 0 so `friendlyMessage` and `toString()` both
      // surface a clean "Can't reach the server…" message.
      throw ApiException(0, friendlyMessage(e));
    }
  }

  Future<http.Response> _runWithAuth(_Sender sender,
      {required bool auth}) async {
    final token = auth ? (StorageService.getAccessToken() ?? '') : '';
    final res = await sender(token);
    if (auth && res.statusCode == 401) {
      // No refresh-token dance — token is dead, kick the user back to
      // login immediately so they can re-authenticate. The latch in
      // [_handleUnauthorized] keeps a burst of parallel 401s from
      // navigating multiple times.
      await _handleUnauthorized();
    }
    return res;
  }

  Future<void> _handleUnauthorized() async {
    if (_unauthorizedFired) return;
    _unauthorizedFired = true;
    await StorageService.clearTokens();
    final cb = onUnauthorized;
    if (cb != null) cb();
  }

  dynamic _decode(http.Response res) {
    final body = res.body;
    Map<String, dynamic>? json;
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) json = decoded;
        if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
      } catch (_) {
        // not json; fall through
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw ApiException(
      res.statusCode,
      _extractMessage(json) ?? 'Request failed (${res.statusCode})',
      json,
    );
  }

  String _safeMessage(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return _extractMessage(decoded) ?? 'Request failed (${res.statusCode})';
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  String? _extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final msg = body['message'] ?? body['error'];
    if (msg is String) return msg;
    if (msg is Map && msg['message'] is String) return msg['message'] as String;
    return null;
  }

  // Helpers used by services to unwrap { success, data } envelopes.
  static T unwrap<T>(dynamic raw) {
    if (raw is Map<String, dynamic> && raw.containsKey('data')) {
      return raw['data'] as T;
    }
    return raw as T;
  }

  static Map<String, dynamic> unwrapMap(dynamic raw) =>
      unwrap<Map<String, dynamic>>(raw);

  static List<dynamic> unwrapList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is List) return raw['data'] as List;
      if (raw['data'] is Map<String, dynamic>) {
        final inner = raw['data'] as Map<String, dynamic>;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['results'] is List) return inner['results'] as List;
      }
      if (raw['items'] is List) return raw['items'] as List;
    }
    return const [];
  }

  // For uploads from File, used by services so they don't depend on dart:io.
  Future<dynamic> uploadFromFile(
    String path, {
    required String field,
    required File file,
    String? contentType,
    String method = 'POST',
  }) =>
      uploadFile(
        path,
        field: field,
        filePath: file.path,
        method: method,
        contentType: contentType,
      );
}

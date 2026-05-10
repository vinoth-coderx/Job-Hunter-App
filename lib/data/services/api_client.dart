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

typedef _Sender = Future<http.Response> Function(String accessToken);

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final http.Client _http = http.Client();
  Future<bool>? _refreshing;

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

  Map<String, String> _headers(String token, bool auth, {bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    if (auth && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<dynamic> _send(_Sender sender, {required bool auth}) async {
    final res = await _runWithAuth(sender, auth: auth);
    return _decode(res);
  }

  Future<http.Response> _runWithAuth(_Sender sender,
      {required bool auth}) async {
    final token = auth ? (StorageService.getAccessToken() ?? '') : '';
    var res = await sender(token);
    if (auth && res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = StorageService.getAccessToken() ?? '';
        res = await sender(newToken);
      }
    }
    return res;
  }

  Future<bool> _tryRefresh() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = StorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await _http.post(
        _uri('auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode != 200) {
        await StorageService.clearTokens();
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final payload = (data['data'] ?? data) as Map<String, dynamic>;
      final newAccess = payload['accessToken'] as String?;
      final newRefresh =
          (payload['refreshToken'] as String?) ?? refreshToken;
      if (newAccess == null) return false;
      await StorageService.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } catch (_) {
      return false;
    }
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Authentication service backed by the Job Hunter REST API.
///
/// Endpoints (relative to `/api/v1`):
///   POST   /auth/register
///   POST   /auth/login
///   POST   /auth/refresh
///   GET    /auth/me
///   POST   /auth/logout
///   GET    /auth/google         (browser-only OAuth start)
class AuthService {
  final ApiClient _api = ApiClient.instance;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn _google() {
    return _googleSignIn ??= GoogleSignIn(
      serverClientId:
          AppConstants.googleWebClientId.isEmpty
              ? null
              : AppConstants.googleWebClientId,
      scopes: const ['email', 'profile'],
    );
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    if (fullName.trim().isEmpty) throw 'Please enter your name';
    _validateEmail(email);
    _validatePassword(password);

    final body = await _api.post(
      'auth/register',
      auth: false,
      body: {
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      },
    );
    return _persistAuth(body);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    if (password.isEmpty) throw 'Password required';

    final body = await _api.post(
      'auth/login',
      auth: false,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );
    return _persistAuth(body);
  }

  Future<UserModel> me() async {
    final body = await _api.get('auth/me');
    final data = ApiClient.unwrapMap(body);
    final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
    final user = UserModel.fromApiJson(userJson);
    await StorageService.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    final refresh = StorageService.getRefreshToken();
    try {
      await _api.post(
        'auth/logout',
        body: refresh == null ? null : {'refreshToken': refresh},
      );
    } catch (_) {
      // server-side logout failure shouldn't block local clean up
    }
    try {
      await _googleSignIn?.signOut();
    } catch (_) {/* ignore */}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {/* Firebase not configured / already signed out — ignore. */}
    await StorageService.logout();
  }

  /// Backward-compatible wrappers used by [AuthProvider].
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) =>
      login(email: email, password: password);

  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) =>
      register(
        email: email,
        password: password,
        fullName: name,
        phone: phone,
      );

  /// Native Google Sign-In: opens the system account picker, gets an ID token
  /// from Google, then exchanges it for our own access/refresh tokens via
  /// `POST /auth/google/mobile { idToken }`.
  Future<UserModel> signInWithGoogle() async {
    if (!AppConstants.googleAuthConfigured) {
      throw 'Google sign-in is not configured. Add GOOGLE_WEB_CLIENT_ID to env/<env>.json and re-run.';
    }
    final google = _google();
    GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } on PlatformException catch (e) {
      final msg = e.message ?? '';
      // code 10 = DEVELOPER_ERROR: SHA-1 / package name not registered
      // as an Android OAuth client in Google Cloud Console (or the
      // Web Client ID belongs to a different project). The picker
      // appears briefly and then auto-closes.
      if (e.code == 'sign_in_failed' && msg.contains('10')) {
        throw 'Google sign-in misconfigured (DEVELOPER_ERROR 10). '
            'Register this app\'s package name + debug SHA-1 as an '
            'Android OAuth client in the same Google Cloud project as '
            'GOOGLE_WEB_CLIENT_ID.';
      }
      // ApiException 7 = NETWORK_ERROR. On a working network this almost
      // always means the Android OAuth client (package name + SHA-1)
      // isn't registered in Google Cloud Console for this Firebase /
      // OAuth project — Play Services tries to validate the app and
      // can't, so it surfaces a misleading "network_error". Telling the
      // user to "check your internet" wastes their time.
      if (e.code == 'network_error' || msg.contains('ApiException: 7')) {
        throw 'Google sign-in is blocked by Play Services config. '
            'Add this app as an Android OAuth client (package: '
            'com.vinoth.jobhunter, debug SHA-1 from `gradlew '
            'signingReport`) in the same Google Cloud project as '
            'GOOGLE_WEB_CLIENT_ID, then reinstall the app.';
      }
      throw 'Google sign-in failed: ${e.code} $msg'.trim();
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
    if (account == null) {
      throw 'Sign-in cancelled';
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw 'Google did not return an ID token. Check the Web Client ID.';
    }
    final body = await _api.post(
      'auth/google/mobile',
      auth: false,
      body: {
        'idToken': idToken,
        if (auth.accessToken != null) 'accessToken': auth.accessToken,
      },
    );
    return _persistAuth(body);
  }

  /// Stateless guest session: backend issues a short-lived JWT carrying
  /// `role: 'guest'`. The token is stored just like a real auth session,
  /// so every API call automatically sends a Bearer header — no `auth:
  /// false` special-casing needed downstream. Privileged endpoints (apply,
  /// profile, subscription) still 403 the guest token, surfacing a clear
  /// "sign in to continue" path in the UI.
  Future<UserModel> loginAsGuest() async {
    final body = await _api.post('auth/guest', auth: false);
    final data = ApiClient.unwrapMap(body);
    final access = data['accessToken'] as String?;
    if (access == null || access.isEmpty) {
      throw 'Server did not return a guest token';
    }
    await StorageService.saveTokens(
      accessToken: access,
      // Guest tokens are not refreshable — store empty so api_client skips
      // the auto-refresh on 401 and surfaces the error directly.
      refreshToken: '',
    );
    final userJson = (data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final user = UserModel.fromApiJson(userJson);
    await StorageService.saveUser(user);
    return user;
  }

  // ────────────────────────────────────────────────────────────────
  // Firebase Auth hybrid flow
  //
  // The client signs in with Firebase Auth (any provider it supports),
  // hands the resulting ID token to `/auth/firebase`, and the backend
  // verifies it and returns our own JWT pair. From there everything
  // downstream is identical to the password / Google flows.
  //
  // Existing accounts that signed up via /auth/login still work — the
  // backend links the Firebase UID on first hybrid sign-in.
  // ────────────────────────────────────────────────────────────────

  Future<UserModel> signUpWithFirebase({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (name.trim().isEmpty) throw 'Please enter your name';
    _validateEmail(email);
    _validatePassword(password);

    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Set the display name on the Firebase user so other Firebase
      // features (Firestore rules, etc.) can rely on it later.
      await cred.user?.updateDisplayName(name.trim());
    } on FirebaseAuthException catch (e) {
      throw _firebaseAuthMessage(e);
    }

    final idToken = await cred.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw 'Firebase did not return an ID token';
    }

    final body = await _api.post(
      'auth/firebase',
      auth: false,
      body: {
        'idToken': idToken,
        'fullName': name.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      },
    );
    return _persistAuth(body);
  }

  Future<UserModel> signInWithFirebase({
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    if (password.isEmpty) throw 'Password required';

    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _firebaseAuthMessage(e);
    }

    final idToken = await cred.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw 'Firebase did not return an ID token';
    }

    final body = await _api.post(
      'auth/firebase',
      auth: false,
      body: {'idToken': idToken},
    );
    return _persistAuth(body);
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password is too weak — use at least 8 characters with mixed case, numbers, and a symbol';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts — try again in a moment';
      case 'network-request-failed':
        return 'Network error — check your connection and try again';
      default:
        return 'Sign-in failed: ${e.message ?? e.code}';
    }
  }

  Future<void> signOut() => logout();

  Future<UserModel> updateUser(UserModel user) async {
    await StorageService.saveUser(user);
    return user;
  }

  UserModel? get currentUser => StorageService.getUser();
  bool get isLoggedIn =>
      StorageService.isLoggedIn() &&
      (StorageService.getAccessToken() ?? '').isNotEmpty;

  Future<UserModel> _persistAuth(dynamic raw) async {
    final data = ApiClient.unwrapMap(raw);
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw 'Server did not return tokens';
    }
    await StorageService.saveTokens(
      accessToken: access,
      refreshToken: refresh,
    );
    final userJson = (data['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final user = UserModel.fromApiJson(userJson);
    await StorageService.saveUser(user);
    return user;
  }

  void _validateEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      throw 'Please enter a valid email address';
    }
  }

  void _validatePassword(String password) {
    if (password.length < 6) {
      throw 'Password must be at least 6 characters';
    }
  }
}

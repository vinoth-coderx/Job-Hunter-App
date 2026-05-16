import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
    // Drop the cached GoogleSignIn instance. Reusing the same instance
    // across a logout → re-login cycle is the known cause of "first
    // signIn() returns null" on Android — the plugin's internal client
    // gets stuck in a half-signed-out state. Building a fresh instance
    // the next time [_google] runs avoids it.
    _googleSignIn = null;
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

  /// Google Sign-In via Firebase Auth. Opens the native Google picker,
  /// exchanges the OAuth credential for a Firebase session, then hands
  /// the Firebase ID token to `/auth/firebase`. Existing accounts that
  /// signed up via the legacy `/auth/google/mobile` flow get their
  /// `firebaseUid` linked on the first hybrid sign-in — no migration
  /// step required on the user's end.
  ///
  /// Falls back to the legacy `/auth/google/mobile` endpoint when
  /// FirebaseAuth itself isn't initialised (e.g. dev build without
  /// google-services.json). Production should always take the Firebase
  /// path.
  Future<({UserModel user, bool isNewUser})> signInWithGoogle() async {
    if (!AppConstants.googleAuthConfigured) {
      throw 'Google sign-in is not configured. Add GOOGLE_WEB_CLIENT_ID to env/<env>.json and re-run.';
    }

    // Why we DON'T pre-emptively call `googleSignIn.signOut()` or
    // `disconnect()` here: on Android, the google_sign_in plugin has a
    // well-documented bug where the first `signIn()` call right after
    // a `signOut()`/`disconnect()` returns null — the picker either
    // doesn't show or returns before the user picked. The user-facing
    // symptom is "Google login needs two taps". Our `logout()` already
    // calls `googleSignIn.signOut()` when the user actually logs out,
    // so the picker arrives clean by the time they tap Sign In again.
    //
    // We *do* clear FirebaseAuth's stale `currentUser` first, since a
    // 401 redirect can drop our local tokens without touching Firebase,
    // and `signInWithCredential` will throw "credential already in use"
    // if the previous Firebase session is still hanging around.
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {/* Firebase not configured / already out — fine */}

    final account = await _resolveGoogleAccount();

    // Fetch the OAuth tokens. The google_sign_in package occasionally
    // returns a non-null account whose `authentication` resolves with a
    // null idToken on the very first call against a fresh GoogleSignIn
    // instance (no picker re-show happens — the second call uses the
    // already-signed-in account). A single retry papers over that race
    // without making the user tap again.
    GoogleSignInAuthentication googleAuth = await account.authentication;
    if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
      googleAuth = await account.authentication;
    }
    final googleIdToken = googleAuth.idToken;
    final googleAccessToken = googleAuth.accessToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw 'Google did not return an ID token. Check the Web Client ID.';
    }

    // Firebase is the only sign-in path now. The legacy
    // /auth/google/mobile fallback was removed when the backend
    // committed fully to Firebase Auth — any failure here surfaces
    // straight to the UI instead of silently downgrading.
    try {
      final cred = GoogleAuthProvider.credential(
        idToken: googleIdToken,
        accessToken: googleAccessToken,
      );
      final firebaseCred =
          await FirebaseAuth.instance.signInWithCredential(cred);
      final firebaseIdToken = await firebaseCred.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw 'Firebase did not return an ID token after Google sign-in';
      }
      final body = await _api.post(
        'auth/firebase',
        auth: false,
        body: {'idToken': firebaseIdToken},
      );
      final isNewUser = firebaseCred.additionalUserInfo?.isNewUser ?? false;
      return (user: await _persistAuth(body), isNewUser: isNewUser);
    } on FirebaseAuthException catch (e) {
      throw _firebaseAuthMessage(e);
    }
  }

  /// Pop the OS Google account picker and return the selected account.
  /// No pre-emptive signOut/disconnect — those trigger the Android
  /// "first signIn returns null" plugin bug. The picker handles account
  /// selection on its own; we only retry on null (which on Android is
  /// the only reliable signal of "the plugin swallowed the tap" vs an
  /// actual user cancellation — they're indistinguishable here, but the
  /// cost of a second picker is small compared to forcing a second tap).
  Future<GoogleSignInAccount> _resolveGoogleAccount() async {
    GoogleSignInAccount? account;
    try {
      account = await _google().signIn();
    } on PlatformException catch (e) {
      throw _googlePlatformMessage(e);
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
    if (account != null) return account;

    // First call returned null without an exception. Most often this is
    // a user cancellation, but on a freshly-rebuilt process it can also
    // be the plugin's internal singleton returning early before the
    // picker actually drew. Rebuild the GoogleSignIn instance — that
    // clears the half-warmed cache — and try once more. If the user
    // genuinely cancelled, they cancel the second picker too and we
    // surface the cancellation cleanly.
    _googleSignIn = null;
    try {
      account = await _google().signIn();
    } on PlatformException catch (e) {
      throw _googlePlatformMessage(e);
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
    if (account != null) return account;

    throw 'Sign-in cancelled';
  }

  /// User-facing error mapping for the `google_sign_in` PlatformException.
  ///
  /// Goal: never leak SDK error codes, stack traces, or setup instructions
  /// into the UI — those belong in logs. The user gets one of three short,
  /// recoverable messages:
  ///   * "No internet…"            → device offline / Play Services can't
  ///                                 reach Google (ApiException 7)
  ///   * "Try again"               → transient/unknown SDK failure
  ///   * "Sign-in cancelled"       → user dismissed the picker
  ///
  /// DEVELOPER_ERROR (code 10) is a build-time misconfig that the user can
  /// do nothing about, so we still surface "Try again later" rather than
  /// the SHA-1 instructions — those go to `debugPrint` for the developer.
  String _googlePlatformMessage(PlatformException e) {
    final msg = e.message ?? '';
    if (kDebugMode) {
      debugPrint('GoogleSignIn PlatformException: code=${e.code} msg=$msg');
    }

    // Cancellation — surface as a softer message than "failed".
    if (e.code == 'sign_in_canceled' ||
        e.code == 'sign_in_cancelled' ||
        msg.toLowerCase().contains('cancel')) {
      return 'Sign-in cancelled';
    }

    // ApiException 7 = NETWORK_ERROR. Also catch the explicit network_error
    // code emitted by some plugin versions.
    if (e.code == 'network_error' || msg.contains('ApiException: 7')) {
      return 'No internet. Check your connection and try again.';
    }

    // DEVELOPER_ERROR 10 — build/config issue (wrong SHA-1, wrong client
    // ID, etc). User can't fix this; we log loudly and show a generic
    // message so the UI doesn't lecture them about gradlew commands.
    if ((e.code == 'sign_in_failed' && msg.contains('10')) ||
        msg.contains('ApiException: 10')) {
      if (kDebugMode) {
        debugPrint(
          'GoogleSignIn DEVELOPER_ERROR: SHA-1 / package / web client ID '
          'mismatch. Run `cd android && ./gradlew signingReport` and check '
          'the Android OAuth client in Google Cloud.',
        );
      }
      return 'Google sign-in is unavailable right now. Try again later.';
    }

    // SIGN_IN_FAILED — catch-all for "Google said no". Often means the
    // Firebase Google provider is disabled.
    if (msg.contains('ApiException: 12500')) {
      return 'Google sign-in failed. Please try again.';
    }

    // Everything else — soft fallback. No raw error codes in the UI.
    return 'Google sign-in failed. Please try again.';
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

  /// Sends a Firebase email-verification link to the currently signed-in
  /// Firebase user. Throws if no user is signed in (shouldn't happen
  /// from authenticated app screens — caller can show a generic error).
  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw 'You need to sign in again before requesting verification.';
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _firebaseAuthMessage(e);
    }
  }

  /// After the user clicks the verification link in their email, call
  /// this to re-fetch the Firebase user state and trade a fresh ID
  /// token for an updated backend session — the User document's
  /// `isEmailVerified` flag flips on the next `/auth/me` read.
  ///
  /// Returns the latest [UserModel] when verification succeeded, or
  /// `null` when the email is still pending verification.
  Future<UserModel?> refreshEmailVerifiedStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    if (fresh == null || !fresh.emailVerified) return null;

    // Force-refresh the ID token so it carries the new email_verified
    // claim, then exchange it for an updated backend JWT.
    final idToken = await fresh.getIdToken(true);
    if (idToken == null || idToken.isEmpty) return null;

    final body = await _api.post(
      'auth/firebase',
      auth: false,
      body: {'idToken': idToken},
    );
    return _persistAuth(body);
  }

  /// Backend pre-flight for forgot-password: returns true when the email
  /// is registered with our Firebase project. Firebase's enumeration
  /// protection silently swallows reset requests for unknown emails, so
  /// without this check the user sees "Check your inbox" but no email
  /// arrives. Throws on transport/server errors so callers can show a
  /// retry message rather than a misleading "no account found".
  Future<bool> checkEmailExists(String email) async {
    final body = await _api.post(
      'auth/check-email-exists',
      auth: false,
      body: {'email': email.trim().toLowerCase()},
    );
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is Map<String, dynamic> && data['exists'] is bool) {
      return data['exists'] as bool;
    }
    throw 'Unexpected response from email check.';
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

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models/subscription_model.dart';
import '../data/models/user_model.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/subscription_service.dart';
import '../data/services/user_service.dart';
export '../data/models/user_model.dart' show SubscriptionPlan, SubscriptionPlanX;

enum AuthStatus { initial, loading, authenticated, guest, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _error;
  List<SubscriptionPlanInfo> _plans = const [];
  SubscriptionState _subscriptionState = SubscriptionState.free;
  bool _subscriptionLoading = false;
  bool _lastSignInIsNewUser = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isLoading => _status == AuthStatus.loading;

  /// True after Google login if the user hasn't filled in basic profile
  /// data yet — drives the mandatory onboarding gate.
  bool get needsOnboarding {
    if (!isAuthenticated || _user == null) return false;
    final u = _user!;
    final hasResume = (u.resumeText ?? '').trim().isNotEmpty;
    final hasBasics = u.headline.trim().isNotEmpty ||
        u.skills.isNotEmpty ||
        u.experienceYears > 0;
    return !(hasResume || hasBasics);
  }

  List<SubscriptionPlanInfo> get plans => _plans;
  SubscriptionState get subscriptionState => _subscriptionState;
  bool get subscriptionLoading => _subscriptionLoading;

  /// True only for the call immediately following a fresh signup
  /// (Firebase reports `additionalUserInfo.isNewUser` for Google,
  /// or the email-signup path sets it). Drives the post-auth route
  /// to onboarding for new accounts only.
  bool get lastSignInIsNewUser => _lastSignInIsNewUser;

  Future<void> checkAuthStatus() async {
    // Check guest first: a guest session ALSO sets the access-token flag
    // (it stores a JWT), so without this short-circuit guests would be
    // misclassified as authenticated and we'd hit /auth/me — which strictly
    // rejects guest tokens with 403.
    if (StorageService.isGuestMode()) {
      _user = _authService.currentUser;
      _status = AuthStatus.guest;
      notifyListeners();
      return;
    }
    if (_authService.isLoggedIn) {
      _user = _authService.currentUser;
      _status = _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
      // Fire-and-forget background refresh — never block splash/navigation
      // on /auth/me, since the Render free-tier backend can cold-start for
      // 30+ seconds and would otherwise leave the user staring at the splash.
      _refreshUserInBackground();
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  void _refreshUserInBackground() {
    _authService.me().then((u) {
      _user = u;
      notifyListeners();
    }).catchError((_) {/* keep cached user */});
  }

  /// Public awaited refresh, for callers that just mutated server-side
  /// state (resume upload, avatar change) and need the next read of
  /// [user] to reflect it. Failures are swallowed — the cached user is
  /// good enough to keep going.
  Future<void> refreshMe() async {
    try {
      _user = await _authService.me();
      notifyListeners();
    } catch (_) {
      /* keep cached user */
    }
  }

  Future<void> enterGuestMode() async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      // Backend issues a guest JWT so subsequent API calls go through the
      // same Bearer-token path as authenticated users. If the call fails
      // (offline, server down) we still flip into local guest mode so the
      // user can at least open the app — feed loads will then surface the
      // network error in their own UI.
      _user = await _authService.loginAsGuest();
    } catch (e) {
      _user = null;
      _error = _formatError(e);
    }
    await StorageService.setGuestMode(true);
    _status = AuthStatus.guest;
    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    // Drop the guest JWT and the cached "Guest" user record alongside the
    // flag, otherwise checkAuthStatus would still see a logged-in shell.
    await StorageService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _authService.signInWithGoogle();
      _user = result.user;
      _lastSignInIsNewUser = result.isNewUser;
      await StorageService.setGuestMode(false);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Email/password sign-in via Firebase Auth → backend `/auth/firebase`.
  /// Returns true on success and flips the provider to `authenticated`.
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.signInWithFirebase(
        email: email,
        password: password,
      );
      _lastSignInIsNewUser = false;
      await StorageService.setGuestMode(false);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Email/password sign-up via Firebase Auth → backend `/auth/firebase`.
  /// The backend creates the User document on first hybrid sign-in.
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await _authService.signUpWithFirebase(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _lastSignInIsNewUser = true;
      await StorageService.setGuestMode(false);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Trigger a Firebase password-reset email for the current user's
  /// email. Used in the "I lost my password" flow before sign-in is
  /// possible — for the in-app forgot-password screen we go through
  /// FirebaseAuth directly. Returns true on success.
  Future<bool> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Re-checks whether the user has completed email verification. When
  /// they have, refreshes the cached User and returns true so the UI
  /// can hide its "verify your email" banner.
  Future<bool> refreshEmailVerifiedStatus() async {
    try {
      final fresh = await _authService.refreshEmailVerifiedStatus();
      if (fresh != null) {
        _user = fresh;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? profession,
    String? company,
    int? age,
    String? headline,
    List<String>? skills,
    int? experienceYears,
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    List<String>? preferredJobTypes,
    List<String>? preferredRemote,
    int? expectedSalaryMin,
    String? resumeText,
  }) async {
    if (_user == null) return false;
    try {
      _user = await _userService.updateProfile(
        fullName: name,
        phone: phone,
        headline: headline ?? profession,
        skills: skills,
        experienceYears: experienceYears,
        preferredRoles: preferredRoles,
        preferredLocations: preferredLocations,
        preferredJobTypes: preferredJobTypes,
        preferredRemote: preferredRemote,
        expectedSalaryMin: expectedSalaryMin,
        resumeText: resumeText,
      );
      // Locally re-merge the optional fields the backend doesn't echo back.
      _user = _user!.copyWith(
        company: company,
        age: age,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<({bool ok, bool needsHirerProfile, String? error})> switchRole(
      String role) async {
    try {
      final newRole = await _userService.switchRole(role);
      if (_user != null) {
        _user = _user!.copyWith(activeRole: newRole);
      }
      notifyListeners();
      return (ok: true, needsHirerProfile: false, error: null);
    } catch (e) {
      final msg = _formatError(e);
      // Backend signals "no hirer profile yet" with HTTP 409 — pass that
      // back so the caller can route to company setup instead of showing
      // an error.
      final needs = msg.toLowerCase().contains('company profile');
      _error = msg;
      notifyListeners();
      return (ok: false, needsHirerProfile: needs, error: msg);
    }
  }

  bool get isHirerMode => _user?.activeRole == 'hirer';

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _userService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadResume(File file) async {
    try {
      await _userService.uploadResume(file);
      // Refresh profile so resumeText length etc. is up-to-date.
      _user = await _authService.me();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteResume() async {
    try {
      await _userService.deleteResume();
      _user = await _authService.me();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(File file) async {
    try {
      await _userService.uploadAvatar(file);
      // Backend returns the same path after re-upload, so the cached
      // network image would keep serving the previous bytes. Append a
      // version query param to break the cache key for this session.
      final fresh = await _authService.me();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final url = fresh.photoUrl;
      final busted = (url == null || url.isEmpty)
          ? null
          : '$url${url.contains('?') ? '&' : '?'}v=$stamp';
      _user = fresh.copyWith(photoUrl: busted);
      notifyListeners();
      return true;
    } catch (e, st) {
      // Surface the underlying error in dev — silent failures here mean
      // the user only sees "Upload failed" with no clue why (size, mime,
      // auth, network). Logging the real cause makes triage trivial.
      debugPrint('[AuthProvider.uploadAvatar] failed: $e\n$st');
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAvatar() async {
    try {
      await _userService.deleteAvatar();
      // After delete the API stops returning an avatar field, so use the
      // server response directly (don't copyWith, which can't null-out
      // an existing photoUrl).
      _user = await _authService.me();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _userService.deleteAccount();
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Pull the public plan catalog. Cached on the provider so the screen
  /// can render synchronously after the first fetch.
  Future<bool> loadSubscriptionPlans({bool force = false}) async {
    if (_plans.isNotEmpty && !force) return true;
    try {
      _plans = await _subscriptionService.listPlans();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return false;
    }
  }

  /// Fetch the user's current subscription state (tier + active record).
  Future<bool> loadCurrentSubscription() async {
    _subscriptionLoading = true;
    notifyListeners();
    try {
      _subscriptionState = await _subscriptionService.current();
      // Keep the local user.plan in sync — other screens (profile card,
      // Pro badges) read it without touching the subscription provider.
      if (_user != null) {
        _user = _user!.copyWith(
          plan: _subscriptionState.tier,
          isPro: _subscriptionState.isPro,
        );
      }
      return true;
    } catch (e) {
      _error = _formatError(e);
      return false;
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to a tier. For paid tiers the payment screen first
  /// produces a `paymentId` (Razorpay or stub) which we forward to the
  /// backend so the Subscription record links to the payment.
  Future<bool> subscribeToTier(
    SubscriptionPlan tier, {
    String? paymentMethod,
    String? paymentId,
    String? orderId,
  }) async {
    _subscriptionLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _subscriptionService.subscribe(
        tier: tier,
        paymentMethod: paymentMethod,
        paymentId: paymentId,
        orderId: orderId,
      );
      // Re-fetch the canonical state from the backend (includes the new
      // activeSubscription record + plan details).
      _subscriptionState = await _subscriptionService.current();
      if (_user != null) {
        _user = _user!.copyWith(
          plan: _subscriptionState.tier,
          isPro: _subscriptionState.isPro,
        );
      }
      return true;
    } catch (e) {
      _error = _formatError(e);
      return false;
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelSubscription() async {
    _subscriptionLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _subscriptionService.cancel();
      _subscriptionState = await _subscriptionService.current();
      if (_user != null) {
        _user = _user!.copyWith(
          plan: _subscriptionState.tier,
          isPro: _subscriptionState.isPro,
        );
      }
      return true;
    } catch (e) {
      _error = _formatError(e);
      return false;
    } finally {
      _subscriptionLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }
}

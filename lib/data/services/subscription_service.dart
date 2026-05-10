import 'package:flutter/foundation.dart';

import '../models/subscription_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// Razorpay credential set the backend should use for this checkout.
///
/// Debug builds (emulators / `flutter run`) request `'test'` — the backend
/// honors it only when `NODE_ENV !== 'production'`, so a release-build user
/// cannot bypass real billing by spoofing the flag.
String _razorpayMode() => kDebugMode ? 'test' : 'live';

/// Subscription endpoints under `/api/v1/subscriptions`.
class SubscriptionService {
  final ApiClient _api = ApiClient.instance;

  /// Public — no token required.
  Future<List<SubscriptionPlanInfo>> listPlans() async {
    final raw = await _api.get('subscriptions/plans', auth: false);
    return ApiClient.unwrapList(raw)
        .map((e) => SubscriptionPlanInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /subscriptions/current` returns the wrapped shape
  /// `{ tier, status, activeSubscription, plan }` — not a flat record.
  Future<SubscriptionState> current() async {
    try {
      final raw = await _api.get('subscriptions/current');
      final data = ApiClient.unwrapMap(raw);
      if (data.isEmpty) return SubscriptionState.free;
      return SubscriptionState.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return SubscriptionState.free;
      rethrow;
    }
  }

  Future<List<SubscriptionRecord>> history() async {
    final raw = await _api.get('subscriptions/history');
    return ApiClient.unwrapList(raw)
        .map((e) => SubscriptionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionRecord> subscribe({
    required SubscriptionPlan tier,
    String? paymentMethod,
    String? paymentId,
    String? orderId,
  }) async {
    final body = <String, dynamic>{
      'tier': tier.id,
    };
    if (tier != SubscriptionPlan.free) {
      if (paymentMethod != null) body['paymentMethod'] = paymentMethod;
      if (paymentId != null) body['paymentId'] = paymentId;
      if (orderId != null) body['orderId'] = orderId;
    }
    final raw = await _api.post('subscriptions/subscribe', body: body);
    final data = ApiClient.unwrapMap(raw);
    return SubscriptionRecord.fromJson(data);
  }

  Future<void> cancel() async {
    await _api.post('subscriptions/cancel');
  }

  /// Activates a paid tier by spending the seeker's coin balance instead
  /// of going through Razorpay. Server enforces a per-day idempotency key
  /// so a double-tap returns 409 rather than double-spending.
  Future<RedeemWithCoinsResult> redeemWithCoins(SubscriptionPlan tier) async {
    final raw = await _api.post('subscriptions/redeem-with-coins', body: {
      'tier': tier.id,
    });
    final root = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final data = root['data'] is Map<String, dynamic>
        ? root['data'] as Map<String, dynamic>
        : ApiClient.unwrapMap(raw);
    return RedeemWithCoinsResult(
      record: SubscriptionRecord.fromJson(data),
      coinsSpent: (root['coinsSpent'] as num?)?.toInt() ?? 0,
      coinsBalance: (root['coinsBalance'] as num?)?.toInt() ?? 0,
    );
  }

  // ---- Razorpay ----

  /// Ask the server to create a Razorpay order pinned to a tier. The
  /// amount comes from the server-side plan list — never trust the
  /// client to specify it.
  Future<RazorpayOrder> createRazorpayOrder(SubscriptionPlan tier) async {
    final raw = await _api.post('subscriptions/razorpay/order', body: {
      'tier': tier.id,
      'mode': _razorpayMode(),
    });
    return RazorpayOrder.fromJson(ApiClient.unwrapMap(raw));
  }

  /// Submit Razorpay's success payload to the backend for HMAC
  /// verification. Returns the activated subscription record on success.
  ///
  /// Tier is intentionally NOT sent — the server re-derives it from the
  /// order's server-set notes so a tampered client can't pay weekly and
  /// claim yearly.
  Future<SubscriptionRecord> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final raw = await _api.post('subscriptions/razorpay/verify', body: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
      'mode': _razorpayMode(),
    });
    return SubscriptionRecord.fromJson(ApiClient.unwrapMap(raw));
  }
}

class RedeemWithCoinsResult {
  final SubscriptionRecord record;
  final int coinsSpent;
  final int coinsBalance;
  const RedeemWithCoinsResult({
    required this.record,
    required this.coinsSpent,
    required this.coinsBalance,
  });
}

class RazorpayOrder {
  final String orderId;
  final int amount; // paise
  final String currency;
  final String? keyId;
  final String tier;
  final String? planName;

  const RazorpayOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.tier,
    this.keyId,
    this.planName,
  });

  factory RazorpayOrder.fromJson(Map<String, dynamic> j) => RazorpayOrder(
        orderId: (j['orderId'] ?? '').toString(),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        currency: (j['currency'] ?? 'INR').toString(),
        keyId: j['keyId'] as String?,
        tier: (j['tier'] ?? '').toString(),
        planName: j['planName'] as String?,
      );
}

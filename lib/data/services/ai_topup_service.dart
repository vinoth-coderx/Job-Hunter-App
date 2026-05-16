import 'package:flutter/foundation.dart';

import 'api_client.dart';

String _razorpayMode() => kDebugMode ? 'test' : 'live';

class AiTopUpPack {
  final String id;
  final String label;
  final int credits;
  final int priceInr;
  final bool bestValue;
  const AiTopUpPack({
    required this.id,
    required this.label,
    required this.credits,
    required this.priceInr,
    required this.bestValue,
  });

  factory AiTopUpPack.fromJson(Map<String, dynamic> j) => AiTopUpPack(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        credits: (j['credits'] as num?)?.toInt() ?? 0,
        priceInr: (j['priceInr'] as num?)?.toInt() ?? 0,
        bestValue: j['bestValue'] as bool? ?? false,
      );
}

class AiTopUpOrder {
  final String orderId;
  final int amount;
  final String currency;
  final String? keyId;
  final String packId;
  final int credits;
  final int priceInr;
  const AiTopUpOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.packId,
    required this.credits,
    required this.priceInr,
    this.keyId,
  });
  factory AiTopUpOrder.fromJson(Map<String, dynamic> j) => AiTopUpOrder(
        orderId: (j['orderId'] ?? '').toString(),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        currency: (j['currency'] ?? 'INR').toString(),
        keyId: j['keyId'] as String?,
        packId: (j['packId'] ?? '').toString(),
        credits: (j['credits'] as num?)?.toInt() ?? 0,
        priceInr: (j['priceInr'] as num?)?.toInt() ?? 0,
      );
}

class AiTopUpResult {
  final bool alreadyCredited;
  final int creditsGranted;
  final int balance;
  const AiTopUpResult({
    required this.alreadyCredited,
    required this.creditsGranted,
    required this.balance,
  });
  factory AiTopUpResult.fromJson(Map<String, dynamic> j) => AiTopUpResult(
        alreadyCredited: j['alreadyCredited'] as bool? ?? false,
        creditsGranted: (j['creditsGranted'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
      );
}

/// AI credit top-up — pay-as-you-go packs that buy out-of-quota AI
/// usage. Mirrors the subscription flow's API shape (order → checkout
/// → verify) but persists credits on the user record instead of
/// activating a subscription.
class AiTopUpService {
  AiTopUpService._();
  static final AiTopUpService instance = AiTopUpService._();
  final ApiClient _api = ApiClient.instance;

  Future<List<AiTopUpPack>> listPacks() async {
    final raw = await _api.get('ai/topup/packs');
    final list = ApiClient.unwrapList(raw);
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiTopUpPack.fromJson)
        .toList();
  }

  Future<AiTopUpOrder> createOrder(String packId) async {
    final raw = await _api.post('ai/topup/order', body: {
      'packId': packId,
      'mode': _razorpayMode(),
    });
    return AiTopUpOrder.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<AiTopUpResult> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final raw = await _api.post('ai/topup/verify', body: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
      'mode': _razorpayMode(),
    });
    return AiTopUpResult.fromJson(ApiClient.unwrapMap(raw));
  }
}

import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../models/subscription_model.dart';
import '../models/user_model.dart';
import 'ai_topup_service.dart';
import 'subscription_service.dart';

class RazorpayCheckoutResult {
  final bool success;
  final String? message;
  final SubscriptionRecord? activated;
  const RazorpayCheckoutResult.success(this.activated)
      : success = true,
        message = null;
  const RazorpayCheckoutResult.failure(this.message)
      : success = false,
        activated = null;
}

/// Wraps the Razorpay Flutter SDK into a single Future-returning call.
/// Caller is responsible for showing UI; this just orchestrates:
///   1. POST /subscriptions/razorpay/order   (server creates order)
///   2. Open Razorpay native checkout
///   3. POST /subscriptions/razorpay/verify  (server verifies HMAC)
class RazorpayCheckoutService {
  final SubscriptionService _subs;
  final Razorpay _razorpay = Razorpay();

  RazorpayCheckoutService([SubscriptionService? subs])
      : _subs = subs ?? SubscriptionService();

  Future<RazorpayCheckoutResult> startCheckout({
    required SubscriptionPlan tier,
    required String userEmail,
    required String userName,
    String? userPhone,
  }) async {
    if (tier == SubscriptionPlan.free) {
      return const RazorpayCheckoutResult.failure(
          'Free tier does not require payment');
    }

    final RazorpayOrder order;
    try {
      order = await _subs.createRazorpayOrder(tier);
    } catch (e) {
      return RazorpayCheckoutResult.failure('Could not create order: $e');
    }

    final completer = Completer<RazorpayCheckoutResult>();

    // Bind handlers; clear them once the future completes either way so a
    // subsequent call doesn't fire stale callbacks.
    void onSuccess(PaymentSuccessResponse r) async {
      _razorpay.clear();
      if (r.orderId == null || r.paymentId == null || r.signature == null) {
        completer.complete(
            const RazorpayCheckoutResult.failure('Incomplete payment response'));
        return;
      }
      try {
        final activated = await _subs.verifyRazorpayPayment(
          orderId: r.orderId!,
          paymentId: r.paymentId!,
          signature: r.signature!,
        );
        completer.complete(RazorpayCheckoutResult.success(activated));
      } catch (e) {
        completer.complete(
            RazorpayCheckoutResult.failure('Verification failed: $e'));
      }
    }

    void onError(PaymentFailureResponse r) {
      _razorpay.clear();
      completer.complete(
          RazorpayCheckoutResult.failure(r.message ?? 'Payment failed'));
    }

    void onWallet(ExternalWalletResponse _) {
      // External wallet selected — Razorpay still calls success/error
      // afterwards. Nothing to do here.
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWallet);

    // Razorpay options — kept minimal on purpose.
    //
    // Why no `config.display.blocks` / custom UPI-Intent block:
    //   The SDK already shows installed UPI apps (GPay/PhonePe/Paytm/BHIM)
    //   automatically when (a) AndroidManifest declares the upi scheme query,
    //   (b) the user is on a real device with UPI apps installed and
    //   registered, and (c) the order is in LIVE mode. Adding a custom block
    //   with `flows: ['intent']` only narrows what's shown and can leave the
    //   block visually empty on devices without UPI apps.
    final options = <String, dynamic>{
      'key': order.keyId,
      'amount': order.amount,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'Job Hunter',
      'description': order.planName ?? tier.id,
      'prefill': {
        'email': userEmail,
        'name': userName,
        if (userPhone != null && userPhone.isNotEmpty) 'contact': userPhone,
      },
      'theme': {'color': '#2D7BFF'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _razorpay.clear();
      return RazorpayCheckoutResult.failure('Could not open checkout: $e');
    }

    return completer.future;
  }

  void dispose() => _razorpay.clear();

  /// AI credit top-up checkout. Same harness as [startCheckout] but
  /// points at the AI top-up endpoints and returns the granted credits
  /// + new pack balance instead of a subscription record.
  Future<AiTopUpCheckoutResult> startAiTopUpCheckout({
    required AiTopUpPack pack,
    required String userEmail,
    required String userName,
    String? userPhone,
  }) async {
    final svc = AiTopUpService.instance;
    final AiTopUpOrder order;
    try {
      order = await svc.createOrder(pack.id);
    } catch (e) {
      return AiTopUpCheckoutResult.failure('Could not create order: $e');
    }

    final completer = Completer<AiTopUpCheckoutResult>();

    void onSuccess(PaymentSuccessResponse r) async {
      _razorpay.clear();
      if (r.orderId == null || r.paymentId == null || r.signature == null) {
        completer.complete(
          const AiTopUpCheckoutResult.failure('Incomplete payment response'),
        );
        return;
      }
      try {
        final result = await svc.verifyPayment(
          orderId: r.orderId!,
          paymentId: r.paymentId!,
          signature: r.signature!,
        );
        completer.complete(AiTopUpCheckoutResult.success(result));
      } catch (e) {
        completer.complete(
          AiTopUpCheckoutResult.failure('Verification failed: $e'),
        );
      }
    }

    void onError(PaymentFailureResponse r) {
      _razorpay.clear();
      completer.complete(
        AiTopUpCheckoutResult.failure(r.message ?? 'Payment failed'),
      );
    }

    void onWallet(ExternalWalletResponse _) {}

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWallet);

    final options = <String, dynamic>{
      'key': order.keyId,
      'amount': order.amount,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'Job Hunter',
      'description': '${pack.credits} AI credits',
      'prefill': {
        'email': userEmail,
        'name': userName,
        if (userPhone != null && userPhone.isNotEmpty) 'contact': userPhone,
      },
      'theme': {'color': '#2D7BFF'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _razorpay.clear();
      return AiTopUpCheckoutResult.failure('Could not open checkout: $e');
    }

    return completer.future;
  }
}

class AiTopUpCheckoutResult {
  final bool success;
  final String? message;
  final AiTopUpResult? grant;
  const AiTopUpCheckoutResult.success(this.grant)
      : success = true,
        message = null;
  const AiTopUpCheckoutResult.failure(this.message)
      : success = false,
        grant = null;
}

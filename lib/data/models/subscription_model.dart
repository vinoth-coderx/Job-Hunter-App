import 'user_model.dart';

/// Plan catalog entry — matches `SUBSCRIPTION_PLANS` shape from
/// `subscription.controller.ts` (priceInr, durationDays, features[],
/// jobMatchLimit, apiCallLimit, prioritySupport).
class SubscriptionPlanInfo {
  final SubscriptionPlan tier;
  final String name;
  final num priceInr;
  final int durationDays;
  final List<String> features;
  final int jobMatchLimit;
  final int apiCallLimit;
  final bool prioritySupport;

  const SubscriptionPlanInfo({
    required this.tier,
    required this.name,
    required this.priceInr,
    required this.durationDays,
    required this.features,
    required this.jobMatchLimit,
    required this.apiCallLimit,
    required this.prioritySupport,
  });

  /// Convenience: paise amount used by Razorpay-style payment screens.
  int get amountPaise => (priceInr * 100).round();

  /// "/week", "/month", "/year", "forever" — derived from the canonical
  /// duration the backend returns so we never disagree with billing.
  String get periodLabel {
    if (durationDays >= 36000) return 'forever';
    if (durationDays >= 350) return '/year';
    if (durationDays >= 28) return '/month';
    if (durationDays >= 7) return '/week';
    return '/$durationDays days';
  }

  String get priceLabel {
    if (priceInr <= 0) return '₹0';
    final n = priceInr.toInt();
    return '₹${_formatNumber(n)}';
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    final firstChunk = s.length % 3 == 0 ? 3 : s.length % 3;
    buf.write(s.substring(0, firstChunk));
    for (int i = firstChunk; i < s.length; i += 3) {
      buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }

  factory SubscriptionPlanInfo.fromJson(Map<String, dynamic> j) {
    return SubscriptionPlanInfo(
      tier: SubscriptionPlanX.fromId(j['tier'] as String?),
      name: (j['name'] ?? j['tier'] ?? '').toString(),
      // Backend returns `priceInr`; older clients may have read `price`,
      // accept both so we don't break in flight.
      priceInr: (j['priceInr'] as num?) ?? (j['price'] as num?) ?? 0,
      durationDays: (j['durationDays'] as num?)?.toInt() ?? 0,
      features: (j['features'] is List)
          ? (j['features'] as List).map((e) => e.toString()).toList()
          : const [],
      jobMatchLimit: (j['jobMatchLimit'] as num?)?.toInt() ?? 0,
      apiCallLimit: (j['apiCallLimit'] as num?)?.toInt() ?? 0,
      prioritySupport: (j['prioritySupport'] as bool?) ?? false,
    );
  }
}

/// One row of the user's subscription history (or the wrapped
/// `activeSubscription` in `current`).
class SubscriptionRecord {
  final String? id;
  final SubscriptionPlan tier;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final num amountPaid;
  final String currency;
  final String? paymentMethod;
  final String? paymentId;
  final String? orderId;
  final bool autoRenew;
  final DateTime? cancelledAt;

  const SubscriptionRecord({
    required this.id,
    required this.tier,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.amountPaid,
    required this.currency,
    required this.paymentMethod,
    required this.paymentId,
    required this.orderId,
    required this.autoRenew,
    required this.cancelledAt,
  });

  bool get isActive => status == 'active';

  factory SubscriptionRecord.fromJson(Map<String, dynamic> j) {
    DateTime? parse(dynamic v) =>
        v is String ? DateTime.tryParse(v) : null;
    return SubscriptionRecord(
      id: (j['_id'] ?? j['id'])?.toString(),
      tier: SubscriptionPlanX.fromId(j['tier'] as String?),
      status: (j['status'] ?? 'active').toString(),
      startDate: parse(j['startDate']),
      endDate: parse(j['endDate']),
      amountPaid: (j['amountPaid'] as num?) ?? 0,
      currency: (j['currency'] ?? 'INR').toString(),
      paymentMethod: j['paymentMethod'] as String?,
      paymentId: j['paymentId'] as String?,
      orderId: j['orderId'] as String?,
      autoRenew: (j['autoRenew'] as bool?) ?? false,
      cancelledAt: parse(j['cancelledAt']),
    );
  }
}

/// Shape returned by `GET /subscriptions/current`:
///   { tier, status, activeSubscription, plan }
class SubscriptionState {
  final SubscriptionPlan tier;
  final String status;
  final SubscriptionRecord? activeSubscription;
  final SubscriptionPlanInfo? plan;

  const SubscriptionState({
    required this.tier,
    required this.status,
    required this.activeSubscription,
    required this.plan,
  });

  bool get isPro => tier != SubscriptionPlan.free;

  /// True only when there's a paid plan with a real active record we can
  /// cancel — the free tier has no record to cancel.
  bool get canCancel =>
      isPro &&
      activeSubscription != null &&
      activeSubscription!.isActive;

  factory SubscriptionState.fromJson(Map<String, dynamic> j) {
    final activeRaw = j['activeSubscription'];
    final planRaw = j['plan'];
    return SubscriptionState(
      tier: SubscriptionPlanX.fromId(j['tier'] as String?),
      status: (j['status'] ?? 'active').toString(),
      activeSubscription: activeRaw is Map<String, dynamic>
          ? SubscriptionRecord.fromJson(activeRaw)
          : null,
      plan: planRaw is Map<String, dynamic>
          ? SubscriptionPlanInfo.fromJson(planRaw)
          : null,
    );
  }

  static const free = SubscriptionState(
    tier: SubscriptionPlan.free,
    status: 'active',
    activeSubscription: null,
    plan: null,
  );
}

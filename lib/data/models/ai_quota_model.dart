/// Mirror of the backend AI quota snapshot. Keep field names aligned
/// with `services/ai/quota.service.ts:QuotaSnapshot`.
class AiQuota {
  final int userUsed;
  final int userLimit;
  final int userRemaining;
  final int globalUsed;
  final int globalLimit;
  final int globalRemaining;
  final DateTime resetsAt;
  final int resetsInSec;

  const AiQuota({
    required this.userUsed,
    required this.userLimit,
    required this.userRemaining,
    required this.globalUsed,
    required this.globalLimit,
    required this.globalRemaining,
    required this.resetsAt,
    required this.resetsInSec,
  });

  factory AiQuota.fromJson(Map<String, dynamic> j) => AiQuota(
        userUsed: (j['userUsed'] as num?)?.toInt() ?? 0,
        userLimit: (j['userLimit'] as num?)?.toInt() ?? 0,
        userRemaining: (j['userRemaining'] as num?)?.toInt() ?? 0,
        globalUsed: (j['globalUsed'] as num?)?.toInt() ?? 0,
        globalLimit: (j['globalLimit'] as num?)?.toInt() ?? 0,
        globalRemaining: (j['globalRemaining'] as num?)?.toInt() ?? 0,
        resetsAt: DateTime.tryParse((j['resetsAtIso'] ?? '').toString()) ??
            DateTime.now().add(const Duration(hours: 24)),
        resetsInSec: (j['resetsInSec'] as num?)?.toInt() ?? 0,
      );

  /// True when either the per-user or global cap has been hit. Drives the
  /// quota-exhausted banner and gates AI-CTA buttons in the UI.
  bool get isExhausted => userRemaining <= 0 || globalRemaining <= 0;

  /// True when the user is close to running out (< 20% of their daily cap).
  /// Drives the soft "running low" banner.
  bool get isLow =>
      userLimit > 0 && userRemaining > 0 && userRemaining <= (userLimit * 0.2);
}

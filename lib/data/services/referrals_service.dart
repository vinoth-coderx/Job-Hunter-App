import 'api_client.dart';

class ReferralClaimResult {
  final int coinsAwarded;
  final int coinsBalance;
  const ReferralClaimResult({
    required this.coinsAwarded,
    required this.coinsBalance,
  });
}

/// Referral endpoints under `/api/v1/seeker/referrals`.
class ReferralsService {
  ReferralsService._();
  static final ReferralsService instance = ReferralsService._();
  final ApiClient _api = ApiClient.instance;

  /// Returns the seeker's referral code, generating one lazily on the
  /// server side on first call.
  Future<String> myCode() async {
    final raw = await _api.get('seeker/referrals/code');
    final data = ApiClient.unwrapMap(raw);
    return (data['code'] as String?) ?? '';
  }

  /// Claims a referrer's code. Server enforces "one claim per referee
  /// for life" via a unique index, so a retry/double-tap collapses to
  /// the same outcome.
  Future<ReferralClaimResult> claim(String code) async {
    final raw = await _api.post(
      'seeker/referrals/claim',
      body: {'code': code.trim().toUpperCase()},
    );
    final data = ApiClient.unwrapMap(raw);
    return ReferralClaimResult(
      coinsAwarded: (data['coinsAwarded'] as num?)?.toInt() ?? 0,
      coinsBalance: (data['coinsBalance'] as num?)?.toInt() ?? 0,
    );
  }
}

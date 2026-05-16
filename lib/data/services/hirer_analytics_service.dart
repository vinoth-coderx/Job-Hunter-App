import 'api_client.dart';

class FunnelBucket {
  final String status;
  final int count;
  const FunnelBucket({required this.status, required this.count});
  factory FunnelBucket.fromJson(Map<String, dynamic> j) => FunnelBucket(
        status: (j['status'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class SourceBucket {
  final String source;
  final int count;
  const SourceBucket({required this.source, required this.count});
  factory SourceBucket.fromJson(Map<String, dynamic> j) => SourceBucket(
        source: (j['source'] ?? 'unknown').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class TopJob {
  final String jobId;
  final String title;
  final int applicationsCount;
  final int shortlistedCount;
  final String status;
  const TopJob({
    required this.jobId,
    required this.title,
    required this.applicationsCount,
    required this.shortlistedCount,
    required this.status,
  });
  factory TopJob.fromJson(Map<String, dynamic> j) => TopJob(
        jobId: (j['jobId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        applicationsCount: (j['applicationsCount'] as num?)?.toInt() ?? 0,
        shortlistedCount: (j['shortlistedCount'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? '').toString(),
      );
}

class DailyPoint {
  final String date; // YYYY-MM-DD
  final int count;
  const DailyPoint({required this.date, required this.count});
  factory DailyPoint.fromJson(Map<String, dynamic> j) => DailyPoint(
        date: (j['date'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

class HirerAnalytics {
  final int totalJobs;
  final int totalApplications;
  final List<FunnelBucket> funnel;
  final List<SourceBucket> sourceBreakdown;
  final List<TopJob> topJobs;
  final int? timeToHireDays;
  final List<DailyPoint> daily30;

  const HirerAnalytics({
    required this.totalJobs,
    required this.totalApplications,
    required this.funnel,
    required this.sourceBreakdown,
    required this.topJobs,
    this.timeToHireDays,
    required this.daily30,
  });

  factory HirerAnalytics.fromJson(Map<String, dynamic> j) => HirerAnalytics(
        totalJobs: (j['totalJobs'] as num?)?.toInt() ?? 0,
        totalApplications: (j['totalApplications'] as num?)?.toInt() ?? 0,
        funnel: (j['funnel'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(FunnelBucket.fromJson)
                .toList() ??
            const [],
        sourceBreakdown: (j['sourceBreakdown'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(SourceBucket.fromJson)
                .toList() ??
            const [],
        topJobs: (j['topJobs'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(TopJob.fromJson)
                .toList() ??
            const [],
        timeToHireDays: (j['timeToHireDays'] as num?)?.toInt(),
        daily30: (j['daily30'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(DailyPoint.fromJson)
                .toList() ??
            const [],
      );
}

/// AI-generated weekly digest for the hirer dashboard. One short
/// headline + 2-4 next-action bullets. The backend caches per
/// (hirerProfile, UTC day) so multiple dashboard refreshes never burn
/// fresh quota — `cached` tells the UI whether this hit cache.
class HirerDigest {
  final String headline;
  final List<String> bullets;
  final DateTime generatedAt;
  final bool cached;
  final bool usedAi;

  const HirerDigest({
    required this.headline,
    required this.bullets,
    required this.generatedAt,
    required this.cached,
    required this.usedAi,
  });

  factory HirerDigest.fromJson(Map<String, dynamic> j) => HirerDigest(
        headline: (j['headline'] ?? '').toString(),
        bullets: (j['bullets'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toList() ??
            const [],
        generatedAt: DateTime.tryParse((j['generatedAt'] ?? '').toString()) ??
            DateTime.now(),
        cached: j['cached'] as bool? ?? false,
        usedAi: j['usedAi'] as bool? ?? false,
      );
}

class HirerAnalyticsService {
  HirerAnalyticsService._();
  static final HirerAnalyticsService instance = HirerAnalyticsService._();
  final ApiClient _api = ApiClient.instance;

  Future<HirerAnalytics> fetch() async {
    final raw = await _api.get('hirer/analytics');
    return HirerAnalytics.fromJson(ApiClient.unwrapMap(raw));
  }

  /// AI-generated weekly digest. Cheap on cache hits (24h server-side
  /// per hirer + UTC day). Returns an empty-headline digest when the
  /// hirer has no active jobs yet.
  Future<HirerDigest> fetchDigest() async {
    final raw = await _api.get('hirer/digest');
    return HirerDigest.fromJson(ApiClient.unwrapMap(raw));
  }
}

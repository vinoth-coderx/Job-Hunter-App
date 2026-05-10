import '../models/job_model.dart';
import 'api_client.dart';

class CompanyProfile {
  final String id;
  final String companyName;
  final String? companyLogoUrl;
  final String? industry;
  final String? companySize;
  final int? foundedYear;
  final String? website;
  final String? description;
  final String? cultureValues;
  final List<String> officePhotos;
  final double ratingAverage;
  final int totalReviews;
  final int followersCount;
  final int activeJobsCount;
  final bool isVerified;
  final bool isFollowing;

  const CompanyProfile({
    required this.id,
    required this.companyName,
    this.companyLogoUrl,
    this.industry,
    this.companySize,
    this.foundedYear,
    this.website,
    this.description,
    this.cultureValues,
    this.officePhotos = const [],
    this.ratingAverage = 0,
    this.totalReviews = 0,
    this.followersCount = 0,
    this.activeJobsCount = 0,
    this.isVerified = false,
    this.isFollowing = false,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> j) {
    final rating = j['rating'] as Map<String, dynamic>?;
    final verification = j['verification'] as Map<String, dynamic>?;
    return CompanyProfile(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      companyName: (j['companyName'] ?? '').toString(),
      companyLogoUrl: j['companyLogoUrl'] as String?,
      industry: j['industry'] as String?,
      companySize: j['companySize'] as String?,
      foundedYear: (j['foundedYear'] as num?)?.toInt(),
      website: j['website'] as String?,
      description: j['description'] as String?,
      cultureValues: j['cultureValues'] as String?,
      officePhotos:
          (j['officePhotos'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      ratingAverage: (rating?['average'] as num?)?.toDouble() ?? 0,
      totalReviews: (rating?['totalReviews'] as num?)?.toInt() ?? 0,
      followersCount: (j['followersCount'] as num?)?.toInt() ?? 0,
      activeJobsCount: (j['activeJobsCount'] as num?)?.toInt() ?? 0,
      isVerified: verification?['isVerified'] as bool? ?? false,
      isFollowing: j['isFollowing'] as bool? ?? false,
    );
  }
}

class CompanyReview {
  final String id;
  final bool isAnonymous;
  final String reviewerRole;
  final String? reviewerName;
  final int overall;
  final int? culture;
  final int? workLifeBalance;
  final int? growth;
  final int? pay;
  final int? management;
  final String? title;
  final String? pros;
  final String? cons;
  final String? adviceToManagement;
  final int helpfulCount;
  final DateTime createdAt;

  const CompanyReview({
    required this.id,
    required this.isAnonymous,
    required this.reviewerRole,
    this.reviewerName,
    required this.overall,
    this.culture,
    this.workLifeBalance,
    this.growth,
    this.pay,
    this.management,
    this.title,
    this.pros,
    this.cons,
    this.adviceToManagement,
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory CompanyReview.fromJson(Map<String, dynamic> j) {
    final ratings = (j['ratings'] as Map<String, dynamic>?) ?? const {};
    final reviewer = j['reviewer'] as Map<String, dynamic>?;
    return CompanyReview(
      id: (j['id'] ?? '').toString(),
      isAnonymous: j['isAnonymous'] as bool? ?? true,
      reviewerRole: (j['reviewerRole'] ?? 'candidate').toString(),
      reviewerName: reviewer?['fullName'] as String?,
      overall: (ratings['overall'] as num?)?.toInt() ?? 0,
      culture: (ratings['culture'] as num?)?.toInt(),
      workLifeBalance: (ratings['workLifeBalance'] as num?)?.toInt(),
      growth: (ratings['growth'] as num?)?.toInt(),
      pay: (ratings['pay'] as num?)?.toInt(),
      management: (ratings['management'] as num?)?.toInt(),
      title: j['title'] as String?,
      pros: j['pros'] as String?,
      cons: j['cons'] as String?,
      adviceToManagement: j['adviceToManagement'] as String?,
      helpfulCount: (j['helpfulCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class CompanyService {
  CompanyService._();
  static final CompanyService instance = CompanyService._();

  final ApiClient _api = ApiClient.instance;

  Future<CompanyProfile> getProfile(String id) async {
    final raw = await _api.get('companies/$id', auth: false);
    return CompanyProfile.fromJson(ApiClient.unwrapMap(raw));
  }

  Future<List<Job>> listJobs(String id) async {
    final raw = await _api.get('companies/$id/jobs', auth: false);
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(Job.fromApiJson)
        .toList();
  }

  Future<List<CompanyReview>> listReviews(String id) async {
    final raw = await _api.get('companies/$id/reviews', auth: false);
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(CompanyReview.fromJson)
        .toList();
  }

  Future<List<CompanyProfile>> listFollowed() async {
    final raw = await _api.get('companies/followed');
    return ApiClient.unwrapList(raw)
        .whereType<Map<String, dynamic>>()
        .map(CompanyProfile.fromJson)
        .toList();
  }

  Future<void> follow(String id) => _api.post('companies/$id/follow');
  Future<void> unfollow(String id) => _api.delete('companies/$id/follow');

  Future<void> submitReview({
    required String id,
    required int overall,
    int? culture,
    int? workLifeBalance,
    int? growth,
    int? pay,
    int? management,
    required String reviewerRole,
    bool isAnonymous = true,
    String? title,
    String? pros,
    String? cons,
    String? adviceToManagement,
  }) async {
    await _api.post('companies/$id/reviews', body: {
      'isAnonymous': isAnonymous,
      'reviewerRole': reviewerRole,
      'ratings': {
        'overall': overall,
        if (culture != null) 'culture': culture,
        if (workLifeBalance != null) 'workLifeBalance': workLifeBalance,
        if (growth != null) 'growth': growth,
        if (pay != null) 'pay': pay,
        if (management != null) 'management': management,
      },
      if (title != null && title.isNotEmpty) 'title': title,
      if (pros != null && pros.isNotEmpty) 'pros': pros,
      if (cons != null && cons.isNotEmpty) 'cons': cons,
      if (adviceToManagement != null && adviceToManagement.isNotEmpty)
        'adviceToManagement': adviceToManagement,
    });
  }
}

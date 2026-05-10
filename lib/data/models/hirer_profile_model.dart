class CompanyHeadquarters {
  final String? city;
  final String? state;
  final String? country;
  final String? address;

  const CompanyHeadquarters({this.city, this.state, this.country, this.address});

  factory CompanyHeadquarters.fromJson(Map<String, dynamic> json) =>
      CompanyHeadquarters(
        city: json['city'] as String?,
        state: json['state'] as String?,
        country: json['country'] as String?,
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (country != null) 'country': country,
        if (address != null) 'address': address,
      };
}

class CompanyOtherLocation {
  final String city;
  final String? state;
  const CompanyOtherLocation({required this.city, this.state});
  factory CompanyOtherLocation.fromJson(Map<String, dynamic> json) =>
      CompanyOtherLocation(
        city: json['city'] as String? ?? '',
        state: json['state'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'city': city,
        if (state != null) 'state': state,
      };
}

class CompanySocialLinks {
  final String? linkedin;
  final String? twitter;
  final String? glassdoor;

  const CompanySocialLinks({this.linkedin, this.twitter, this.glassdoor});

  factory CompanySocialLinks.fromJson(Map<String, dynamic> json) =>
      CompanySocialLinks(
        linkedin: json['linkedin'] as String?,
        twitter: json['twitter'] as String?,
        glassdoor: json['glassdoor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (linkedin != null && linkedin!.isNotEmpty) 'linkedin': linkedin,
        if (twitter != null && twitter!.isNotEmpty) 'twitter': twitter,
        if (glassdoor != null && glassdoor!.isNotEmpty) 'glassdoor': glassdoor,
      };
}

class HirerVerification {
  final bool isVerified;
  final String? gstNumber;
  final DateTime? verifiedAt;

  const HirerVerification({
    required this.isVerified,
    this.gstNumber,
    this.verifiedAt,
  });

  factory HirerVerification.fromJson(Map<String, dynamic> json) =>
      HirerVerification(
        isVerified: json['isVerified'] as bool? ?? false,
        gstNumber: json['gstNumber'] as String?,
        verifiedAt: json['verifiedAt'] != null
            ? DateTime.tryParse(json['verifiedAt'].toString())
            : null,
      );
}

class HirerProfile {
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
  final CompanyHeadquarters? headquarters;
  final List<CompanyOtherLocation> otherLocations;
  final CompanySocialLinks? socialLinks;
  final HirerVerification verification;
  final double ratingAverage;
  final int totalReviews;
  final int followersCount;
  final int activeJobsCount;

  const HirerProfile({
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
    this.headquarters,
    this.otherLocations = const [],
    this.socialLinks,
    required this.verification,
    this.ratingAverage = 0,
    this.totalReviews = 0,
    this.followersCount = 0,
    this.activeJobsCount = 0,
  });

  factory HirerProfile.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] as Map<String, dynamic>?;
    return HirerProfile(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      companyName: json['companyName'] as String? ?? '',
      companyLogoUrl: json['companyLogoUrl'] as String?,
      industry: json['industry'] as String?,
      companySize: json['companySize'] as String?,
      foundedYear: json['foundedYear'] as int?,
      website: json['website'] as String?,
      description: json['description'] as String?,
      cultureValues: json['cultureValues'] as String?,
      officePhotos: (json['officePhotos'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      headquarters: json['headquarters'] is Map<String, dynamic>
          ? CompanyHeadquarters.fromJson(
              json['headquarters'] as Map<String, dynamic>)
          : null,
      otherLocations: (json['otherLocations'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(CompanyOtherLocation.fromJson)
              .toList() ??
          const [],
      socialLinks: json['socialLinks'] is Map<String, dynamic>
          ? CompanySocialLinks.fromJson(
              json['socialLinks'] as Map<String, dynamic>)
          : null,
      verification: json['verification'] is Map<String, dynamic>
          ? HirerVerification.fromJson(
              json['verification'] as Map<String, dynamic>)
          : const HirerVerification(isVerified: false),
      ratingAverage: (rating?['average'] as num?)?.toDouble() ?? 0,
      totalReviews: (rating?['totalReviews'] as int?) ?? 0,
      followersCount: (json['followersCount'] as int?) ?? 0,
      activeJobsCount: (json['activeJobsCount'] as int?) ?? 0,
    );
  }
}

class HirerStats {
  final bool hasProfile;
  final String? hirerProfileId;
  final String? companyName;
  final bool isVerified;
  final int activeJobs;
  final int draftJobs;
  final int closedJobs;
  final int totalApplications;
  final int totalShortlisted;

  const HirerStats({
    required this.hasProfile,
    this.hirerProfileId,
    this.companyName,
    this.isVerified = false,
    this.activeJobs = 0,
    this.draftJobs = 0,
    this.closedJobs = 0,
    this.totalApplications = 0,
    this.totalShortlisted = 0,
  });

  factory HirerStats.fromJson(Map<String, dynamic> json) => HirerStats(
        hasProfile: json['hasProfile'] as bool? ?? false,
        hirerProfileId: json['hirerProfileId'] as String?,
        companyName: json['companyName'] as String?,
        isVerified: json['isVerified'] as bool? ?? false,
        activeJobs: json['activeJobs'] as int? ?? 0,
        draftJobs: json['draftJobs'] as int? ?? 0,
        closedJobs: json['closedJobs'] as int? ?? 0,
        totalApplications: json['totalApplications'] as int? ?? 0,
        totalShortlisted: json['totalShortlisted'] as int? ?? 0,
      );
}

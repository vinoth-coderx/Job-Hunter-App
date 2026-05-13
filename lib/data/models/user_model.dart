enum SubscriptionPlan { free, weekly, proMonthly, proYearly }

extension SubscriptionPlanX on SubscriptionPlan {
  String get id {
    switch (this) {
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.weekly:
        return 'weekly';
      case SubscriptionPlan.proMonthly:
        return 'monthly';
      case SubscriptionPlan.proYearly:
        return 'yearly';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.weekly:
        return 'Weekly';
      case SubscriptionPlan.proMonthly:
        return 'Pro Monthly';
      case SubscriptionPlan.proYearly:
        return 'Pro Yearly';
    }
  }

  static SubscriptionPlan fromId(String? value) {
    switch (value) {
      case 'monthly':
      case 'pro_monthly':
        return SubscriptionPlan.proMonthly;
      case 'yearly':
      case 'pro_yearly':
        return SubscriptionPlan.proYearly;
      case 'weekly':
        return SubscriptionPlan.weekly;
      default:
        return SubscriptionPlan.free;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profession;
  final String company;
  final String? photoUrl;
  final int age;
  final bool isPro;
  final SubscriptionPlan plan;
  final List<String> savedJobIds;
  final List<String> appliedJobIds;
  final String activeRole; // 'seeker' | 'hirer'
  final String headline;
  final List<String> skills;
  final int experienceYears;
  final List<String> preferredRoles;
  final List<String> preferredLocations;
  final List<String> preferredJobTypes;
  final List<String> preferredRemote;
  final int? expectedSalaryMin;
  final String? resumeText;
  final bool isEmailVerified;
  /// Raw `profile.resumeProfile` subdoc from /auth/me, kept as a map so
  /// the resume profile provider can hydrate its rich Naukri-style
  /// sections without UserModel needing to know the full shape.
  final Map<String, dynamic>? resumeProfile;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.profession = 'Job Seeker',
    this.company = '',
    this.photoUrl,
    this.age = 0,
    this.isPro = false,
    this.plan = SubscriptionPlan.free,
    this.savedJobIds = const [],
    this.appliedJobIds = const [],
    this.activeRole = 'seeker',
    this.headline = '',
    this.skills = const [],
    this.experienceYears = 0,
    this.preferredRoles = const [],
    this.preferredLocations = const [],
    this.preferredJobTypes = const [],
    this.preferredRemote = const [],
    this.expectedSalaryMin,
    this.resumeText,
    this.isEmailVerified = false,
    this.resumeProfile,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? profession,
    String? company,
    String? photoUrl,
    int? age,
    bool? isPro,
    SubscriptionPlan? plan,
    List<String>? savedJobIds,
    List<String>? appliedJobIds,
    String? activeRole,
    String? headline,
    List<String>? skills,
    int? experienceYears,
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    List<String>? preferredJobTypes,
    List<String>? preferredRemote,
    int? expectedSalaryMin,
    String? resumeText,
    bool? isEmailVerified,
    Map<String, dynamic>? resumeProfile,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profession: profession ?? this.profession,
      company: company ?? this.company,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      isPro: isPro ?? this.isPro,
      plan: plan ?? this.plan,
      savedJobIds: savedJobIds ?? this.savedJobIds,
      appliedJobIds: appliedJobIds ?? this.appliedJobIds,
      activeRole: activeRole ?? this.activeRole,
      headline: headline ?? this.headline,
      skills: skills ?? this.skills,
      experienceYears: experienceYears ?? this.experienceYears,
      preferredRoles: preferredRoles ?? this.preferredRoles,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      preferredJobTypes: preferredJobTypes ?? this.preferredJobTypes,
      preferredRemote: preferredRemote ?? this.preferredRemote,
      expectedSalaryMin: expectedSalaryMin ?? this.expectedSalaryMin,
      resumeText: resumeText ?? this.resumeText,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      resumeProfile: resumeProfile ?? this.resumeProfile,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'profession': profession,
        'company': company,
        'photoUrl': photoUrl,
        'age': age,
        'isPro': isPro,
        'plan': plan.id,
        'savedJobIds': savedJobIds,
        'appliedJobIds': appliedJobIds,
        'activeRole': activeRole,
        'headline': headline,
        'skills': skills,
        'experienceYears': experienceYears,
        'preferredRoles': preferredRoles,
        'preferredLocations': preferredLocations,
        'preferredJobTypes': preferredJobTypes,
        'preferredRemote': preferredRemote,
        'expectedSalaryMin': expectedSalaryMin,
        'resumeText': resumeText,
        'isEmailVerified': isEmailVerified,
        'resumeProfile': resumeProfile,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: (json['phone'] ?? '') as String,
        profession: (json['profession'] ?? 'Job Seeker') as String,
        company: (json['company'] ?? '') as String,
        photoUrl: json['photoUrl'] as String?,
        age: (json['age'] ?? 0) as int,
        isPro: (json['isPro'] ?? false) as bool,
        plan: SubscriptionPlanX.fromId(json['plan'] as String?),
        savedJobIds: List<String>.from(json['savedJobIds'] ?? []),
        appliedJobIds: List<String>.from(json['appliedJobIds'] ?? []),
        activeRole: (json['activeRole'] ?? 'seeker') as String,
        headline: (json['headline'] ?? '') as String,
        skills: List<String>.from(json['skills'] ?? const []),
        experienceYears: (json['experienceYears'] ?? 0) as int,
        preferredRoles: List<String>.from(json['preferredRoles'] ?? const []),
        preferredLocations:
            List<String>.from(json['preferredLocations'] ?? const []),
        preferredJobTypes:
            List<String>.from(json['preferredJobTypes'] ?? const []),
        preferredRemote:
            List<String>.from(json['preferredRemote'] ?? const []),
        expectedSalaryMin: json['expectedSalaryMin'] as int?,
        resumeText: json['resumeText'] as String?,
        isEmailVerified: (json['isEmailVerified'] as bool?) ?? false,
        resumeProfile: json['resumeProfile'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['resumeProfile'] as Map)
            : null,
      );

  /// Parses the API response shape from the Job Hunter backend, which uses
  /// MongoDB-style `_id`, a separate `profile` block for resume info, and a
  /// `subscription.tier` field for plan tier.
  factory UserModel.fromApiJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final profile =
        (json['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final subscription = (json['subscription'] as Map<String, dynamic>?);
    final planValue =
        subscription?['tier'] as String? ?? json['plan'] as String?;
    final plan = SubscriptionPlanX.fromId(planValue);
    final isPro = json['isPro'] as bool? ?? plan != SubscriptionPlan.free;

    String? avatarPath = profile['avatar'] as String? ??
        json['avatar'] as String? ??
        json['photoUrl'] as String?;

    return UserModel(
      id: id,
      name: (profile['fullName'] ??
              json['fullName'] ??
              json['name'] ??
              '')
          .toString(),
      email: (json['email'] ?? '').toString(),
      phone: (profile['phone'] ?? json['phone'] ?? '').toString(),
      profession: (profile['headline'] ?? json['profession'] ?? 'Job Seeker')
          .toString(),
      company: (profile['company'] ?? json['company'] ?? '').toString(),
      photoUrl: avatarPath,
      age: (json['age'] as int?) ?? 0,
      isPro: isPro,
      plan: plan,
      savedJobIds: List<String>.from(json['savedJobIds'] ?? const []),
      appliedJobIds: List<String>.from(json['appliedJobIds'] ?? const []),
      activeRole: (json['activeRole'] ?? 'seeker').toString(),
      headline:
          (profile['headline'] ?? json['headline'] ?? '').toString(),
      skills: _stringList(profile['skills'] ?? json['skills']),
      experienceYears: (profile['experienceYears'] as int?) ??
          (json['experienceYears'] as int?) ??
          0,
      preferredRoles:
          _stringList(profile['preferredRoles'] ?? json['preferredRoles']),
      preferredLocations: _stringList(
          profile['preferredLocations'] ?? json['preferredLocations']),
      preferredJobTypes: _stringList(
          profile['preferredJobTypes'] ?? json['preferredJobTypes']),
      preferredRemote:
          _stringList(profile['preferredRemote'] ?? json['preferredRemote']),
      expectedSalaryMin: (profile['expectedSalaryMin'] as num?)?.toInt() ??
          (json['expectedSalaryMin'] as num?)?.toInt(),
      resumeText: profile['resumeText'] as String? ??
          json['resumeText'] as String?,
      isEmailVerified: (json['isEmailVerified'] as bool?) ?? false,
      resumeProfile: profile['resumeProfile'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(profile['resumeProfile'] as Map)
          : null,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }
}

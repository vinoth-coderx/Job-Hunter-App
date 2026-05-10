class EmploymentEntry {
  final String designation;
  final String company;
  final String period;
  final bool current;
  const EmploymentEntry({
    required this.designation,
    required this.company,
    required this.period,
    this.current = false,
  });

  EmploymentEntry copyWith({
    String? designation,
    String? company,
    String? period,
    bool? current,
  }) =>
      EmploymentEntry(
        designation: designation ?? this.designation,
        company: company ?? this.company,
        period: period ?? this.period,
        current: current ?? this.current,
      );

  Map<String, dynamic> toJson() => {
        'designation': designation,
        'company': company,
        'period': period,
        'current': current,
      };

  factory EmploymentEntry.fromJson(Map<String, dynamic> j) => EmploymentEntry(
        designation: j['designation'] as String? ?? '',
        company: j['company'] as String? ?? '',
        period: j['period'] as String? ?? '',
        current: j['current'] as bool? ?? false,
      );
}

class EducationEntry {
  final String degree;
  final String institute;
  final String period;
  final String type;
  final List<String> projects;
  const EducationEntry({
    required this.degree,
    required this.institute,
    required this.period,
    required this.type,
    this.projects = const [],
  });

  EducationEntry copyWith({
    String? degree,
    String? institute,
    String? period,
    String? type,
    List<String>? projects,
  }) =>
      EducationEntry(
        degree: degree ?? this.degree,
        institute: institute ?? this.institute,
        period: period ?? this.period,
        type: type ?? this.type,
        projects: projects ?? this.projects,
      );

  Map<String, dynamic> toJson() => {
        'degree': degree,
        'institute': institute,
        'period': period,
        'type': type,
        'projects': projects,
      };

  factory EducationEntry.fromJson(Map<String, dynamic> j) => EducationEntry(
        degree: j['degree'] as String? ?? '',
        institute: j['institute'] as String? ?? '',
        period: j['period'] as String? ?? '',
        type: j['type'] as String? ?? '',
        projects: List<String>.from(j['projects'] as List? ?? const []),
      );
}

class ITSkill {
  final String skill;
  final String version;
  final String lastUsed;
  final String experience;
  const ITSkill({
    required this.skill,
    required this.version,
    required this.lastUsed,
    required this.experience,
  });

  ITSkill copyWith({
    String? skill,
    String? version,
    String? lastUsed,
    String? experience,
  }) =>
      ITSkill(
        skill: skill ?? this.skill,
        version: version ?? this.version,
        lastUsed: lastUsed ?? this.lastUsed,
        experience: experience ?? this.experience,
      );

  Map<String, dynamic> toJson() => {
        'skill': skill,
        'version': version,
        'lastUsed': lastUsed,
        'experience': experience,
      };

  factory ITSkill.fromJson(Map<String, dynamic> j) => ITSkill(
        skill: j['skill'] as String? ?? '',
        version: j['version'] as String? ?? '-',
        lastUsed: j['lastUsed'] as String? ?? '',
        experience: j['experience'] as String? ?? '',
      );
}

class ProjectEntry {
  final String title;
  final String company;
  final String type;
  final String period;
  final String description;
  const ProjectEntry({
    required this.title,
    required this.company,
    required this.type,
    required this.period,
    required this.description,
  });

  ProjectEntry copyWith({
    String? title,
    String? company,
    String? type,
    String? period,
    String? description,
  }) =>
      ProjectEntry(
        title: title ?? this.title,
        company: company ?? this.company,
        type: type ?? this.type,
        period: period ?? this.period,
        description: description ?? this.description,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'company': company,
        'type': type,
        'period': period,
        'description': description,
      };

  factory ProjectEntry.fromJson(Map<String, dynamic> j) => ProjectEntry(
        title: j['title'] as String? ?? '',
        company: j['company'] as String? ?? '',
        type: j['type'] as String? ?? '',
        period: j['period'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );
}

class CareerProfile {
  final String currentIndustry;
  final String department;
  final String roleCategory;
  final String jobRole;
  final String desiredJobType;
  final String desiredEmploymentType;
  final String preferredShift;
  final String preferredLocation;
  final String expectedSalary;
  const CareerProfile({
    required this.currentIndustry,
    required this.department,
    required this.roleCategory,
    required this.jobRole,
    required this.desiredJobType,
    required this.desiredEmploymentType,
    required this.preferredShift,
    required this.preferredLocation,
    required this.expectedSalary,
  });

  CareerProfile copyWith({
    String? currentIndustry,
    String? department,
    String? roleCategory,
    String? jobRole,
    String? desiredJobType,
    String? desiredEmploymentType,
    String? preferredShift,
    String? preferredLocation,
    String? expectedSalary,
  }) =>
      CareerProfile(
        currentIndustry: currentIndustry ?? this.currentIndustry,
        department: department ?? this.department,
        roleCategory: roleCategory ?? this.roleCategory,
        jobRole: jobRole ?? this.jobRole,
        desiredJobType: desiredJobType ?? this.desiredJobType,
        desiredEmploymentType:
            desiredEmploymentType ?? this.desiredEmploymentType,
        preferredShift: preferredShift ?? this.preferredShift,
        preferredLocation: preferredLocation ?? this.preferredLocation,
        expectedSalary: expectedSalary ?? this.expectedSalary,
      );

  Map<String, dynamic> toJson() => {
        'currentIndustry': currentIndustry,
        'department': department,
        'roleCategory': roleCategory,
        'jobRole': jobRole,
        'desiredJobType': desiredJobType,
        'desiredEmploymentType': desiredEmploymentType,
        'preferredShift': preferredShift,
        'preferredLocation': preferredLocation,
        'expectedSalary': expectedSalary,
      };

  factory CareerProfile.fromJson(Map<String, dynamic> j) => CareerProfile(
        currentIndustry: j['currentIndustry'] as String? ?? '',
        department: j['department'] as String? ?? '',
        roleCategory: j['roleCategory'] as String? ?? '',
        jobRole: j['jobRole'] as String? ?? '',
        desiredJobType: j['desiredJobType'] as String? ?? '',
        desiredEmploymentType: j['desiredEmploymentType'] as String? ?? '',
        preferredShift: j['preferredShift'] as String? ?? '',
        preferredLocation: j['preferredLocation'] as String? ?? '',
        expectedSalary: j['expectedSalary'] as String? ?? '',
      );
}

class PersonalDetails {
  final String gender;
  final String maritalStatus;
  final String dob;
  final String category;
  final String workPermit;
  final String address;
  const PersonalDetails({
    required this.gender,
    required this.maritalStatus,
    required this.dob,
    required this.category,
    required this.workPermit,
    required this.address,
  });

  PersonalDetails copyWith({
    String? gender,
    String? maritalStatus,
    String? dob,
    String? category,
    String? workPermit,
    String? address,
  }) =>
      PersonalDetails(
        gender: gender ?? this.gender,
        maritalStatus: maritalStatus ?? this.maritalStatus,
        dob: dob ?? this.dob,
        category: category ?? this.category,
        workPermit: workPermit ?? this.workPermit,
        address: address ?? this.address,
      );

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'maritalStatus': maritalStatus,
        'dob': dob,
        'category': category,
        'workPermit': workPermit,
        'address': address,
      };

  factory PersonalDetails.fromJson(Map<String, dynamic> j) => PersonalDetails(
        gender: j['gender'] as String? ?? '',
        maritalStatus: j['maritalStatus'] as String? ?? '',
        dob: j['dob'] as String? ?? '',
        category: j['category'] as String? ?? '',
        workPermit: j['workPermit'] as String? ?? '',
        address: j['address'] as String? ?? '',
      );
}

class LanguageProficiency {
  final String language;
  final String proficiency;
  final bool read;
  final bool write;
  final bool speak;
  const LanguageProficiency({
    required this.language,
    required this.proficiency,
    required this.read,
    required this.write,
    required this.speak,
  });

  LanguageProficiency copyWith({
    String? language,
    String? proficiency,
    bool? read,
    bool? write,
    bool? speak,
  }) =>
      LanguageProficiency(
        language: language ?? this.language,
        proficiency: proficiency ?? this.proficiency,
        read: read ?? this.read,
        write: write ?? this.write,
        speak: speak ?? this.speak,
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'proficiency': proficiency,
        'read': read,
        'write': write,
        'speak': speak,
      };

  factory LanguageProficiency.fromJson(Map<String, dynamic> j) =>
      LanguageProficiency(
        language: j['language'] as String? ?? '',
        proficiency: j['proficiency'] as String? ?? 'Beginner',
        read: j['read'] as bool? ?? false,
        write: j['write'] as bool? ?? false,
        speak: j['speak'] as bool? ?? false,
      );
}

class Accomplishment {
  final String type;
  final String label;
  final String value;
  const Accomplishment({
    required this.type,
    required this.label,
    required this.value,
  });

  Accomplishment copyWith({String? type, String? label, String? value}) =>
      Accomplishment(
        type: type ?? this.type,
        label: label ?? this.label,
        value: value ?? this.value,
      );

  Map<String, dynamic> toJson() =>
      {'type': type, 'label': label, 'value': value};

  factory Accomplishment.fromJson(Map<String, dynamic> j) => Accomplishment(
        type: j['type'] as String? ?? '',
        label: j['label'] as String? ?? '',
        value: j['value'] as String? ?? '',
      );
}

class ResumeProfile {
  final String location;
  final String experience;
  final String currentSalary;
  final String availability;
  final String workStatus;
  final int expYears;
  final int expMonths;
  final String currency;
  final String salaryAmount;
  final String salaryBreakdown;
  final String locationType;
  final String locationCity;
  final String locationCountry;
  final String telephoneCountry;
  final String telephoneArea;
  final String telephonePhone;
  final String resumeFileName;
  final String resumeUploadedOn;
  final String resumeFilePath;
  final int resumeSizeBytes;
  final String resumeHeadline;
  final List<String> keySkills;
  final List<EmploymentEntry> employments;
  final List<EducationEntry> educations;
  final List<ITSkill> itSkills;
  final List<ProjectEntry> projects;
  final String profileSummary;
  final List<Accomplishment> accomplishments;
  final CareerProfile careerProfile;
  final PersonalDetails personalDetails;
  final List<LanguageProficiency> languages;
  final String diversityNote;

  const ResumeProfile({
    required this.location,
    required this.experience,
    required this.currentSalary,
    required this.availability,
    required this.workStatus,
    required this.expYears,
    required this.expMonths,
    required this.currency,
    required this.salaryAmount,
    required this.salaryBreakdown,
    required this.locationType,
    required this.locationCity,
    required this.locationCountry,
    required this.telephoneCountry,
    required this.telephoneArea,
    required this.telephonePhone,
    required this.resumeFileName,
    required this.resumeUploadedOn,
    required this.resumeFilePath,
    required this.resumeSizeBytes,
    required this.resumeHeadline,
    required this.keySkills,
    required this.employments,
    required this.educations,
    required this.itSkills,
    required this.projects,
    required this.profileSummary,
    required this.accomplishments,
    required this.careerProfile,
    required this.personalDetails,
    required this.languages,
    required this.diversityNote,
  });

  int get completionPercent {
    int score = 0;
    int total = 14;
    if (resumeFileName.isNotEmpty) score++;
    if (resumeHeadline.isNotEmpty) score++;
    if (keySkills.isNotEmpty) score++;
    if (employments.isNotEmpty) score++;
    if (educations.isNotEmpty) score++;
    if (itSkills.isNotEmpty) score++;
    if (projects.isNotEmpty) score++;
    if (profileSummary.isNotEmpty) score++;
    if (accomplishments.isNotEmpty) score++;
    if (careerProfile.currentIndustry.isNotEmpty) score++;
    if (personalDetails.dob.isNotEmpty) score++;
    if (languages.isNotEmpty) score++;
    if (location.isNotEmpty) score++;
    if (currentSalary.isNotEmpty) score++;
    return ((score / total) * 100).round().clamp(0, 100);
  }

  ResumeProfile copyWith({
    String? location,
    String? experience,
    String? currentSalary,
    String? availability,
    String? workStatus,
    int? expYears,
    int? expMonths,
    String? currency,
    String? salaryAmount,
    String? salaryBreakdown,
    String? locationType,
    String? locationCity,
    String? locationCountry,
    String? telephoneCountry,
    String? telephoneArea,
    String? telephonePhone,
    String? resumeFileName,
    String? resumeUploadedOn,
    String? resumeFilePath,
    int? resumeSizeBytes,
    String? resumeHeadline,
    List<String>? keySkills,
    List<EmploymentEntry>? employments,
    List<EducationEntry>? educations,
    List<ITSkill>? itSkills,
    List<ProjectEntry>? projects,
    String? profileSummary,
    List<Accomplishment>? accomplishments,
    CareerProfile? careerProfile,
    PersonalDetails? personalDetails,
    List<LanguageProficiency>? languages,
    String? diversityNote,
  }) =>
      ResumeProfile(
        location: location ?? this.location,
        experience: experience ?? this.experience,
        currentSalary: currentSalary ?? this.currentSalary,
        availability: availability ?? this.availability,
        workStatus: workStatus ?? this.workStatus,
        expYears: expYears ?? this.expYears,
        expMonths: expMonths ?? this.expMonths,
        currency: currency ?? this.currency,
        salaryAmount: salaryAmount ?? this.salaryAmount,
        salaryBreakdown: salaryBreakdown ?? this.salaryBreakdown,
        locationType: locationType ?? this.locationType,
        locationCity: locationCity ?? this.locationCity,
        locationCountry: locationCountry ?? this.locationCountry,
        telephoneCountry: telephoneCountry ?? this.telephoneCountry,
        telephoneArea: telephoneArea ?? this.telephoneArea,
        telephonePhone: telephonePhone ?? this.telephonePhone,
        resumeFileName: resumeFileName ?? this.resumeFileName,
        resumeUploadedOn: resumeUploadedOn ?? this.resumeUploadedOn,
        resumeFilePath: resumeFilePath ?? this.resumeFilePath,
        resumeSizeBytes: resumeSizeBytes ?? this.resumeSizeBytes,
        resumeHeadline: resumeHeadline ?? this.resumeHeadline,
        keySkills: keySkills ?? this.keySkills,
        employments: employments ?? this.employments,
        educations: educations ?? this.educations,
        itSkills: itSkills ?? this.itSkills,
        projects: projects ?? this.projects,
        profileSummary: profileSummary ?? this.profileSummary,
        accomplishments: accomplishments ?? this.accomplishments,
        careerProfile: careerProfile ?? this.careerProfile,
        personalDetails: personalDetails ?? this.personalDetails,
        languages: languages ?? this.languages,
        diversityNote: diversityNote ?? this.diversityNote,
      );

  Map<String, dynamic> toJson() => {
        'location': location,
        'experience': experience,
        'currentSalary': currentSalary,
        'availability': availability,
        'workStatus': workStatus,
        'expYears': expYears,
        'expMonths': expMonths,
        'currency': currency,
        'salaryAmount': salaryAmount,
        'salaryBreakdown': salaryBreakdown,
        'locationType': locationType,
        'locationCity': locationCity,
        'locationCountry': locationCountry,
        'telephoneCountry': telephoneCountry,
        'telephoneArea': telephoneArea,
        'telephonePhone': telephonePhone,
        'resumeFileName': resumeFileName,
        'resumeUploadedOn': resumeUploadedOn,
        'resumeFilePath': resumeFilePath,
        'resumeSizeBytes': resumeSizeBytes,
        'resumeHeadline': resumeHeadline,
        'keySkills': keySkills,
        'employments': employments.map((e) => e.toJson()).toList(),
        'educations': educations.map((e) => e.toJson()).toList(),
        'itSkills': itSkills.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'profileSummary': profileSummary,
        'accomplishments': accomplishments.map((e) => e.toJson()).toList(),
        'careerProfile': careerProfile.toJson(),
        'personalDetails': personalDetails.toJson(),
        'languages': languages.map((e) => e.toJson()).toList(),
        'diversityNote': diversityNote,
      };

  factory ResumeProfile.fromJson(Map<String, dynamic> j) => ResumeProfile(
        location: j['location'] as String? ?? '',
        experience: j['experience'] as String? ?? '',
        currentSalary: j['currentSalary'] as String? ?? '',
        availability: j['availability'] as String? ?? '',
        workStatus: j['workStatus'] as String? ?? 'Experienced',
        expYears: j['expYears'] as int? ?? 0,
        expMonths: j['expMonths'] as int? ?? 0,
        currency: j['currency'] as String? ?? '₹',
        salaryAmount: j['salaryAmount'] as String? ?? '',
        salaryBreakdown: j['salaryBreakdown'] as String? ?? 'Fixed',
        locationType: j['locationType'] as String? ?? 'India',
        locationCity: j['locationCity'] as String? ?? '',
        locationCountry: j['locationCountry'] as String? ?? '',
        telephoneCountry: j['telephoneCountry'] as String? ?? '',
        telephoneArea: j['telephoneArea'] as String? ?? '',
        telephonePhone: j['telephonePhone'] as String? ?? '',
        resumeFileName: j['resumeFileName'] as String? ?? '',
        resumeUploadedOn: j['resumeUploadedOn'] as String? ?? '',
        resumeFilePath: j['resumeFilePath'] as String? ?? '',
        resumeSizeBytes: j['resumeSizeBytes'] as int? ?? 0,
        resumeHeadline: j['resumeHeadline'] as String? ?? '',
        keySkills: List<String>.from(j['keySkills'] as List? ?? const []),
        employments: (j['employments'] as List? ?? const [])
            .map((e) => EmploymentEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        educations: (j['educations'] as List? ?? const [])
            .map((e) => EducationEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        itSkills: (j['itSkills'] as List? ?? const [])
            .map((e) => ITSkill.fromJson(e as Map<String, dynamic>))
            .toList(),
        projects: (j['projects'] as List? ?? const [])
            .map((e) => ProjectEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        profileSummary: j['profileSummary'] as String? ?? '',
        accomplishments: (j['accomplishments'] as List? ?? const [])
            .map((e) => Accomplishment.fromJson(e as Map<String, dynamic>))
            .toList(),
        careerProfile: j['careerProfile'] != null
            ? CareerProfile.fromJson(
                j['careerProfile'] as Map<String, dynamic>)
            : _emptyCareer,
        personalDetails: j['personalDetails'] != null
            ? PersonalDetails.fromJson(
                j['personalDetails'] as Map<String, dynamic>)
            : _emptyPersonal,
        languages: (j['languages'] as List? ?? const [])
            .map((e) =>
                LanguageProficiency.fromJson(e as Map<String, dynamic>))
            .toList(),
        diversityNote: j['diversityNote'] as String? ?? '',
      );

  static ResumeProfile get initial => const ResumeProfile(
        location: '',
        experience: '',
        currentSalary: '',
        availability: '',
        workStatus: 'Experienced',
        expYears: 0,
        expMonths: 0,
        currency: '₹',
        salaryAmount: '',
        salaryBreakdown: 'Fixed',
        locationType: 'India',
        locationCity: '',
        locationCountry: '',
        telephoneCountry: '',
        telephoneArea: '',
        telephonePhone: '',
        resumeFileName: '',
        resumeUploadedOn: '',
        resumeFilePath: '',
        resumeSizeBytes: 0,
        resumeHeadline: '',
        keySkills: [],
        employments: [],
        educations: [],
        itSkills: [],
        projects: [],
        profileSummary: '',
        accomplishments: [],
        careerProfile: _emptyCareer,
        personalDetails: _emptyPersonal,
        languages: [],
        diversityNote: '',
      );
}

const CareerProfile _emptyCareer = CareerProfile(
  currentIndustry: '',
  department: '',
  roleCategory: '',
  jobRole: '',
  desiredJobType: '',
  desiredEmploymentType: '',
  preferredShift: '',
  preferredLocation: '',
  expectedSalary: '',
);

const PersonalDetails _emptyPersonal = PersonalDetails(
  gender: '',
  maritalStatus: '',
  dob: '',
  category: '',
  workPermit: '',
  address: '',
);

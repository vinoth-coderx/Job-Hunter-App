import 'package:intl/intl.dart';

enum ApplicationStatus { applied, viewed, shortlisted, interview, offered, rejected, withdrawn }

class JobScreeningQuestion {
  final String question;
  final String type; // 'text' | 'mcq' | 'yes_no'
  final List<String> options;
  final bool isRequired;
  const JobScreeningQuestion({
    required this.question,
    required this.type,
    this.options = const [],
    this.isRequired = false,
  });
  factory JobScreeningQuestion.fromJson(Map<String, dynamic> j) =>
      JobScreeningQuestion(
        question: (j['question'] ?? '').toString(),
        type: (j['type'] ?? 'text').toString(),
        options:
            (j['options'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        isRequired: j['isRequired'] as bool? ?? false,
      );
}

class Job {
  final String id;
  final String title;
  final String company;
  final String companyLogo;
  final String location;
  final String salary;
  final List<String> skills;
  final String description;
  final String postedTime;
  final DateTime? postedAt;
  final bool isRemote;
  final String employmentType;
  final String remoteType;
  final String experience;
  final String category;
  final String? applyUrl;
  final double? matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String? matchReasoning;

  /// True when this is a native job posted via our hirer flow.
  /// Drives in-app one-click apply vs WebView external apply.
  final bool isNative;
  final String source; // 'native' | 'adzuna' | 'serpapi' | ...
  final String applyType; // 'easy_apply' | 'custom_form'
  final List<JobScreeningQuestion> screeningQuestions;
  final List<String> requiredDocuments;

  /// User id of the hirer who posted this — used to start a chat from
  /// the job detail. Empty for non-native (scraped) jobs.
  final String postedByUserId;

  /// Native-job extras the hirer fills in during posting. Scraped jobs
  /// usually leave these empty; the JobDetail UI hides each section
  /// individually rather than showing empty placeholders.
  final List<String> responsibilities;
  final List<String> perks;
  final List<String> niceToHaveSkills;
  final int? openingsCount;
  final String? education;
  final DateTime? applicationDeadline;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.companyLogo,
    required this.location,
    required this.salary,
    this.skills = const [],
    required this.description,
    this.postedTime = '',
    this.postedAt,
    this.isRemote = false,
    this.employmentType = '',
    this.remoteType = '',
    this.experience = '',
    this.category = 'All',
    this.applyUrl,
    this.matchScore,
    this.matchedSkills = const [],
    this.missingSkills = const [],
    this.matchReasoning,
    this.isNative = false,
    this.source = '',
    this.applyType = 'easy_apply',
    this.screeningQuestions = const [],
    this.requiredDocuments = const [],
    this.postedByUserId = '',
    this.responsibilities = const [],
    this.perks = const [],
    this.niceToHaveSkills = const [],
    this.openingsCount,
    this.education,
    this.applicationDeadline,
  });

  Job copyWith({
    double? matchScore,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    String? matchReasoning,
  }) =>
      Job(
        id: id,
        title: title,
        company: company,
        companyLogo: companyLogo,
        location: location,
        salary: salary,
        skills: skills,
        description: description,
        postedTime: postedTime,
        postedAt: postedAt,
        isRemote: isRemote,
        employmentType: employmentType,
        remoteType: remoteType,
        experience: experience,
        category: category,
        applyUrl: applyUrl,
        matchScore: matchScore ?? this.matchScore,
        matchedSkills: matchedSkills ?? this.matchedSkills,
        missingSkills: missingSkills ?? this.missingSkills,
        matchReasoning: matchReasoning ?? this.matchReasoning,
        isNative: isNative,
        source: source,
        applyType: applyType,
        screeningQuestions: screeningQuestions,
        requiredDocuments: requiredDocuments,
        postedByUserId: postedByUserId,
        responsibilities: responsibilities,
        perks: perks,
        niceToHaveSkills: niceToHaveSkills,
        openingsCount: openingsCount,
        education: education,
        applicationDeadline: applicationDeadline,
      );

  /// Convenience tags used by list/detail UI: employment type + remote + skills preview.
  List<String> get tags {
    final out = <String>[];
    if (employmentType.isNotEmpty) out.add(_capitalize(employmentType));
    if (isRemote && !out.contains('Remote')) out.add('Remote');
    out.addAll(skills.take(4));
    return out;
  }

  /// Parses a job document returned by the Job Hunter REST API.
  /// Accepts either a raw job document or a match-wrapped envelope
  /// (`{ job: {...}, score: 87, matchedSkills, missingSkills, reasoning }`).
  factory Job.fromApiJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;
    double? score;
    List<String> matchedSkills = const [];
    List<String> missingSkills = const [];
    String? reasoning;
    if (raw['job'] is Map<String, dynamic>) {
      j = raw['job'] as Map<String, dynamic>;
      final s = raw['score'] ?? raw['matchScore'];
      if (s is num) score = s.toDouble();
      matchedSkills = _stringList(raw['matchedSkills']);
      missingSkills = _stringList(raw['missingSkills']);
      reasoning = raw['reasoning'] as String?;
    } else if (raw['matchScore'] is num) {
      score = (raw['matchScore'] as num).toDouble();
    }

    final id = (j['_id'] ?? j['id'] ?? '').toString();
    final title = (j['title'] ?? j['role'] ?? '').toString();
    final company = (j['company'] ?? j['companyName'] ?? '').toString();
    final companyLogo =
        (j['companyLogo'] ?? j['logo'] ?? _logoFor(company)).toString();
    final location = (j['location'] ?? j['city'] ?? 'Remote').toString();
    final rawJobType =
        (j['jobType'] ?? j['employmentType'] ?? '').toString();
    final jobType = _isPlaceholderValue(rawJobType) ? '' : rawJobType;
    final rawRemoteType = (j['remoteType'] ?? '').toString().toLowerCase();
    final remoteType = _isPlaceholderValue(rawRemoteType) ? '' : rawRemoteType;
    final isRemote = remoteType.contains('remote') ||
        location.toLowerCase().contains('remote');

    final skills = _stringList(j['skills']);
    final description =
        (j['description'] ?? j['summary'] ?? '').toString();
    final rawPostedAt = j['postedAt'] ?? j['createdAt'];
    final postedAt = _parseDate(rawPostedAt);
    final postedTime = _formatPosted(rawPostedAt);
    final salary = _formatSalary(j);
    final experience = _formatExperience(j);
    final category = _categoryFromTitle(title);
    final applyUrl =
        j['applyUrl'] as String? ?? j['url'] as String?;

    final source = (j['source'] as String?)?.toLowerCase() ?? '';
    final isNative = j['isNative'] as bool? ?? source == 'native';
    final applyType = (j['applyType'] as String?) ?? 'easy_apply';
    final screeningQuestions = (j['screeningQuestions'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(JobScreeningQuestion.fromJson)
            .toList() ??
        const <JobScreeningQuestion>[];
    final requiredDocs = (j['requiredDocuments'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final postedByUserId = (j['postedBy'] ?? '').toString();
    final responsibilities = _stringList(j['responsibilities']);
    final perks = _stringList(j['perks']);
    final niceToHaveSkills = _stringList(j['niceToHaveSkills']);
    final openingsCount = (j['openingsCount'] as num?)?.toInt();
    final education = (j['education'] as String?)?.trim();
    final applicationDeadline = _parseDate(j['applicationDeadline']);

    return Job(
      id: id,
      title: title,
      company: company,
      companyLogo: companyLogo,
      location: location,
      salary: salary,
      skills: skills,
      description: description,
      postedTime: postedTime,
      postedAt: postedAt,
      isRemote: isRemote,
      employmentType: jobType,
      remoteType: remoteType,
      experience: experience,
      category: category,
      applyUrl: applyUrl,
      matchScore: score,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      matchReasoning: reasoning,
      isNative: isNative,
      source: source,
      applyType: applyType,
      screeningQuestions: screeningQuestions,
      requiredDocuments: requiredDocs,
      postedByUserId: postedByUserId,
      responsibilities: responsibilities,
      perks: perks,
      niceToHaveSkills: niceToHaveSkills,
      openingsCount: openingsCount,
      education: education,
      applicationDeadline: applicationDeadline,
    );
  }

  /// Only trust explicit experience fields the API returns. We deliberately
  /// don't grep the description — different jobs say "2-4 hours/week",
  /// "team of 4 years tenure", "founded in 4 years", and the regex picked
  /// up false positives that surfaced as a wrong "2-4 yrs" on the detail.
  static String _formatExperience(Map<String, dynamic> j) {
    final min = (j['experienceMin'] as num?)?.toInt();
    final max = (j['experienceMax'] as num?)?.toInt();
    if (min != null && max != null) return '$min – $max yrs';
    if (min != null) return '$min+ yrs';
    if (max != null) return 'Up to $max yrs';

    for (final key in const ['experienceLevel', 'experience', 'seniority']) {
      final v = j[key];
      if (v is String) {
        final trimmed = v.trim();
        // Don't surface server placeholders ("unknown", "n/a", "any") to
        // the seeker — empty string lets _StatHero hide the tile rather
        // than display a low-trust label.
        if (_isPlaceholderValue(trimmed)) continue;
        if (trimmed.isNotEmpty) return _capitalize(trimmed);
      }
    }

    return '';
  }

  static bool _isPlaceholderValue(String v) {
    final lc = v.toLowerCase();
    return lc.isEmpty ||
        lc == 'unknown' ||
        lc == 'n/a' ||
        lc == 'na' ||
        lc == 'none' ||
        lc == 'not specified' ||
        lc == 'not disclosed' ||
        lc == 'any' ||
        lc == 'any level';
  }

  static String _logoFor(String company) {
    if (company.isEmpty) return '';
    final domain = company
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (domain.isEmpty) return '';
    return 'https://logo.clearbit.com/$domain.com';
  }

  static List<String> _stringList(dynamic raw) {
    Iterable<String> source;
    if (raw is List) {
      source = raw.map((e) => e.toString());
    } else if (raw is String && raw.isNotEmpty) {
      source = [raw];
    } else {
      return const [];
    }
    // Split every entry on comma so backend strings like
    // "react, node, mongo" — whether they arrive as a bare string or
    // packed into a one-element list — become individual items. Trim,
    // drop blanks, dedupe (case-insensitive) so the chip wrap doesn't
    // render empty pills or duplicates.
    final out = <String>[];
    final seen = <String>{};
    for (final item in source) {
      for (final part in item.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final key = trimmed.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(trimmed);
      }
    }
    return out;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join('-');
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return null;
  }

  static String _formatPosted(dynamic raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return DateFormat.yMMMd().format(dt);
  }

  static String _formatSalary(Map<String, dynamic> j) {
    final periodSuffix = _salaryPeriodSuffix(j);
    final shown = j['salary'];
    if (shown is String && shown.isNotEmpty) {
      // Pre-baked salary strings often arrive with the raw currency code
      // ("INR6L", "USD50K"). Map those to symbols + spacing so the chip
      // reads as "₹6L" / "$50K" instead of the unformatted string.
      return _appendPeriod(_polishSalaryString(shown), periodSuffix);
    }
    final min = (j['salaryMin'] as num?)?.toInt();
    final max = (j['salaryMax'] as num?)?.toInt();
    final currency = _currencySymbol((j['currency'] as String?) ?? '\$');
    String fmt(int v) {
      if (v >= 100000) {
        final lakhs = v / 100000;
        return '${lakhs.toStringAsFixed(lakhs.truncateToDouble() == lakhs ? 0 : 1)}L';
      }
      if (v >= 1000) {
        final k = v / 1000;
        return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
      }
      return NumberFormat.decimalPattern().format(v);
    }

    String range;
    if (min != null && max != null) {
      range = '$currency${fmt(min)} – $currency${fmt(max)}';
    } else if (min != null) {
      range = '$currency${fmt(min)}+';
    } else if (max != null) {
      range = 'Up to $currency${fmt(max)}';
    } else {
      return '';
    }
    return _appendPeriod(range, periodSuffix);
  }

  /// Reads pay-frequency hints from common backend field names. Returns
  /// short suffixes like "/yr", "/mo", "/hr" so the salary chip can
  /// disambiguate "₹6L" between annual vs monthly when the backend tells
  /// us. Returns empty string when the period isn't supplied — we never
  /// guess.
  static String _salaryPeriodSuffix(Map<String, dynamic> j) {
    final raw = (j['salaryPeriod'] ??
            j['payPeriod'] ??
            j['period'] ??
            j['frequency'] ??
            j['paymentFrequency'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (raw == null || raw.isEmpty) return '';
    if (raw.contains('year') || raw.contains('annual') || raw == 'pa') {
      return '/yr';
    }
    if (raw.contains('month') || raw == 'pm') return '/mo';
    if (raw.contains('week')) return '/wk';
    if (raw.contains('hour')) return '/hr';
    if (raw.contains('day')) return '/day';
    return '';
  }

  /// Appends the period suffix unless the formatted salary already
  /// carries one (avoids "₹6L/yr/yr" when the backend baked it in).
  static String _appendPeriod(String salary, String suffix) {
    if (suffix.isEmpty || salary.isEmpty) return salary;
    final lower = salary.toLowerCase();
    if (lower.contains('/yr') ||
        lower.contains('/mo') ||
        lower.contains('/wk') ||
        lower.contains('/hr') ||
        lower.contains('/day') ||
        lower.contains('per year') ||
        lower.contains('per month') ||
        lower.contains('per week') ||
        lower.contains('per hour') ||
        lower.contains('per day') ||
        lower.contains(' a year') ||
        lower.contains(' a month')) {
      return salary;
    }
    return '$salary $suffix';
  }

  /// Maps an ISO currency code (or raw symbol) to the glyph used on
  /// salary chips. Falls back to the input if we don't know the code,
  /// so unusual currencies still render legibly.
  static String _currencySymbol(String raw) {
    final c = raw.trim().toUpperCase();
    switch (c) {
      case 'INR':
      case 'RS':
      case 'RS.':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'AUD':
      case 'CAD':
      case 'SGD':
      case 'NZD':
      case 'HKD':
        return '\$';
      default:
        return raw;
    }
  }

  /// Cleans up server-supplied salary strings like "INR6L - INR15L" into
  /// "₹6L – ₹15L". We replace currency codes with symbols and normalise
  /// the dash. Keeps the original string intact if no known code is
  /// present so we don't accidentally mangle bespoke display text.
  static String _polishSalaryString(String raw) {
    var out = raw;
    const codes = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
    };
    for (final entry in codes.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    // Normalise hyphen ranges to en-dash, but only when sandwiched by
    // spaces so we don't touch hyphens inside compound words.
    out = out.replaceAll(' - ', ' – ');
    return out;
  }

  static String _categoryFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('design')) return 'Design';
    if (t.contains('market')) return 'Marketing';
    if (t.contains('admin')) return 'Administration';
    if (t.contains('finance') || t.contains('account')) return 'Finance';
    if (t.contains('sales')) return 'Sales';
    if (t.contains('hr') || t.contains('human resources')) return 'HR';
    if (t.contains('product manager') || t.contains('product owner')) return 'Product';
    if (t.contains('data') || t.contains('analyst') || t.contains('scientist')) {
      return 'Data';
    }
    if (t.contains('developer') ||
        t.contains('engineer') ||
        t.contains('programmer') ||
        t.contains('full stack') ||
        t.contains('frontend') ||
        t.contains('backend') ||
        t.contains('mobile') ||
        t.contains('ios') ||
        t.contains('android') ||
        t.contains('software')) {
      return 'Programming';
    }
    return 'Other';
  }
}

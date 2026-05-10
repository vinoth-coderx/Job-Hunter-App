/// A backend-persisted job alert (saved search that pushes new matches).
class JobAlert {
  final String id;
  final String? label;
  final String query;
  final List<String> filters;
  final String? location;
  final String sort;
  final bool active;
  final DateTime? lastNotifiedAt;
  final int notificationCount;
  final DateTime createdAt;

  const JobAlert({
    required this.id,
    this.label,
    required this.query,
    this.filters = const [],
    this.location,
    this.sort = 'mostRelevant',
    this.active = true,
    this.lastNotifiedAt,
    this.notificationCount = 0,
    required this.createdAt,
  });

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    if (query.isNotEmpty) return query;
    if (filters.isNotEmpty) return filters.join(' · ');
    return 'All jobs';
  }

  String get summary {
    final parts = <String>[];
    if (location != null && location!.isNotEmpty) parts.add(location!);
    if (filters.isNotEmpty) {
      parts.add('${filters.length} filter${filters.length == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }

  factory JobAlert.fromApiJson(Map<String, dynamic> j) => JobAlert(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        label: j['label'] as String?,
        query: (j['query'] ?? '').toString(),
        filters: (j['filters'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        location: j['location'] as String?,
        sort: (j['sort'] ?? 'mostRelevant').toString(),
        active: j['active'] != false,
        lastNotifiedAt: _parseDate(j['lastNotifiedAt']),
        notificationCount: (j['notificationCount'] as num?)?.toInt() ?? 0,
        createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
      );

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return null;
  }
}

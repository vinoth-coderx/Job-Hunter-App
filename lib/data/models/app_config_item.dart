/// Single row in the admin "App Config" page. Mirrors the
/// `AppConfigSummary` payload from `GET /admin/config` on the backend.
///
/// Secrets (`isSecret == true`) only carry a masked [preview] like
/// "••••xy12" — the plaintext never leaves the server. To rotate a
/// secret the admin re-enters the full value in the edit dialog.
class AppConfigItem {
  final String key;
  final String category; // job-board | payment | cloudinary | email | firebase | cron | misc
  final bool isSecret;
  final bool hasValue;
  final String? preview;
  final String? notes;
  final DateTime updatedAt;

  const AppConfigItem({
    required this.key,
    required this.category,
    required this.isSecret,
    required this.hasValue,
    required this.preview,
    required this.notes,
    required this.updatedAt,
  });

  factory AppConfigItem.fromJson(Map<String, dynamic> json) {
    DateTime parsed;
    try {
      parsed = DateTime.parse(json['updatedAt'].toString()).toLocal();
    } catch (_) {
      parsed = DateTime.now();
    }
    return AppConfigItem(
      key: (json['key'] ?? '').toString(),
      category: (json['category'] ?? 'misc').toString(),
      isSecret: (json['isSecret'] as bool?) ?? false,
      hasValue: (json['hasValue'] as bool?) ?? false,
      preview: json['preview'] as String?,
      notes: json['notes'] as String?,
      updatedAt: parsed,
    );
  }
}

/// Canonical list of categories the backend recognises. The dialog
/// dropdown is built from this so we don't end up sending an
/// unrecognised value that fails server-side validation.
const List<String> kAppConfigCategories = <String>[
  'job-board',
  'payment',
  'cloudinary',
  'email',
  'firebase',
  'cron',
  'misc',
];

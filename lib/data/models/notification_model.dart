/// In-app notification surfaced via `/api/v1/notifications`.
///
/// Distinct from `JobAlert` (saved-search alerts under `/alerts`) — those
/// are user-defined searches that fire when matching jobs are posted.
/// Notifications are the unified inbox: application status changes,
/// interview invites, new messages, profile views, auto-apply summaries.
enum NotificationKind {
  newJobMatch,
  applicationStatus,
  interviewScheduled,
  newMessage,
  autoApplySummary,
  profileViewed,
  subscriptionExpiry,
  companyNewJob,
  newApplicant,
  system,
}

NotificationKind _parseKind(String? raw) {
  switch (raw) {
    case 'new_job_match':
      return NotificationKind.newJobMatch;
    case 'application_status':
      return NotificationKind.applicationStatus;
    case 'interview_scheduled':
      return NotificationKind.interviewScheduled;
    case 'new_message':
      return NotificationKind.newMessage;
    case 'auto_apply_summary':
      return NotificationKind.autoApplySummary;
    case 'profile_viewed':
      return NotificationKind.profileViewed;
    case 'subscription_expiry':
      return NotificationKind.subscriptionExpiry;
    case 'company_new_job':
      return NotificationKind.companyNewJob;
    case 'new_applicant':
      return NotificationKind.newApplicant;
    default:
      return NotificationKind.system;
  }
}

class AppNotification {
  final String id;
  final NotificationKind kind;
  final String role;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.role,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        kind: kind,
        role: role,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final created = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now();
    return AppNotification(
      id: id,
      kind: _parseKind(json['type'] as String?),
      role: (json['role'] ?? 'seeker') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      data: (json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: json['isRead'] as bool? ?? false,
      createdAt: created,
    );
  }
}

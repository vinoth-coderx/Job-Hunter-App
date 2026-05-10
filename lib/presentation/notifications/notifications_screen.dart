import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/notification_model.dart';
import '../../providers/notification_provider.dart';

/// Unified notification inbox.
///
/// Backed by `/api/v1/notifications` (the cross-cutting feed:
/// application status, interview invites, new messages, profile views,
/// auto-apply summaries). This is intentionally separate from the
/// saved-search-alerts screen — that one is just a list of search
/// definitions, this is the live activity log.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Consumer<NotificationProvider>(
          builder: (_, prov, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Notifications',
                    style: AppTextStyles.h4
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (prov.unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.urgent,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        prov.unread > 99 ? '99+' : '${prov.unread}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                'Application & interview activity',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.textTertiary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: context.textPrimary,
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, prov, __) => prov.unread == 0
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: prov.markAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Mark all read'),
                  ),
          ),
          IconButton(
            tooltip: 'Saved searches',
            icon: const Icon(Icons.bookmark_outline_rounded),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.alerts),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (_, prov, __) {
          if (prov.loading && prov.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.items.isEmpty) {
            return _empty(prov.error);
          }
          final list = _unreadOnly
              ? prov.items.where((n) => !n.isRead).toList()
              : prov.items;
          return RefreshIndicator(
            onRefresh: () => prov.load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _FilterRow(
                  unreadOnly: _unreadOnly,
                  total: prov.items.length,
                  unread: prov.unread,
                  onChange: (v) => setState(() => _unreadOnly = v),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        _unreadOnly ? 'No unread notifications' : 'No notifications',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  for (final n in list) ...[
                    _NotificationTile(
                      notification: n,
                      onTap: () => _handleTap(prov, n),
                      onDismiss: () => prov.remove(n.id),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTap(NotificationProvider prov, AppNotification n) {
    if (!n.isRead) prov.markRead(n.id);
    final route = _routeFor(n);
    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }

  String? _routeFor(AppNotification n) {
    switch (n.kind) {
      case NotificationKind.newMessage:
        return AppRoutes.conversations;
      case NotificationKind.interviewScheduled:
        return AppRoutes.myInterviews;
      case NotificationKind.applicationStatus:
        return null; // Stays on inbox; deep link by jobId is a follow-up.
      case NotificationKind.autoApplySummary:
        return AppRoutes.autoApplyLog;
      case NotificationKind.subscriptionExpiry:
        return AppRoutes.subscription;
      case NotificationKind.newJobMatch:
      case NotificationKind.companyNewJob:
      case NotificationKind.profileViewed:
      case NotificationKind.newApplicant:
      case NotificationKind.system:
        return null;
    }
  }

  Widget _empty(String? error) {
    final isError = error != null && error.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.primary.withValues(alpha: 0.04),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            isError ? Icons.cloud_off_rounded : Icons.notifications_none_rounded,
            size: 44,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isError ? "Couldn't load notifications" : "You're all caught up",
          textAlign: TextAlign.center,
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          isError
              ? error
              : "We'll ping you when a hirer responds or an interview gets scheduled.",
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final bool unreadOnly;
  final int total;
  final int unread;
  final ValueChanged<bool> onChange;
  const _FilterRow({
    required this.unreadOnly,
    required this.total,
    required this.unread,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All · $total',
          selected: !unreadOnly,
          onTap: () => onChange(false),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Unread · $unread',
          selected: unreadOnly,
          onTap: () => onChange(true),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? null : context.surface,
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                )
              : null,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.primary : context.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final v = _visualsFor(n.kind);
    final unread = !n.isRead;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.urgent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.urgent),
      ),
      onDismissed: (_) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : context.cardBorder,
              width: 1,
            ),
            boxShadow: unread
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: v.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(v.icon, color: v.tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(n.createdAt),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: context.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _Visual _visualsFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.newJobMatch:
      case NotificationKind.companyNewJob:
        return const _Visual(Icons.workspace_premium_rounded, AppColors.primary);
      case NotificationKind.applicationStatus:
        return const _Visual(Icons.send_rounded, AppColors.info);
      case NotificationKind.interviewScheduled:
        return const _Visual(Icons.event_available_rounded, AppColors.success);
      case NotificationKind.newMessage:
        return const _Visual(Icons.chat_bubble_rounded, AppColors.primary);
      case NotificationKind.autoApplySummary:
        return const _Visual(Icons.auto_awesome_rounded, AppColors.warning);
      case NotificationKind.profileViewed:
        return const _Visual(Icons.visibility_rounded, AppColors.info);
      case NotificationKind.subscriptionExpiry:
        return const _Visual(Icons.card_membership_rounded, AppColors.urgent);
      case NotificationKind.newApplicant:
        return const _Visual(Icons.person_add_rounded, AppColors.success);
      case NotificationKind.system:
        return _Visual(Icons.notifications_rounded, AppColors.textSecondary);
    }
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }
}

class _Visual {
  final IconData icon;
  final Color tint;
  const _Visual(this.icon, this.tint);
}

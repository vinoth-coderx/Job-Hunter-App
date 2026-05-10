import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/alert_model.dart';
import '../../providers/alert_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/scroll_to_top_fab.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AlertProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove(JobAlert alert) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this alert?',
      message: 'You\'ll stop getting notifications for "${alert.displayLabel}".',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AlertProvider>().remove(alert.id);
  }

  void _runAlert(JobAlert alert) {
    Navigator.pushNamed(
      context,
      AppRoutes.search,
      arguments: AlertSearchArgs(
        query: alert.query,
        filters: alert.filters,
        location: alert.location,
        sort: alert.sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        surfaceTintColor: context.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job alerts',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800)),
            Text(
              provider.alerts.isEmpty
                  ? 'Get notified the moment matches drop'
                  : '${provider.alerts.where((a) => a.active).length} active · ${provider.alerts.length} total',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: context.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(),
        color: AppColors.primary,
        child: _buildBody(provider),
      ),
      floatingActionButton: ScrollToTopFab(
        controller: _scrollCtrl,
        showAfterPixels: 600,
        additionalCondition: () => provider.alerts.length > 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody(AlertProvider provider) {
    if (provider.isLoading && provider.alerts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (provider.alerts.isEmpty) {
      return _buildEmpty(provider.error);
    }
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: provider.alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final alert = provider.alerts[i];
        return AnimatedListItem(
          key: ValueKey(alert.id),
          child: _AlertTile(
            alert: alert,
            onTap: () => _runAlert(alert),
            onToggle: () => provider.toggleActive(alert),
            onDelete: () => _confirmRemove(alert),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String? error) {
    final isError = error != null && error.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
      children: [
        Icon(
          isError ? Icons.cloud_off_rounded : Icons.notifications_none_rounded,
          size: 64,
          color: context.textTertiary,
        ),
        const SizedBox(height: 16),
        Text(
          isError ? 'Could not load alerts' : 'No alerts yet',
          style: AppTextStyles.h4,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isError
              ? error
              : 'Save a search from the Search screen to get notified when matching jobs are posted.',
          style: AppTextStyles.bodySmall
              .copyWith(color: context.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (!isError) ...[
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search jobs'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final JobAlert alert;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AlertTile({
    required this.alert,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: alert.active
                          ? AppColors.primaryLight
                          : context.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alert.active
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      size: 20,
                      color: alert.active
                          ? AppColors.primary
                          : context.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.displayLabel,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (alert.summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            alert.summary,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.textTertiary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: alert.active,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (alert.notificationCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '${alert.notificationCount} notification${alert.notificationCount == 1 ? '' : 's'}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: context.textTertiary,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Args passed when opening the search screen pre-populated from an alert.
class AlertSearchArgs {
  final String query;
  final List<String> filters;
  final String? location;
  final String sort;
  const AlertSearchArgs({
    required this.query,
    required this.filters,
    this.location,
    required this.sort,
  });
}

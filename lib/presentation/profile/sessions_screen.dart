import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/security_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _svc = SecurityService.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _sessions = await _svc.listSessions();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(String id) async {
    setState(() => _busyId = id);
    try {
      await _svc.revokeSession(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revokeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of all devices?'),
        content: const Text(
          'You will be signed out everywhere. The current device will require a fresh login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out everywhere'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _svc.revokeAllSessions();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Active sessions', style: AppTextStyles.h3),
        actions: [
          TextButton(
            onPressed: _revokeAll,
            child: const Text('Sign out all'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText.body(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        PrimaryButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      final id = s['_id'] as String;
                      return _SessionCard(
                        platform: (s['platform'] as String?) ?? 'unknown',
                        ip: s['ip'] as String?,
                        userAgent: s['userAgent'] as String?,
                        lastActivityAt: s['lastActivityAt'] as String?,
                        trusted: s['trusted'] as bool? ?? false,
                        busy: _busyId == id,
                        onRevoke: () => _revoke(id),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.platform,
    required this.ip,
    required this.userAgent,
    required this.lastActivityAt,
    required this.trusted,
    required this.busy,
    required this.onRevoke,
  });

  final String platform;
  final String? ip;
  final String? userAgent;
  final String? lastActivityAt;
  final bool trusted;
  final bool busy;
  final VoidCallback onRevoke;

  IconData get _icon {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
      case 'admin_web':
        return Icons.computer;
      default:
        return Icons.devices_other;
    }
  }

  String _formatRelative(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return DateFormat.yMMMd().add_jm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 28, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppText.body(
                      platform.toUpperCase(),
                      fontWeight: FontWeight.w600,
                    ),
                    if (trusted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AppText.labelSmall(
                          'trusted',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
                if (userAgent != null)
                  AppText.caption(
                    userAgent!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                AppText.caption(
                  '${ip ?? "—"} · ${lastActivityAt != null ? _formatRelative(lastActivityAt!) : ""}',
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: busy ? null : onRevoke,
          ),
        ],
      ),
    );
  }
}

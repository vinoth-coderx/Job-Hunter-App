import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/api_client.dart';
import '../../data/services/user_service.dart';
import '../widgets/custom_button.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  final UserService _userSvc = UserService();
  final ApiClient _api = ApiClient.instance;

  bool _loading = true;
  String? _error;

  bool _push = true;
  bool _email = true;
  bool _whatsapp = false;
  bool _jobAlerts = true;
  bool _applicationUpdates = true;
  bool _autoApplySummary = true;
  bool _aiPolish = true;
  String _quietStart = '22:00';
  String _quietEnd = '08:00';

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
      // Pull from /auth/me — already returns full user incl. preferences.
      final raw = await _api.get('auth/me');
      final data = (ApiClient.unwrapMap(raw)['notificationPreferences']
              as Map<String, dynamic>?) ??
          const {};
      if (!mounted) return;
      setState(() {
        _push = data['push'] as bool? ?? true;
        _email = data['email'] as bool? ?? true;
        _whatsapp = data['whatsapp'] as bool? ?? false;
        _jobAlerts = data['jobAlerts'] as bool? ?? true;
        _applicationUpdates = data['applicationUpdates'] as bool? ?? true;
        _autoApplySummary = data['autoApplySummary'] as bool? ?? true;
        _aiPolish = data['aiPolish'] as bool? ?? true;
        _quietStart = (data['quietHoursStart'] as String?) ?? '22:00';
        _quietEnd = (data['quietHoursEnd'] as String?) ?? '08:00';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _userSvc.updateNotificationPrefs(
        push: _push,
        email: _email,
        whatsapp: _whatsapp,
        jobAlerts: _jobAlerts,
        applicationUpdates: _applicationUpdates,
        autoApplySummary: _autoApplySummary,
        aiPolish: _aiPolish,
        quietHoursStart: _quietStart,
        quietHoursEnd: _quietEnd,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Notification preferences saved'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final cur = isStart ? _quietStart : _quietEnd;
    final parts = cur.split(':');
    final tod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 22,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
    );
    if (tod == null) return;
    final hh = tod.hour.toString().padLeft(2, '0');
    final mm = tod.minute.toString().padLeft(2, '0');
    setState(() {
      if (isStart) {
        _quietStart = '$hh:$mm';
      } else {
        _quietEnd = '$hh:$mm';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _section('Channels'),
                    _channelTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Push',
                      subtitle: 'In-app and lock-screen notifications',
                      value: _push,
                      onChanged: (v) => setState(() => _push = v),
                    ),
                    _channelTile(
                      icon: Icons.mail_outline,
                      title: 'Email',
                      subtitle: 'Daily / immediate digests',
                      value: _email,
                      onChanged: (v) => setState(() => _email = v),
                    ),
                    _channelTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'WhatsApp',
                      subtitle: 'Top-match alerts only — opt-in',
                      value: _whatsapp,
                      onChanged: (v) => setState(() => _whatsapp = v),
                    ),
                    const SizedBox(height: 16),
                    _section('Categories'),
                    _channelTile(
                      icon: Icons.work_outline_rounded,
                      title: 'Job alerts',
                      subtitle: 'Saved-search matches',
                      value: _jobAlerts,
                      onChanged: (v) => setState(() => _jobAlerts = v),
                    ),
                    _channelTile(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Application updates',
                      subtitle: 'Status changes, interview invites',
                      value: _applicationUpdates,
                      onChanged: (v) =>
                          setState(() => _applicationUpdates = v),
                    ),
                    _channelTile(
                      icon: Icons.auto_awesome,
                      title: 'Auto-Apply summary',
                      subtitle: 'Daily summary of auto-applied jobs',
                      value: _autoApplySummary,
                      onChanged: (v) => setState(() => _autoApplySummary = v),
                    ),
                    const SizedBox(height: 16),
                    _section('AI'),
                    _channelTile(
                      icon: Icons.auto_fix_high_rounded,
                      title: 'AI polish notifications',
                      subtitle:
                          'Let AI rewrite alert titles & bodies for clarity. Off keeps the original copy.',
                      value: _aiPolish,
                      onChanged: (v) => setState(() => _aiPolish = v),
                    ),
                    const SizedBox(height: 16),
                    _section('Quiet hours'),
                    _timeRow('Start', _quietStart,
                        () => _pickTime(isStart: true)),
                    _timeRow('End', _quietEnd,
                        () => _pickTime(isStart: false)),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Save changes', onPressed: _save),
                  ],
                ),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            )),
      );

  Widget _channelTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder),
        ),
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
          secondary: Icon(icon, color: AppColors.primary),
          title: Text(title,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        ),
      );

  Widget _timeRow(String label, String value, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder),
        ),
        child: ListTile(
          leading: const Icon(Icons.bedtime_outlined,
              color: AppColors.primary),
          title: Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          trailing: Text(value, style: AppTextStyles.bodyMedium),
          onTap: onTap,
        ),
      );
}

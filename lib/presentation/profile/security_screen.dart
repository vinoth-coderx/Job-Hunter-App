import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/api_client.dart';
import '../../data/services/security_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import 'two_factor_setup_screen.dart';
import 'sessions_screen.dart';
import 'resume_access_log_screen.dart';

/// Settings → Security & Privacy. Aggregates the 2FA toggle, sessions
/// link, resume access log link, and the privacy switches described in
/// `security.md` (open-to-work, hide-from-current-employer, resume
/// visibility, searchability, download permission).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final SecurityService _svc = SecurityService.instance;
  final ApiClient _api = ApiClient.instance;

  bool _loading = true;
  String? _error;

  bool _twoFaEnabled = false;
  bool _openToWork = false;
  bool _hideFromCurrentEmployer = false;
  bool _hidePersonalDetails = false;
  bool _hideContactUntilShortlisted = true;
  String _resumeVisibility = 'applied_only';
  bool _searchable = true;
  bool _allowResumeDownload = true;
  bool _saving = false;

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
      final raw = await _api.get('auth/me');
      final user = ApiClient.unwrapMap(raw);
      final twoFactor = (user['twoFactor'] as Map?) ?? const {};
      final privacy = (user['privacy'] as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        _twoFaEnabled = twoFactor['enabled'] as bool? ?? false;
        _openToWork = privacy['openToWork'] as bool? ?? false;
        _hideFromCurrentEmployer =
            privacy['hideFromCurrentEmployer'] as bool? ?? false;
        _hidePersonalDetails = privacy['hidePersonalDetails'] as bool? ?? false;
        _hideContactUntilShortlisted =
            privacy['hideContactUntilShortlisted'] as bool? ?? true;
        _resumeVisibility =
            privacy['resumeVisibility'] as String? ?? 'applied_only';
        _searchable = privacy['searchableInResumeDatabase'] as bool? ?? true;
        _allowResumeDownload = privacy['allowResumeDownload'] as bool? ?? true;
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

  Future<void> _savePrivacy(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await _svc.updatePrivacy(patch);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disable2fa() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable two-factor?'),
        content: const Text(
          'You will be signed in with just your password. Strongly not recommended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _svc.disable2fa();
      if (!mounted) return;
      setState(() => _twoFaEnabled = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security & Privacy', style: AppTextStyles.h3),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _SectionHeader('Authentication'),
                      _Tile(
                        icon: Icons.verified_user_outlined,
                        title: 'Two-factor authentication',
                        subtitle: _twoFaEnabled
                            ? 'Enabled — authenticator app'
                            : 'Disabled',
                        trailing: Switch(
                          value: _twoFaEnabled,
                          onChanged: (v) async {
                            if (v) {
                              final res = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TwoFactorSetupScreen(),
                                ),
                              );
                              if (res == true && mounted) {
                                setState(() => _twoFaEnabled = true);
                              }
                            } else {
                              await _disable2fa();
                            }
                          },
                        ),
                      ),
                      _Tile(
                        icon: Icons.devices_outlined,
                        title: 'Active sessions',
                        subtitle: 'Where you are signed in',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SessionsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader('Visibility & privacy'),
                      _SwitchTile(
                        title: 'Open to work',
                        subtitle:
                            'Show a discreet "Open to work" pill to recruiters',
                        value: _openToWork,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _openToWork = v);
                                _savePrivacy({'openToWork': v});
                              },
                      ),
                      _SwitchTile(
                        title: 'Hide from current employer',
                        subtitle:
                            'Hide your profile from recruiters whose company matches your latest job',
                        value: _hideFromCurrentEmployer,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _hideFromCurrentEmployer = v);
                                _savePrivacy({'hideFromCurrentEmployer': v});
                              },
                      ),
                      _SwitchTile(
                        title: 'Hide personal details',
                        subtitle:
                            'Mask phone, email, address on public profile views',
                        value: _hidePersonalDetails,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _hidePersonalDetails = v);
                                _savePrivacy({'hidePersonalDetails': v});
                              },
                      ),
                      _SwitchTile(
                        title: 'Hide contact until shortlisted',
                        subtitle:
                            'Recruiters see your details only after shortlisting you',
                        value: _hideContactUntilShortlisted,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(
                                    () => _hideContactUntilShortlisted = v);
                                _savePrivacy(
                                    {'hideContactUntilShortlisted': v});
                              },
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeader('Resume'),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText.body('Resume visibility'),
                        subtitle: AppText.caption(
                          _resumeVisibility == 'public'
                              ? 'Anyone can find your resume'
                              : _resumeVisibility == 'applied_only'
                                  ? 'Only recruiters of jobs you applied to'
                                  : 'Private — nobody can browse',
                        ),
                        trailing: DropdownButton<String>(
                          value: _resumeVisibility,
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public'),
                            ),
                            DropdownMenuItem(
                              value: 'applied_only',
                              child: Text('Applied only'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Private'),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() => _resumeVisibility = v);
                                  _savePrivacy({'resumeVisibility': v});
                                },
                        ),
                      ),
                      _SwitchTile(
                        title: 'Searchable in resume database',
                        subtitle:
                            'Cold-discovery searches by recruiters can find your profile',
                        value: _searchable,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _searchable = v);
                                _savePrivacy(
                                    {'searchableInResumeDatabase': v});
                              },
                      ),
                      _SwitchTile(
                        title: 'Allow recruiters to download resume',
                        subtitle:
                            'Disable to allow only in-app viewing (no PDF download)',
                        value: _allowResumeDownload,
                        onChanged: _saving
                            ? null
                            : (v) {
                                setState(() => _allowResumeDownload = v);
                                _savePrivacy({'allowResumeDownload': v});
                              },
                      ),
                      _Tile(
                        icon: Icons.visibility_outlined,
                        title: 'Resume access log',
                        subtitle: 'Who viewed or downloaded your resume',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ResumeAccessLogScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: AppText.labelSmall(
        label.toUpperCase(),
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: AppText.body(title),
      subtitle: subtitle == null ? null : AppText.caption(subtitle!),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: AppColors.textTertiary)
              : null),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText.body(title),
      subtitle: AppText.caption(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.body(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

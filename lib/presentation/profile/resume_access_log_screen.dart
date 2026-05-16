import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/security_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';

class ResumeAccessLogScreen extends StatefulWidget {
  const ResumeAccessLogScreen({super.key});

  @override
  State<ResumeAccessLogScreen> createState() => _ResumeAccessLogScreenState();
}

class _ResumeAccessLogScreenState extends State<ResumeAccessLogScreen> {
  final _svc = SecurityService.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = const [];

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
      _entries = await _svc.resumeAccessLog();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatRelative(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return DateFormat.yMMMd().add_jm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resume access log', style: AppTextStyles.h3)),
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
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppText.body(
                          'No recruiter has viewed your resume yet.',
                          textAlign: TextAlign.center,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = _entries[i];
                          final accessor =
                              (e['accessor'] as Map?) ?? const {};
                          final profile =
                              (accessor['profile'] as Map?) ?? const {};
                          final name = (profile['fullName'] as String?) ??
                              (accessor['email'] as String?) ??
                              'A recruiter';
                          final action = (e['action'] as String?) ?? 'view';
                          final company = e['company'] as String?;
                          return ListTile(
                            leading: Icon(
                              action == 'download'
                                  ? Icons.download
                                  : Icons.visibility,
                            ),
                            title: AppText.body(name),
                            subtitle: AppText.caption(
                              [
                                if (company != null) company,
                                _formatRelative(e['createdAt'] as String),
                                action,
                              ].join(' · '),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

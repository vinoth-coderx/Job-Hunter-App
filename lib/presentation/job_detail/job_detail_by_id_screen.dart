import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/job_service.dart';
import '../widgets/app_text.dart';

/// Entry point for push notifications and email deep links that only
/// carry a job id (not the full Job model). Loads the job from the API
/// and `pushReplacementNamed`s into the regular [AppRoutes.jobDetail]
/// route, so the user lands on the same screen they'd reach via the
/// home feed — back-button included.
///
/// When the fetch fails (job pulled, network out, bad id) we show an
/// inline error with a tap-to-retry, instead of silently dropping the
/// user on a blank screen.
class JobDetailByIdScreen extends StatefulWidget {
  final String jobId;
  const JobDetailByIdScreen({super.key, required this.jobId});

  @override
  State<JobDetailByIdScreen> createState() => _JobDetailByIdScreenState();
}

class _JobDetailByIdScreenState extends State<JobDetailByIdScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.jobId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing job id';
      });
      return;
    }
    try {
      final job = await JobService().getJobById(widget.jobId);
      if (!mounted) return;
      if (job == null) {
        setState(() {
          _loading = false;
          _error = 'Job not found or no longer active';
        });
        return;
      }
      // Replace this loader so the back button returns to wherever the
      // user came from (home, notifications, external app), not the
      // loader skeleton.
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.jobDetail,
        arguments: job,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this job: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: context.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    AppText.bodyLarge(
                      _error ?? 'Something went wrong',
                      color: context.textPrimary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              AppRoutes.main,
                            );
                          },
                          child: const Text('Go home'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _load();
                          },
                          child: const Text('Retry'),
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

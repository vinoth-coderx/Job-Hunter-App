import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/job_model.dart';
import '../../data/services/company_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/job_card.dart';
import '../widgets/report_sheet.dart';
import '../widgets/trust_badges.dart';
import 'add_review_sheet.dart';

class CompanyProfileScreen extends StatefulWidget {
  final String companyId;
  const CompanyProfileScreen({super.key, required this.companyId});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen>
    with SingleTickerProviderStateMixin {
  final CompanyService _service = CompanyService.instance;
  late final TabController _tabs;
  CompanyProfile? _profile;
  List<Job> _jobs = const [];
  List<CompanyReview> _reviews = const [];
  bool _loading = true;
  String? _error;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.getProfile(widget.companyId);
      final results = await Future.wait([
        _service.listJobs(widget.companyId),
        _service.listReviews(widget.companyId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _jobs = results[0] as List<Job>;
        _reviews = results[1] as List<CompanyReview>;
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

  Future<void> _toggleFollow() async {
    final p = _profile;
    if (p == null || _followBusy) return;
    setState(() => _followBusy = true);
    try {
      if (p.isFollowing) {
        await _service.unfollow(p.id);
      } else {
        await _service.follow(p.id);
      }
      await _refresh();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openReview() async {
    final saved = await AddReviewSheet.show(context, widget.companyId);
    if (saved == true) await _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final p = _profile!;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(p.companyName),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report company',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await showReportSheet(
                context: context,
                subjectType: 'company',
                subjectId: p.id,
              );
              if (ok && mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Report submitted.')),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'About'),
            Tab(text: 'Jobs'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: Column(
        children: [
          _header(p),
          if (p.approvalStatus == 'suspended' || p.approvalStatus == 'banned')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FraudWarningBanner(
                message: p.approvalStatus == 'banned'
                    ? 'This company has been banned from the platform. Do not apply or share personal information.'
                    : 'This company is currently suspended pending review. We do not recommend applying right now.',
              ),
            )
          else if (!p.isVerified && p.trustScore < 40)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FraudWarningBanner(
                message:
                    'This company is unverified with low trust signals. Never pay any recruiter to apply and never share OTPs or bank details.',
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _aboutTab(p),
                _jobsTab(),
                _reviewsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabs.index == 2
          ? FloatingActionButton.extended(
              onPressed: _openReview,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Review'),
            )
          : null,
    );
  }

  Widget _header(CompanyProfile p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          _CompanyLogo(url: p.companyLogoUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.companyName,
                        style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isVerified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SafeApplyBadge.fromFlags(
                      companyVerified: p.isVerified,
                      recruiterApproved: p.approvalStatus == 'approved',
                      trustScore: p.trustScore,
                    ),
                    if (p.industry != null && p.industry!.isNotEmpty)
                      Text(p.industry!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textSecondary)),
                    if (p.totalReviews > 0)
                      Text(
                        '★ ${p.ratingAverage.toStringAsFixed(1)} · ${p.totalReviews} reviews',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.warning),
                      ),
                    Text('${p.followersCount} followers',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: context.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _followBusy ? null : _toggleFollow,
            icon: Icon(
                p.isFollowing
                    ? Icons.notifications_active
                    : Icons.add_alert_outlined,
                size: 18),
            label: Text(p.isFollowing ? 'Following' : 'Follow'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  p.isFollowing ? AppColors.success : AppColors.primary,
              side: BorderSide(
                color: (p.isFollowing
                        ? AppColors.success
                        : AppColors.primary)
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Naukri-style rating breakdown: big overall number on the left, per-
  /// dimension bars on the right. Computed from the loaded reviews list
  /// (backend only stores the overall aggregate, not per-dimension averages).
  Widget _ratingBreakdown() {
    if (_reviews.isEmpty) return const SizedBox.shrink();
    double avg(int? Function(CompanyReview r) pick) {
      final vals = _reviews.map(pick).whereType<int>().toList();
      if (vals.isEmpty) return 0;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    final overall = avg((r) => r.overall);
    final culture = avg((r) => r.culture);
    final wlb = avg((r) => r.workLifeBalance);
    final growth = avg((r) => r.growth);
    final pay = avg((r) => r.pay);
    final mgmt = avg((r) => r.management);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(
                overall.toStringAsFixed(1),
                style: AppTextStyles.h2.copyWith(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < overall.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.warning,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text('${_reviews.length} reviews',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _ratingBar('Culture', culture),
                _ratingBar('Work-life balance', wlb),
                _ratingBar('Growth', growth),
                _ratingBar('Pay & benefits', pay),
                _ratingBar('Management', mgmt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(String label, double value) {
    final pct = (value / 5).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: context.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              value > 0 ? value.toStringAsFixed(1) : '—',
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutTab(CompanyProfile p) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_reviews.isNotEmpty) ...[
            _ratingBreakdown(),
            const SizedBox(height: 16),
          ],
          if (p.description != null && p.description!.isNotEmpty) ...[
            _sectionTitle('About'),
            Text(p.description!),
            const SizedBox(height: 16),
          ],
          if (p.cultureValues != null && p.cultureValues!.isNotEmpty) ...[
            _sectionTitle('Culture'),
            Text(p.cultureValues!),
            const SizedBox(height: 16),
          ],
          _sectionTitle('Quick facts'),
          if (p.companySize != null) _kv('Size', p.companySize!),
          if (p.foundedYear != null) _kv('Founded', '${p.foundedYear}'),
          if (p.website != null && p.website!.isNotEmpty)
            _kv('Website', p.website!),
          _kv('Active jobs', '${p.activeJobsCount}'),
          if (p.officePhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Office'),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.officePhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(p.officePhotos[i],
                      width: 160, height: 120, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            color: context.surfaceVariant,
                            child: const Icon(Icons.broken_image),
                          )),
                ),
              ),
            ),
          ],
        ],
      );

  Widget _jobsTab() {
    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No active jobs',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: context.textSecondary)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => JobCard(
        job: _jobs[i],
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.jobDetail,
          arguments: _jobs[i],
        ),
      ),
    );
  }

  Widget _reviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rate_review_outlined,
                  size: 48, color: context.textTertiary),
              const SizedBox(height: 8),
              Text('No reviews yet',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: context.textSecondary)),
              const SizedBox(height: 8),
              Text('Be the first — tap the Review button below.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textTertiary)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reviewCard(_reviews[i]),
    );
  }

  Widget _reviewCard(CompanyReview r) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stars(r.overall),
                const SizedBox(width: 8),
                Text('${r.overall}/5',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy').format(r.createdAt.toLocal()),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              r.isAnonymous
                  ? '${r.reviewerRole.replaceAll('_', ' ')} · anonymous'
                  : (r.reviewerName ?? r.reviewerRole),
              style: AppTextStyles.bodySmall
                  .copyWith(color: context.textSecondary),
            ),
            if (r.title != null && r.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.title!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
            if (r.pros != null && r.pros!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Pros',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
              Text(r.pros!),
            ],
            if (r.cons != null && r.cons!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Cons',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.urgent, fontWeight: FontWeight.w700)),
              Text(r.cons!),
            ],
          ],
        ),
      );

  Widget _stars(int v) => Row(
        children: List.generate(
          5,
          (i) => Icon(
            i < v ? Icons.star : Icons.star_border,
            size: 16,
            color: AppColors.warning,
          ),
        ),
      );

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: context.textPrimary)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textSecondary)),
            ),
            Expanded(
              child: Text(v,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: context.textPrimary)),
            ),
          ],
        ),
      );
}

class _CompanyLogo extends StatelessWidget {
  final String? url;
  final double size;
  const _CompanyLogo({required this.url, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final resolved = AppAvatar.resolveBackendUrl(url);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.business, color: AppColors.primary),
    );
    if (resolved == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

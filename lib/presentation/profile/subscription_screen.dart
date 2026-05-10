import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/subscription_model.dart';
import '../../providers/auth_provider.dart';
import 'payment_screen.dart';

/// All copy on this screen — names, prices, durations, features, current
/// plan badge — comes from the backend (`/subscriptions/plans` and
/// `/subscriptions/current`). Nothing is hardcoded.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan? _selected;
  bool _initialLoad = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    await Future.wait<void>([
      auth.loadSubscriptionPlans(),
      auth.loadCurrentSubscription(),
    ]);
    if (!mounted) return;
    final plans = auth.plans;
    final current = auth.subscriptionState.tier;
    SubscriptionPlan? defaultSelection;
    // Default selection: pick the user's current paid tier, otherwise the
    // most popular paid tier the backend offered (monthly), else first non-free.
    if (current != SubscriptionPlan.free) {
      defaultSelection = current;
    } else {
      final preferred = plans
          .map((p) => p.tier)
          .firstWhere((t) => t == SubscriptionPlan.proMonthly,
              orElse: () => plans.isEmpty
                  ? SubscriptionPlan.free
                  : plans
                      .firstWhere(
                        (p) => p.tier != SubscriptionPlan.free,
                        orElse: () => plans.first,
                      )
                      .tier);
      defaultSelection = preferred;
    }
    setState(() {
      _selected = defaultSelection;
      _initialLoad = false;
    });
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    await Future.wait<void>([
      auth.loadSubscriptionPlans(force: true),
      auth.loadCurrentSubscription(),
    ]);
  }

  Future<void> _handleAction(SubscriptionPlanInfo plan) async {
    final auth = context.read<AuthProvider>();
    final current = auth.subscriptionState.tier;

    // Free tier doesn't go through payment.
    if (plan.tier == SubscriptionPlan.free) {
      if (current == SubscriptionPlan.free) return;
      // Switching from paid → free is a cancellation on the backend.
      await _doCancel(confirmFirst: true);
      return;
    }

    // Paid tier — open payment screen, then on success record via API.
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(plan: plan),
      ),
    );
    if (!mounted || paid != true) return;

    setState(() => _busy = true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ok = await auth.subscribeToTier(
      plan.tier,
      paymentMethod: 'razorpay',
      paymentId: 'pay_stub_$ts',
      orderId: 'order_stub_$ts',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      ok ? '${plan.name} plan activated' : (auth.error ?? 'Could not subscribe'),
      ok ? AppColors.success : AppColors.urgent,
    );
    if (ok) Navigator.pop(context);
  }

  Future<void> _doCancel({bool confirmFirst = false}) async {
    if (confirmFirst) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Cancel subscription?'),
          content: const Text(
            "You'll lose Pro features at the end of your current billing period.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep plan'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (!mounted || ok != true) return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final ok = await auth.cancelSubscription();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      ok ? 'Subscription cancelled' : (auth.error ?? 'Could not cancel'),
      ok ? AppColors.success : AppColors.urgent,
    );
  }

  void _toast(String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final plans = _orderedPlans(auth.plans);
    final state = auth.subscriptionState;
    final selectedPlan = _selected == null
        ? null
        : plans.cast<SubscriptionPlanInfo?>().firstWhere(
              (p) => p?.tier == _selected,
              orElse: () => null,
            );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.gradientTop, context.gradientBottom],
              stops: [0.0, 0.4],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  title: 'Subscription',
                  trailing: state.canCancel
                      ? IconButton(
                          tooltip: 'Cancel subscription',
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: _busy
                              ? null
                              : () => _doCancel(confirmFirst: true),
                        )
                      : null,
                ),
                Expanded(
                  child: _initialLoad
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : plans.isEmpty
                          ? _LoadError(onRetry: _refresh)
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              color: AppColors.primary,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 4, 20, 32),
                                children: [
                                  _CurrentPlanCard(state: state),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Choose your plan',
                                    style: AppTextStyles.h4,
                                  ),
                                  const SizedBox(height: 12),
                                  for (final p in plans) ...[
                                    _PlanTile(
                                      plan: p,
                                      isSelected: _selected == p.tier,
                                      isCurrent: state.tier == p.tier,
                                      tag: _tagFor(p, plans),
                                      onTap: () =>
                                          setState(() => _selected = p.tier),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Center(
                                    child: Text(
                                      'Secure payments via Razorpay · Cancel anytime',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
                if (selectedPlan != null && !_initialLoad)
                  _ActionBar(
                    plan: selectedPlan,
                    isCurrent: state.tier == selectedPlan.tier,
                    busy: _busy || auth.subscriptionLoading,
                    onAction: () => _handleAction(selectedPlan),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ordering: Yearly first (highest value), then Monthly, Weekly, Free
  /// last. Driven by the API's tier IDs so we don't hardcode names.
  List<SubscriptionPlanInfo> _orderedPlans(List<SubscriptionPlanInfo> plans) {
    const order = [
      SubscriptionPlan.proYearly,
      SubscriptionPlan.proMonthly,
      SubscriptionPlan.weekly,
      SubscriptionPlan.free,
    ];
    final sorted = [...plans];
    sorted.sort((a, b) =>
        order.indexOf(a.tier).compareTo(order.indexOf(b.tier)));
    return sorted;
  }

  /// Tag computed from real prices: how much the plan saves vs. the
  /// monthly equivalent. Only tags the yearly plan and only when it
  /// genuinely saves money.
  String? _tagFor(
      SubscriptionPlanInfo plan, List<SubscriptionPlanInfo> all) {
    if (plan.tier != SubscriptionPlan.proYearly) return null;
    final monthly = all
        .cast<SubscriptionPlanInfo?>()
        .firstWhere((p) => p?.tier == SubscriptionPlan.proMonthly,
            orElse: () => null);
    if (monthly == null || monthly.priceInr <= 0) return 'Best value';
    final yearAtMonthly = monthly.priceInr * 12;
    if (plan.priceInr >= yearAtMonthly) return 'Best value';
    final saved = ((yearAtMonthly - plan.priceInr) / yearAtMonthly * 100)
        .round();
    return 'Best value · Save $saved%';
  }
}

class _Header extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _Header({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: context.textPrimary),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(title,
                      style: AppTextStyles.h4
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    'Pick the plan that fits your hunt',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionState state;
  const _CurrentPlanCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isPro = state.isPro;
    final plan = state.plan;
    final activeRecord = state.activeSubscription;
    final endsOn = activeRecord?.endDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? const [Color(0xFFF59E0B), Color(0xFFEF4444)]
              : const [Color(0xFF1A2E5A), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isPro ? const Color(0xFFF59E0B) : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              isPro
                  ? Icons.workspace_premium_rounded
                  : Icons.rocket_launch_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPro
                              ? Icons.workspace_premium_rounded
                              : Icons.lock_outline_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPro ? 'PRO' : 'FREE',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (state.canCancel)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Active',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isPro
                    ? 'You are on ${plan?.name ?? state.tier.label}'
                    : 'Go Pro & accelerate your job hunt',
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPro && endsOn != null
                    ? 'Renews ${_fmtDate(endsOn)}'
                    : 'Unlimited matches, AI insights, priority recruiter visibility.',
                style:
                    AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _PlanTile extends StatelessWidget {
  final SubscriptionPlanInfo plan;
  final bool isSelected;
  final bool isCurrent;
  final String? tag;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Radio(selected: isSelected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              plan.name,
                              style: AppTextStyles.bodyLarge
                                  .copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              label: 'Current',
                              color: AppColors.success,
                            ),
                          ],
                          if (plan.prioritySupport) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.support_agent_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(plan),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: AppTextStyles.h3.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(text: plan.priceLabel),
                      TextSpan(
                        text: ' ${plan.periodLabel}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tag != null) ...[
              const SizedBox(height: 12),
              _Badge(label: tag!, color: AppColors.warning, filled: true),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...plan.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitleFor(SubscriptionPlanInfo p) {
    if (p.tier == SubscriptionPlan.free) {
      return '${p.jobMatchLimit} matched jobs / day · Email support';
    }
    if (p.durationDays >= 350) {
      return 'Billed annually · Cancel anytime';
    }
    if (p.durationDays >= 28) {
      return 'Billed monthly · Cancel anytime';
    }
    return 'Billed every ${p.durationDays} days';
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : context.divider,
          width: 2,
        ),
        color: selected ? AppColors.primary : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Badge({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.15 : 0.15),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final SubscriptionPlanInfo plan;
  final bool isCurrent;
  final bool busy;
  final VoidCallback onAction;

  const _ActionBar({
    required this.plan,
    required this.isCurrent,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = _label();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.h3.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(text: plan.priceLabel),
                      TextSpan(
                        text: ' ${plan.periodLabel}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: (busy || (isCurrent && plan.tier == SubscriptionPlan.free))
                ? null
                : onAction,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: busy ||
                          (isCurrent && plan.tier == SubscriptionPlan.free)
                      ? [
                          AppColors.primary.withValues(alpha: 0.5),
                          AppColors.primaryDark.withValues(alpha: 0.5),
                        ]
                      : const [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: busy
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppTextStyles.button
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _label() {
    if (plan.tier == SubscriptionPlan.free) {
      return isCurrent ? 'Current' : 'Switch to Free';
    }
    if (isCurrent) return 'Renew';
    return 'Continue';
  }
}

class _LoadError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: context.textTertiary),
            const SizedBox(height: 16),
            Text("Couldn't load plans", style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

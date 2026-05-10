import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/auto_apply_settings_model.dart';
import '../../data/services/auto_apply_service.dart';
import '../../providers/auto_apply_provider.dart';
import '../../providers/job_provider.dart';
import '../widgets/custom_button.dart';

/// Auto-Apply settings screen.
///   - Lets the user toggle Auto-Apply on/off
///   - Configure schedule (time + days)
///   - Set match preferences (roles, locations, salary, sources)
///   - Set matching rules (min %, skill count, keywords, blacklist, cooldown)
///   - Choose review mode vs auto-send
///
/// Free / weekly tiers see an "Upgrade" gate; monthly = 10/day, yearly = 30/day.
class AutoApplySetupScreen extends StatefulWidget {
  const AutoApplySetupScreen({super.key});

  @override
  State<AutoApplySetupScreen> createState() => _AutoApplySetupScreenState();
}

class _AutoApplySetupScreenState extends State<AutoApplySetupScreen>
    with TapGuardMixin<AutoApplySetupScreen> {
  // Controllers for chip-input fields (kept until dispose).
  final _roleInput = TextEditingController();
  final _locationInput = TextEditingController();
  final _includeKwInput = TextEditingController();
  final _excludeKwInput = TextEditingController();
  final _blacklistInput = TextEditingController();

  // Local edit state — copied from provider on first load, written back on save.
  bool _isEnabled = false;
  String _runTime = '09:00';
  Set<String> _runDays = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday'};
  int _dailyLimit = 10;
  AutoApplyPreferences _prefs = const AutoApplyPreferences();
  AutoApplyMatchingRules _rules = const AutoApplyMatchingRules();
  bool _hydrated = false;

  static const _allDays = [
    ('mon', 'monday'),
    ('tue', 'tuesday'),
    ('wed', 'wednesday'),
    ('thu', 'thursday'),
    ('fri', 'friday'),
    ('sat', 'saturday'),
    ('sun', 'sunday'),
  ];

  static const _runTimes = ['09:00', '14:00', '18:00'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AutoApplyProvider>().load(),
    );
  }

  void _hydrateFrom(AutoApplySettings s) {
    if (_hydrated) return;
    _hydrated = true;
    _isEnabled = s.isEnabled;
    _runTime = s.runTime;
    _runDays = s.runDays.toSet();
    _dailyLimit = s.dailyLimit;
    _prefs = s.preferences;
    _rules = s.matchingRules;
  }

  @override
  void dispose() {
    _roleInput.dispose();
    _locationInput.dispose();
    _includeKwInput.dispose();
    _excludeKwInput.dispose();
    _blacklistInput.dispose();
    super.dispose();
  }

  Future<void> _runNow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await AutoApplyService.instance.runNow();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Run done · matched ${r['jobsMatched']} · applied ${r['jobsApplied']}'),
        behavior: SnackBarBehavior.floating,
      ));
      // Pull the freshest applications list when the run actually
      // applied to anything — keeps job cards in the home/search feed
      // in sync with the new "Applied" status without a full reload.
      final appliedCount = (r['jobsApplied'] as num?)?.toInt() ?? 0;
      if (appliedCount > 0 && mounted) {
        await context.read<JobProvider>().refreshApplications();
      }
      if (mounted) await context.read<AutoApplyProvider>().load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Run failed: $e')));
    }
  }

  Future<void> _save() async {
    final prov = context.read<AutoApplyProvider>();
    final ok = await prov.save(
      isEnabled: _isEnabled,
      runTime: _runTime,
      runDays: _runDays.toList(),
      dailyLimit: _dailyLimit,
      preferences: _prefs,
      matchingRules: _rules,
      // Always direct-apply now — the legacy reviewMode toggle was
      // removed. Pinning to false keeps existing accounts in sync if
      // their saved record still has reviewMode=true.
      reviewMode: false,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(prov.error ?? 'Could not save Auto-Apply settings')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Auto-Apply preferences saved'),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Auto-Apply',
                    style: AppTextStyles.h4
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'You sleep · We apply',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<AutoApplyProvider>(
        builder: (context, prov, _) {
          if (prov.loading && prov.settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = prov.settings;
          if (s == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  prov.error ?? 'Could not load Auto-Apply.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            );
          }

          _hydrateFrom(s);
          if (!s.eligible) return _upgradeGate(s);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (s.trial.active) ...[
                _trialBanner(s),
                const SizedBox(height: 12),
              ],
              _statusCard(s),
              const SizedBox(height: 16),
              _section('Schedule'),
              _scheduleCard(s),
              const SizedBox(height: 16),
              _section('What to apply for'),
              _preferencesCard(),
              const SizedBox(height: 16),
              _section('Matching rules'),
              _matchingCard(),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save preferences',
                isLoading: prov.loading,
                onPressed: prov.loading ? null : _save,
              ),
              if (s.isEnabled) ...[
                const SizedBox(height: 16),
                _section('Quick actions'),
                _quickActionsGrid(prov, s),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Upgrade gate ───────────────────────────────────────────────────
  Widget _upgradeGate(AutoApplySettings s) {
    final trialEnded = s.trial.used && !s.trial.active;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.auto_awesome,
            size: 72,
            color: AppColors.primary.withValues(alpha: 0.55)),
        const SizedBox(height: 16),
        Text(
          trialEnded
              ? 'Your free trial has ended'
              : 'Auto-Apply is a Pro / Elite feature',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(color: context.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          trialEnded
              ? 'Upgrade to keep auto-applying — Pro (Monthly) gives you 10/day, Elite (Yearly) gives you 30/day.'
              : 'Apply to up to 10 jobs/day on Pro (Monthly) or 30/day on Elite (Yearly), automatically — even while you sleep.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium
              .copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Upgrade plan',
          icon: Icons.upgrade,
          onPressed: () => Navigator.pushNamed(context, '/subscription'),
        ),
      ],
    );
  }

  /// Shown above the settings while the user is inside the 7-day free
  /// trial. Tells them how long is left and what happens after — without
  /// it the trial is invisible and feels like a normal paid account.
  Widget _trialBanner(AutoApplySettings s) {
    final endsAt = s.trial.endsAt;
    final daysLeft = endsAt?.difference(DateTime.now()).inDays;
    final hoursLeft = endsAt?.difference(DateTime.now()).inHours;
    final remaining = (daysLeft != null && daysLeft >= 1)
        ? '$daysLeft day${daysLeft == 1 ? '' : 's'} left'
        : (hoursLeft != null && hoursLeft >= 1)
            ? '$hoursLeft hour${hoursLeft == 1 ? '' : 's'} left'
            : 'Ends today';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free trial · Pro Auto-Apply',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$remaining · 10 auto-applies/day included',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(label,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700, color: context.textPrimary)),
      );

  /// 2x2 polished action grid replacing the old vertical stack of 4
  /// SecondaryButtons. Each tile carries its own colour + icon so the
  /// visual weight matches the importance ("Run now" is the loud one,
  /// "Run history" is the quiet one).
  Widget _quickActionsGrid(AutoApplyProvider prov, AutoApplySettings s) {
    final isPaused = s.isPaused;
    final tiles = <_ActionTileSpec>[
      _ActionTileSpec(
        icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        label: isPaused ? 'Resume' : 'Pause',
        sublabel: isPaused ? 'Restart auto-apply' : 'Take a break',
        color: isPaused ? AppColors.success : AppColors.warning,
        onTap: isBusy('pauseResume')
            ? null
            : () => guard(
                  () async {
                    final ok = isPaused
                        ? await prov.resume()
                        : await _showPauseSheet();
                    if (!mounted) return;
                    if (ok) setState(() {});
                  },
                  key: 'pauseResume',
                ),
      ),
      _ActionTileSpec(
        icon: Icons.flash_on_rounded,
        label: 'Run now',
        sublabel: 'Apply this minute',
        color: AppColors.primary,
        onTap: (prov.loading || isBusy('runNow'))
            ? null
            : () => guard(() async => _runNow(), key: 'runNow'),
      ),
      _ActionTileSpec(
        icon: Icons.history_rounded,
        label: 'Run history',
        sublabel: 'Past activity',
        color: context.textSecondary,
        onTap: () => debounceTap(
          () => Navigator.pushNamed(context, AppRoutes.autoApplyLog),
          key: 'nav-history',
        ),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles.map((t) => _ActionTile(spec: t)).toList(),
    );
  }

  Widget _statusCard(AutoApplySettings s) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Enable Auto-Apply',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              Switch.adaptive(
                value: _isEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isEnabled = v),
              ),
            ],
          ),
          if (s.isPaused)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline,
                        color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.pauseUntil != null
                            ? 'Paused until ${s.pauseUntil!.toLocal().toIso8601String().split("T").first}'
                            : 'Paused',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Plan: ${s.tier} · cap ${s.planCap}/day · applied total ${s.totalAutoApplied}',
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(AutoApplySettings s) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Run time'),
          Wrap(
            spacing: 8,
            children: _runTimes
                .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _runTime == t,
                      onSelected: (_) => setState(() => _runTime = t),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          _label('Days'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allDays
                .map((d) => FilterChip(
                      label: Text(d.$1),
                      selected: _runDays.contains(d.$2),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _runDays.add(d.$2);
                        } else {
                          _runDays.remove(d.$2);
                        }
                      }),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          _label('Daily limit (max ${s.planCap})'),
          Slider(
            value: _dailyLimit
                .clamp(1, s.planCap == 0 ? 1 : s.planCap)
                .toDouble(),
            min: 1,
            max: (s.planCap == 0 ? 1 : s.planCap).toDouble(),
            divisions: (s.planCap - 1).clamp(1, 49),
            label: _dailyLimit.toString(),
            onChanged: (v) => setState(() => _dailyLimit = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _preferencesCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipInput(
            label: 'Target roles',
            controller: _roleInput,
            chips: _prefs.targetRoles,
            onAdd: (v) =>
                setState(() => _prefs = _prefs.copyWith(targetRoles: [..._prefs.targetRoles, v])),
            onRemove: (v) => setState(() => _prefs = _prefs.copyWith(
                targetRoles: _prefs.targetRoles.where((s) => s != v).toList())),
          ),
          _chipInput(
            label: 'Cities',
            controller: _locationInput,
            chips: _prefs.locations,
            onAdd: (v) => setState(() =>
                _prefs = _prefs.copyWith(locations: [..._prefs.locations, v])),
            onRemove: (v) => setState(() => _prefs = _prefs.copyWith(
                locations: _prefs.locations.where((s) => s != v).toList())),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open to remote'),
            value: _prefs.isOpenToRemote,
            activeThumbColor: AppColors.primary,
            onChanged: (v) =>
                setState(() => _prefs = _prefs.copyWith(isOpenToRemote: v)),
          ),
          _label('Job types'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              'full-time',
              'part-time',
              'contract',
              'internship',
              'temporary',
            ].map((t) {
              final on = _prefs.jobTypes.contains(t);
              return FilterChip(
                label: Text(t),
                selected: on,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (sel) => setState(() {
                  final next = [..._prefs.jobTypes];
                  sel ? next.add(t) : next.remove(t);
                  _prefs = _prefs.copyWith(jobTypes: next);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _label('Minimum salary (₹/yr) — leave blank to skip'),
          TextField(
            controller:
                TextEditingController(text: _prefs.minSalary?.toString() ?? '')
                  ..selection = TextSelection.collapsed(
                      offset: (_prefs.minSalary?.toString().length ?? 0)),
            keyboardType: TextInputType.number,
            decoration: _decoration('e.g., 600000'),
            onChanged: (v) {
              final n = int.tryParse(v);
              _prefs = _prefs.copyWith(minSalary: n);
            },
          ),
          const SizedBox(height: 12),
          // Sources picker removed — auto-apply is now native easy-apply
          // only. External / aggregator listings need a custom form or a
          // third-party site, neither of which the runner can submit to
          // unattended, so we don't even surface them as an option.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Auto-applies only to one-tap (Easy Apply) jobs.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchingCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Minimum match: ${_rules.minMatchPercentage}%'),
          Slider(
            value: _rules.minMatchPercentage.toDouble(),
            min: 50,
            max: 95,
            divisions: 9,
            label: '${_rules.minMatchPercentage}%',
            onChanged: (v) => setState(() =>
                _rules = _rules.copyWith(minMatchPercentage: v.round())),
          ),
          _label('Min matched skills: ${_rules.minSkillsMatchCount}'),
          Slider(
            value: _rules.minSkillsMatchCount.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: _rules.minSkillsMatchCount.toString(),
            onChanged: (v) => setState(() =>
                _rules = _rules.copyWith(minSkillsMatchCount: v.round())),
          ),
          _chipInput(
            label: 'Must include keywords',
            controller: _includeKwInput,
            chips: _rules.mustIncludeKeywords,
            onAdd: (v) => setState(() => _rules = _rules.copyWith(
                mustIncludeKeywords: [..._rules.mustIncludeKeywords, v])),
            onRemove: (v) => setState(() => _rules = _rules.copyWith(
                mustIncludeKeywords: _rules.mustIncludeKeywords
                    .where((s) => s != v)
                    .toList())),
          ),
          _chipInput(
            label: 'Exclude keywords',
            controller: _excludeKwInput,
            chips: _rules.excludeKeywords,
            onAdd: (v) => setState(() => _rules = _rules.copyWith(
                excludeKeywords: [..._rules.excludeKeywords, v])),
            onRemove: (v) => setState(() => _rules = _rules.copyWith(
                excludeKeywords:
                    _rules.excludeKeywords.where((s) => s != v).toList())),
          ),
          _chipInput(
            label: 'Blacklist companies',
            controller: _blacklistInput,
            chips: _rules.blacklistedCompanies,
            onAdd: (v) => setState(() => _rules = _rules.copyWith(
                blacklistedCompanies: [..._rules.blacklistedCompanies, v])),
            onRemove: (v) => setState(() => _rules = _rules.copyWith(
                blacklistedCompanies: _rules.blacklistedCompanies
                    .where((s) => s != v)
                    .toList())),
          ),
          const SizedBox(height: 8),
          _label('Reapply cooldown'),
          Wrap(
            spacing: 6,
            children: const [30, 60, 90]
                .map((d) => ChoiceChip(
                      label: Text('$d days'),
                      selected: _rules.reapplyCooldownDays == d,
                      onSelected: (_) => setState(() =>
                          _rules = _rules.copyWith(reapplyCooldownDays: d)),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.2),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Pause sheet ────────────────────────────────────────────────────
  Future<bool> _showPauseSheet() async {
    final prov = context.read<AutoApplyProvider>();
    final pick = await showModalBottomSheet<int?>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pause Auto-Apply for…',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              title: const Text('1 day'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              title: const Text('3 days'),
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              title: const Text('1 week'),
              onTap: () => Navigator.pop(context, 7),
            ),
            ListTile(
              title: const Text('Until I resume'),
              onTap: () => Navigator.pop(context, 0),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (pick == null) return false;
    return prov.pause(days: pick > 0 ? pick : null);
  }

  // ── Reusable bits ──────────────────────────────────────────────────

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(s,
            style: AppTextStyles.bodySmall
                .copyWith(color: context.textSecondary)),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _chipInput({
    required String label,
    required TextEditingController controller,
    required List<String> chips,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: _decoration('Add and tap +'),
                  onSubmitted: (v) {
                    final t = v.trim();
                    if (t.isNotEmpty && !chips.contains(t)) onAdd(t);
                    controller.clear();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isNotEmpty && !chips.contains(t)) {
                    onAdd(t);
                  }
                  controller.clear();
                },
              ),
            ],
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((c) => Chip(
                          label: Text(c),
                          onDeleted: () => onRemove(c),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cardBorder),
        ),
        child: child,
      );
}

/// Spec for a single action tile in the quick-actions grid. Kept as a
/// plain data class so the grid builder reads top-to-bottom without
/// nested closures.
class _ActionTileSpec {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback? onTap;
  const _ActionTileSpec({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });
}

/// Polished tile used in the Auto-Apply quick-actions grid. Each tile is
/// its own card with a tinted accent strip + icon, two lines of text,
/// and a chevron — matches the visual rhythm of the rest of the screen
/// instead of stacking 4 identical secondary buttons.
class _ActionTile extends StatelessWidget {
  final _ActionTileSpec spec;
  const _ActionTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final disabled = spec.onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: spec.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: spec.color.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: spec.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(spec.icon, color: spec.color, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        spec.sublabel,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: context.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/tap_guard_mixin.dart';
import '../../data/models/ai_combined_models.dart';
import '../../data/services/ai_service.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ai_quota_provider.dart';
import '../widgets/app_text.dart';
import 'widgets/ai_quota_banner.dart';

/// AI Career Assistant chat. Wraps the /ai/chat endpoint with optimistic
/// user bubbles, a "model is typing…" indicator, and one-tap retry on
/// quota / network failures.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TapGuardMixin<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Generic fallback starters when we can't build profile-aware ones
  // (guest mode or empty profile). Kept short so the bubbles fit on a
  // phone without wrapping awkwardly.
  static const _genericStarters = [
    'How do I make my resume stand out for product roles?',
    'Negotiation tips for a 25% salary hike?',
    'How do I prepare for a Flutter developer interview?',
    'Suggest 3 skills I should learn for a senior role.',
  ];

  /// Build profile-aware starter prompts so the empty state speaks in
  /// terms of the candidate's actual role + skills, not a generic
  /// product-manager template. Falls back to [_genericStarters] when
  /// the profile is too sparse to personalise.
  List<String> _starters(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return _genericStarters;
    final role = user.preferredRoles.isNotEmpty
        ? user.preferredRoles.first
        : (user.headline.isNotEmpty ? user.headline : user.profession);
    final topSkill = user.skills.isNotEmpty ? user.skills.first : null;
    if (role.trim().isEmpty && topSkill == null) return _genericStarters;
    final out = <String>[
      if (role.trim().isNotEmpty)
        'How do I improve my resume for $role roles?',
      if (topSkill != null)
        'How should I prepare for a $topSkill interview?',
      if (role.trim().isNotEmpty)
        'Salary negotiation tips for a $role offer in India?',
      if (user.skills.length >= 2)
        'Suggest 3 skills to grow my $role career beyond ${user.skills.take(2).join(" and ")}.',
    ];
    if (out.length < 3) {
      // Top up with generic prompts so the empty state never looks bare.
      for (final g in _genericStarters) {
        if (out.length >= 4) break;
        if (!out.contains(g)) out.add(g);
      }
    }
    return out.take(4).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AiAssistantProvider>().ensureLoaded();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Index of the most recent `role: model` turn in [history], or -1 if
  /// there isn't one. Used to gate follow-up chips so only the LATEST
  /// reply offers them — older turns drop their suggestions.
  int _lastModelIndex(List<AiChatTurn> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (!history[i].isUser) return i;
    }
    return -1;
  }

  Future<void> _send([String? overrideText]) async {
    final assistant = context.read<AiAssistantProvider>();
    final quota = context.read<AiQuotaProvider>();
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || assistant.isSending) return;
    _input.clear();
    final newQuota = await assistant.send(text);
    if (!mounted) return;
    quota.update(newQuota);
    _scrollToBottom();
    if (assistant.error != null) {
      AppSnackbar.error(context, 'Assistant failed. Tap retry to try again.');
    }
  }

  Future<void> _retry() async {
    final assistant = context.read<AiAssistantProvider>();
    final quota = context.read<AiQuotaProvider>();
    final newQuota = await assistant.retry();
    if (!mounted) return;
    quota.update(newQuota);
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    final assistant = context.read<AiAssistantProvider>();
    if (!assistant.hasHistory) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
            'This deletes the chat history on the server. You can\'t undo it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await assistant.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AppText.h4('Career assistant'),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: () => debounceTap(_confirmClear, key: 'clear'),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AiQuotaBanner(),
            ),
            Expanded(
              child: Consumer<AiAssistantProvider>(
                builder: (_, assistant, __) {
                  if (!assistant.historyLoaded && assistant.isLoadingHistory) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (assistant.history.isEmpty) {
                    return _EmptyState(
                      starters: _starters(context),
                      onPick: (q) => guard(() => _send(q), key: 'starter'),
                    );
                  }
                  // Only the LAST model turn shows follow-up chips —
                  // older turns drop them so stale suggestions don't
                  // pile up in the scrollback. We compute the index here
                  // so itemBuilder stays cheap.
                  final lastModelIdx = _lastModelIndex(assistant.history);
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount:
                        assistant.history.length + (assistant.isSending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == assistant.history.length &&
                          assistant.isSending) {
                        // Streaming bubble vs typing dots — flip to live
                        // text the moment the first delta arrives so the
                        // user sees the model "writing".
                        if (assistant.isStreaming) {
                          return _StreamingBubble(
                            text: assistant.streamingReply,
                          );
                        }
                        return const _TypingBubble();
                      }
                      final t = assistant.history[i];
                      final isLatestModel =
                          i == lastModelIdx && !assistant.isSending;
                      return _ChatBubble(
                        turn: t,
                        followUps: isLatestModel ? t.followUps : const [],
                        onFollowUpTap: (q) =>
                            guard(() => _send(q), key: 'followup'),
                      );
                    },
                  );
                },
              ),
            ),
            Consumer<AiAssistantProvider>(
              builder: (_, a, __) => a.pendingFailedMessage != null
                  ? _RetryBanner(
                      message: a.quotaError?.message ?? 'Send failed',
                      onRetry: () => guard(_retry, key: 'retry'),
                      onDismiss: a.dismissError,
                    )
                  : const SizedBox.shrink(),
            ),
            _Composer(
              controller: _input,
              isSending: context.watch<AiAssistantProvider>().isSending,
              onSend: () => guard(() => _send(), key: 'send'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> starters;
  final void Function(String) onPick;
  const _EmptyState({required this.starters, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.lgRadius,
          ),
          child: const Icon(Icons.auto_awesome,
              size: 30, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const AppText.h3('Career assistant', textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const AppText.caption(
          'Ask anything about resumes, interviews, salary, or job search.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppText.labelSmall(
          'TRY ASKING',
          color: AppColors.textTertiary,
        ),
        const SizedBox(height: 10),
        for (final s in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: AppRadius.mdRadius,
              onTap: () => onPick(s),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(color: context.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(child: AppText.body(s)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_outward_rounded,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final AiChatTurn turn;

  /// Follow-ups to render under THIS bubble. Threaded by the parent so
  /// older turns can stay quiet (only the latest model reply offers
  /// follow-ups). Empty list = no chip row.
  final List<String> followUps;
  final void Function(String prompt)? onFollowUpTap;

  const _ChatBubble({
    required this.turn,
    this.followUps = const [],
    this.onFollowUpTap,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  // Local optimistic rating: -1 / 0 / 1. Re-tap of the same thumb
  // clears it (back to 0). The backend upserts so the latest state
  // wins; we don't await it before painting.
  int _rating = 0;

  AiChatTurn get turn => widget.turn;

  void _setRating(int next) {
    final value = _rating == next ? 0 : next;
    setState(() => _rating = value);
    // Fire-and-forget — the service swallows errors so a flaky network
    // never strands the user with a half-rated card.
    AiService.instance.sendFeedback(
      feature: 'chat',
      refId: turn.id,
      rating: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    final bg = isUser ? AppColors.primary : context.surface;
    final fg = isUser ? Colors.white : context.textPrimary;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );
    // Feedback only makes sense on model replies that carry a stable id.
    // Legacy turns (loaded from Redis before id-tracking shipped) read
    // `id == ''` and skip the feedback row entirely.
    final showFeedback = !isUser && turn.id.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                border: isUser
                    ? null
                    : Border.all(color: context.cardBorder),
              ),
              child: SelectableText(
                turn.content,
                style: TextStyle(color: fg, height: 1.4, fontSize: 14.5),
              ),
            ),
          ),
          if (showFeedback)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThumbButton(
                    icon: Icons.thumb_up_outlined,
                    activeIcon: Icons.thumb_up,
                    active: _rating == 1,
                    onTap: () => _setRating(1),
                  ),
                  const SizedBox(width: 4),
                  _ThumbButton(
                    icon: Icons.thumb_down_outlined,
                    activeIcon: Icons.thumb_down,
                    active: _rating == -1,
                    onTap: () => _setRating(-1),
                  ),
                ],
              ),
            ),
          if (!isUser && widget.followUps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in widget.followUps)
                  _FollowUpChip(
                    label: q,
                    onTap: widget.onFollowUpTap == null
                        ? null
                        : () => widget.onFollowUpTap!(q),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;
  const _ThumbButton({
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.primary : context.textTertiary;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          active ? activeIcon : icon,
          size: 14,
          color: color,
        ),
      ),
    );
  }
}

/// Compact "tap to ask" chip rendered under the latest model reply.
/// Stays visually quiet — primary affordance is still the composer at
/// the bottom; chips are a one-tap shortcut for the most likely next
/// question.
class _FollowUpChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _FollowUpChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.pillRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_outward_rounded,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: context.cardBorder),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _Dot(progress: ((_ctrl.value + i / 3) % 1.0)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double progress;
  const _Dot({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Simple sinusoidal opacity bob: 0.3 → 1 → 0.3 across the cycle.
    final t = (progress * 2 - 1).abs(); // 0..1..0
    final opacity = 0.3 + (1 - t) * 0.7;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RetryBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  const _RetryBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: AppText.caption(message),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              iconSize: 18,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(top: BorderSide(color: context.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask anything…',
                filled: true,
                fillColor: context.surfaceVariant,
                counterText: '',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isSending
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isSending ? null : onSend,
              child: SizedBox(
                width: 44,
                height: 44,
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live-streaming model bubble. Renders the in-flight reply as text
/// arrives chunk-by-chunk, with a small blinking cursor at the end so
/// the user sees the model is still writing. Replaced by the final
/// [_ChatBubble] once the stream's `done` event lands and the turn is
/// appended to provider history.
class _StreamingBubble extends StatelessWidget {
  final String text;
  const _StreamingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: context.cardBorder),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: context.textPrimary,
                      height: 1.4,
                      fontSize: 14.5,
                    ),
                  ),
                  const _BlinkingCursor(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.3 + 0.7 * _ctrl.value,
        child: Container(
          width: 7,
          height: 14,
          margin: const EdgeInsets.only(left: 2),
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

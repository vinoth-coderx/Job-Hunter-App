import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/app_avatar.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

enum _ConvFilter { all, unread, self }

class _ConversationsScreenState extends State<ConversationsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  _ConvFilter _filter = _ConvFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>()
        ..start()
        ..loadConversations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Apply the active filter chip + search query to the provider's
  /// conversation list. Done client-side because the list is small (typical
  /// usage: tens of threads, not hundreds) and the chat REST endpoint
  /// doesn't yet expose server-side filtering.
  List<Conversation> _applyFilters(List<Conversation> all, String me) {
    Iterable<Conversation> out = all;
    if (_filter == _ConvFilter.unread) {
      out = out.where((c) => c.unreadCount > 0);
    } else if (_filter == _ConvFilter.self) {
      out = out.where((c) => c.isSelfChat(me));
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((c) {
        if (c.isSelfChat(me)) return 'notes to self'.contains(q);
        final other = c.otherThan(me);
        final name = (other?.fullName ?? '').toLowerCase();
        final email = (other?.email ?? '').toLowerCase();
        final last = (c.lastMessage?.content ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || last.contains(q);
      });
    }
    return out.toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user?.id ?? '';
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        // Messages is no longer a bottom-nav tab — it's pushed from the
        // home header — so let Flutter auto-render the back button when
        // there's a route to pop. (No explicit `automaticallyImplyLeading`
        // override needed; the default true handles both cases cleanly.)
        title: Consumer<ChatProvider>(
          builder: (_, prov, __) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  prov.conversations.isEmpty
                      ? 'Talk to hirers and applicants'
                      : '${prov.conversations.length} conversation${prov.conversations.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<ChatProvider>(
        builder: (_, prov, __) {
          if (prov.loadingConversations && prov.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.conversations.isEmpty) {
            return _empty();
          }
          final unreadCount =
              prov.conversations.where((c) => c.unreadCount > 0).length;
          final selfCount =
              prov.conversations.where((c) => c.isSelfChat(me)).length;
          final visible = _applyFilters(prov.conversations, me);

          return Column(
            children: [
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              _FilterChips(
                active: _filter,
                allCount: prov.conversations.length,
                unreadCount: unreadCount,
                selfCount: selfCount,
                onSelect: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _noResults()
                    : RefreshIndicator(
                        onRefresh: () => prov.loadConversations(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: context.divider),
                          itemBuilder: (_, i) =>
                              _ConversationTile(conv: visible[i], me: me),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _noResults() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 56, color: context.textTertiary),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'No conversations match "$_query"'
                    : 'No conversations match this filter',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No messages yet',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Open a job and tap the message icon to chat with the recruiter. Hirers will also message you when they shortlist your application.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name, email or message',
          hintStyle: AppTextStyles.bodySmall
              .copyWith(color: context.textTertiary),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: context.textTertiary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: context.textSecondary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: context.surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _ConvFilter active;
  final int allCount;
  final int unreadCount;
  final int selfCount;
  final ValueChanged<_ConvFilter> onSelect;

  const _FilterChips({
    required this.active,
    required this.allCount,
    required this.unreadCount,
    required this.selfCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_FilterChipSpec>[
      _FilterChipSpec(_ConvFilter.all, 'All', allCount),
      _FilterChipSpec(_ConvFilter.unread, 'Unread', unreadCount),
      if (selfCount > 0)
        _FilterChipSpec(_ConvFilter.self, 'Notes to self', selfCount),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          final selected = active == c.value;
          return ChoiceChip(
            label: Text(
              c.count > 0 ? '${c.label} · ${c.count}' : c.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : context.textPrimary,
              ),
            ),
            selected: selected,
            onSelected: (_) => onSelect(c.value),
            selectedColor: AppColors.primary,
            backgroundColor: context.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : context.cardBorder,
            ),
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

class _FilterChipSpec {
  final _ConvFilter value;
  final String label;
  final int count;
  const _FilterChipSpec(this.value, this.label, this.count);
}

class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  final String me;
  const _ConversationTile({required this.conv, required this.me});

  @override
  Widget build(BuildContext context) {
    final other = conv.otherThan(me);
    final last = conv.lastMessage;
    final unread = conv.unreadCount;
    final isSelf = conv.isSelfChat(me);
    // Branding rule: only seekers see the company logo/name in the row
    // (the recruiter is just the company's voice). Hirers viewing the
    // same conversation list see the seeker's name + avatar — otherwise
    // every row would show their own company name and they'd have no
    // way to tell threads apart.
    final isHirerView = context.watch<AuthProvider>().isHirerMode;
    final hasCompanyBranding = !isSelf &&
        !isHirerView &&
        ((conv.companyLogo?.isNotEmpty ?? false) ||
            (conv.companyName?.isNotEmpty ?? false));
    final title = isSelf
        ? 'Notes to self'
        : hasCompanyBranding
            ? conv.companyName!
            : (other?.fullName.isNotEmpty == true
                ? other!.fullName
                : (other?.email ?? 'Unknown'));

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conv.id),
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            isSelf
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.primary,
                    ),
                  )
                : AppAvatar(
                    url: hasCompanyBranding
                        ? conv.companyLogo
                        : other?.avatar,
                    name: hasCompanyBranding
                        ? (conv.companyName ?? other?.fullName)
                        : other?.fullName,
                    size: 48,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (last != null)
                        Text(
                          DateFormat('h:mm a').format(last.sentAt.toLocal()),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: context.textTertiary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last?.content ?? 'Say hi 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: unread > 0
                                ? context.textPrimary
                                : context.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

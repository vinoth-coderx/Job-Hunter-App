import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/team_service.dart';
import '../widgets/app_text.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _service = TeamService.instance;
  TeamSnapshot? _snap;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.snapshot();
      if (!mounted) return;
      setState(() {
        _snap = s;
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

  Future<void> _invite() async {
    final created = await showModalBottomSheet<TeamInvitePayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InviteSheet(),
    );
    if (created == null || !mounted) return;
    await _refresh();
    if (!mounted) return;
    // Show the share-able invite link/token immediately so admins can
    // copy it to clipboard or DM it.
    await showDialog<void>(
      context: context,
      builder: (_) => _InviteCreatedDialog(invite: created),
    );
  }

  Future<void> _changeRole(TeamMember m) async {
    if (m.userId == null) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _RolePicker(currentRole: m.role),
    );
    if (picked == null || picked == m.role || !mounted) return;
    try {
      await _service.changeRole(userId: m.userId!, role: picked);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not change role: $e')));
    }
  }

  Future<void> _remove(TeamMember m) async {
    if (m.userId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${m.fullName ?? m.email ?? "member"}?'),
        content: const Text('They\'ll lose access immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.remove(m.userId!);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Team'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: _content(_snap!),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite'),
      ),
    );
  }

  Widget _content(TeamSnapshot snap) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _section('Members (${snap.members.length})'),
        const SizedBox(height: 8),
        if (snap.members.isEmpty)
          _emptyHint('No team members yet — invite someone to get started.'),
        ...snap.members.map((m) => _memberRow(m, snap.ownerUserId)),
        if (snap.pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section('Pending invites (${snap.pendingInvites.length})'),
          const SizedBox(height: 8),
          ...snap.pendingInvites.map(_pendingRow),
        ],
      ],
    );
  }

  Widget _section(String s) => AppText.body(s, fontWeight: FontWeight.w700);

  Widget _emptyHint(String s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppText.caption(s),
      );

  Widget _avatarFallback(String initial) => Container(
        color: AppColors.primary.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      );

  Widget _memberRow(TeamMember m, String ownerId) {
    final isOwner = m.userId != null && m.userId == ownerId;
    final hasAvatar = m.avatar != null && m.avatar!.trim().isNotEmpty;
    final initial = ((m.fullName ?? m.email ?? '?').isEmpty
            ? '?'
            : (m.fullName ?? m.email)!.substring(0, 1))
        .toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: hasAvatar
                  ? Image.network(
                      m.avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(initial),
                      loadingBuilder: (ctx, child, progress) =>
                          progress == null ? child : _avatarFallback(initial),
                    )
                  : _avatarFallback(initial),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.fullName ?? m.email ?? 'Unknown',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                if (m.email != null)
                  Text(m.email!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: context.textSecondary)),
              ],
            ),
          ),
          _roleBadge(isOwner ? 'owner' : m.role),
          if (!isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'role') _changeRole(m);
                if (v == 'remove') _remove(m);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'role', child: Text('Change role')),
                PopupMenuItem(
                    value: 'remove', child: Text('Remove from team')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pendingRow(PendingInvite p) {
    final df = DateFormat('d MMM');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.email,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${p.role} · expires ${p.expiresAt != null ? df.format(p.expiresAt!.toLocal()) : "—"}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warning),
                ),
              ],
            ),
          ),
          _roleBadge(p.role),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = switch (role) {
      'owner' => AppColors.success,
      'admin' => AppColors.primary,
      'recruiter' => AppColors.info,
      'interviewer' => AppColors.warning,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _email = TextEditingController();
  String _role = 'recruiter';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final invite = await TeamService.instance
          .invite(email: _email.text.trim(), role: _role);
      if (!mounted) return;
      Navigator.pop(context, invite);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not invite: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText.h3('Invite team member'),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              hint: 'Email *',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: const [
                ('admin', 'Admin'),
                ('recruiter', 'Recruiter'),
                ('interviewer', 'Interviewer'),
              ].map((r) {
                return ChoiceChip(
                  label: Text(r.$2),
                  selected: _role == r.$1,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _role = r.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Send invite',
              icon: Icons.send,
              isLoading: _busy,
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCreatedDialog extends StatelessWidget {
  final TeamInvitePayload invite;
  const _InviteCreatedDialog({required this.invite});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send this token to ${invite.email}. They\'ll paste it in the app to join as ${invite.role}.',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(invite.token,
                style: AppTextStyles.bodySmall
                    .copyWith(fontFamily: 'monospace')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: invite.token));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
            Navigator.pop(context);
          },
          child: const Text('Copy token'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  final String currentRole;
  const _RolePicker({required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Change role',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final r in const ['admin', 'recruiter', 'interviewer'])
            ListTile(
              leading: Icon(
                r == currentRole ? Icons.radio_button_checked : Icons.radio_button_off,
                color:
                    r == currentRole ? AppColors.primary : Colors.grey,
              ),
              title: Text(r),
              onTap: () => Navigator.pop(context, r),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

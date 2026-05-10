import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/app_avatar.dart';
import 'chat_attachment_viewer.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  Timer? _typingDebounce;
  bool _typingSent = false;
  // Tracks the last-rendered message count so we can detect "a new
  // message just arrived" inside build() and auto-scroll to it (covers
  // socket-pushed inbound messages, not just the user's own send).
  int _lastMsgCount = 0;

  // True from the moment the user picks an attachment until the multipart
  // POST completes (success or failure). Drives the composer's spinner +
  // disabled-button state so the user knows the file is on its way and
  // can't double-tap to send the same image twice.
  bool _uploading = false;

  // Friendly date headings — "Today", "Yesterday", weekday name within
  // the last week, otherwise the full date. Mirrors WhatsApp.
  String _formatDateHeading(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays > 1 && diffDays < 7) {
      return DateFormat('EEEE').format(when.toLocal());
    }
    if (now.year == when.year) {
      return DateFormat('EEE, d MMM').format(when.toLocal());
    }
    return DateFormat('d MMM yyyy').format(when.toLocal());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<ChatProvider>()..start();
      await prov.loadMessages(widget.conversationId);
      await prov.markConversationRead(widget.conversationId);
      if (!mounted) return;
      setState(() => _loading = false);
      // Jump must wait for the post-setState frame — only then is the
      // ListView mounted and the ScrollController attached to a Scrollable
      // (otherwise hasClients is false and jumpTo silently no-ops).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToBottom();
      });
    });
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  // Smooth follow-along when an inbound message lands while the user is
  // already at (or near) the bottom — same UX rule as WhatsApp: don't
  // yank the view if they've scrolled up to read history.
  void _animateToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  bool _isNearBottom() {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return (pos.maxScrollExtent - pos.pixels) < 160;
  }

  Conversation? _conv() {
    final list = context.read<ChatProvider>().conversations;
    for (final c in list) {
      if (c.id == widget.conversationId) return c;
    }
    return null;
  }

  ChatParticipant? _other() {
    final me = context.read<AuthProvider>().user?.id ?? '';
    return _conv()?.otherThan(me);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    final other = _other();
    if (other != null && _typingSent) {
      context.read<ChatProvider>().emitTypingStop(
            conversationId: widget.conversationId,
            otherUserId: other.id,
          );
      _typingSent = false;
    }
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<ChatProvider>().sendMessage(
          conversationId: widget.conversationId,
          content: text,
        );
    if (!mounted) return;
    if (result == null) {
      final err = context.read<ChatProvider>().error;
      messenger.showSnackBar(SnackBar(
        content: Text('Could not send: ${err ?? 'unknown error'}'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  // Server-side cap is 10MB (uploadChatAttachment middleware). Mirror it
  // client-side so the user gets immediate feedback instead of waiting
  // for the multipart upload to fail with a 413.
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;

  Future<void> _pickAndSendAttachment() async {
    if (_uploading) return;
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'webp', 'gif',
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt',
        ],
        withData: true,
        allowMultiple: false,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not open file picker: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    if (f.size > _maxAttachmentBytes) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Attachment is too large — 10 MB max.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!mounted) return;

    setState(() => _uploading = true);
    try {
      final result = await context.read<ChatProvider>().sendMessage(
            conversationId: widget.conversationId,
            content: _input.text.trim(),
            attachmentPath: f.path,
            attachmentBytes: f.path == null ? f.bytes : null,
            attachmentFilename: f.name,
            attachmentContentType: _mimeForExtension(f.extension),
          );
      if (!mounted) return;
      if (result == null) {
        final err = context.read<ChatProvider>().error;
        messenger.showSnackBar(SnackBar(
          content: Text('Could not upload: ${err ?? 'unknown error'}'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      _input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _mimeForExtension(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  void _onInputChanged(String _) {
    // Self-chat has no peer to notify; skip typing events entirely.
    final other = _other();
    if (other == null) return;
    final prov = context.read<ChatProvider>();

    if (!_typingSent) {
      prov.emitTypingStart(
        conversationId: widget.conversationId,
        otherUserId: other.id,
      );
      _typingSent = true;
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_typingSent) {
        prov.emitTypingStop(
          conversationId: widget.conversationId,
          otherUserId: other.id,
        );
        _typingSent = false;
      }
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user?.id ?? '';
    final other = _other();
    final conv = _conv();
    final isSelf = conv?.isSelfChat(me) ?? false;
    final messages = context.watch<ChatProvider>().messagesFor(widget.conversationId);
    final isOtherTyping = !isSelf &&
        other != null &&
        context.watch<ChatProvider>().isPeerTyping(other.id);

    // Auto-scroll on inbound message arrivals (socket fan-out). Only
    // follow if the user is already near the bottom — otherwise we'd
    // hijack the view while they're reading history. Sender-side scrolls
    // are still forced by `_send()` after a successful POST.
    //
    // Gate on `!_loading`: while the spinner is up the ListView isn't
    // mounted yet, so a transition from 0 → N during loading would
    // bump _lastMsgCount without ever scrolling — leaving the user at
    // the top once loading flips off. Waiting until !_loading means the
    // first 0 → N delta runs *after* mount and the initial-load branch
    // below jumps to bottom unconditionally.
    if (!_loading && messages.length > _lastMsgCount) {
      final isInitialLoad = _lastMsgCount == 0;
      final wasNearBottom = _isNearBottom();
      final lastIsMine = messages.isNotEmpty && messages.last.senderId == me;
      _lastMsgCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isInitialLoad) {
          _jumpToBottom();
        } else if (lastIsMine || wasNearBottom) {
          _animateToBottom();
        }
      });
    }

    // Seeker-side conversations are tied to a job, and the backend
    // surfaces the linked company's branding alongside the participants.
    // The header should reflect who the *other side* is:
    //   - Seeker  → company logo + name (the recruiter is talking on the
    //                company's behalf, the seeker doesn't know the
    //                recruiter personally).
    //   - Hirer   → the seeker's own name + avatar (the company branding
    //                is *their own* employer, so showing it would label
    //                every chat row "VK · VK"). The previous code used
    //                companyName for both roles, which is why the hirer
    //                saw their own initials in every thread.
    //   - Self    → "Notes to self".
    final isHirerView = context.watch<AuthProvider>().isHirerMode;
    final companyLogo = conv?.companyLogo;
    final companyName = conv?.companyName;
    final hasCompanyBranding = !isSelf &&
        !isHirerView &&
        (companyLogo?.isNotEmpty == true || companyName?.isNotEmpty == true);
    final headerTitle = isSelf
        ? 'Notes to self'
        : hasCompanyBranding
            ? (companyName ?? '')
            : (other?.fullName.isNotEmpty == true
                ? other!.fullName
                : (other?.email ?? 'Conversation'));
    final headerSubtitle = hasCompanyBranding
        ? (conv?.jobTitle?.isNotEmpty == true
            ? conv!.jobTitle!
            : (other?.fullName.isNotEmpty == true ? other!.fullName : ''))
        : (isHirerView && conv?.jobTitle?.isNotEmpty == true
            ? conv!.jobTitle!
            : '');

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            isSelf
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  )
                : AppAvatar(
                    url: hasCompanyBranding ? companyLogo : other?.avatar,
                    name: hasCompanyBranding
                        ? (companyName ?? other?.fullName)
                        : other?.fullName,
                    size: 32,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerTitle,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isOtherTyping)
                    Text('typing…',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic))
                  else if (headerSubtitle.isNotEmpty)
                    Text(
                      headerSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty && !isOtherTyping
                    ? _emptyThread()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: messages.length + (isOtherTyping ? 1 : 0),
                        itemBuilder: (_, i) {
                          // Append a typing-bubble row at the very end while
                          // the peer is composing — mirrors the iMessage feel
                          // of "they're writing right now" without stealing
                          // AppBar real estate.
                          if (isOtherTyping && i == messages.length) {
                            return const _TypingBubble();
                          }
                          final m = messages[i];
                          final mine = m.senderId == me;
                          final showDate = i == 0 ||
                              !_sameDay(messages[i - 1].sentAt, m.sentAt);
                          // Group bubbles when they're from the same sender
                          // AND within 2 minutes of each other — collapses
                          // the timestamp row + tightens spacing so a burst
                          // of replies reads as a single thought.
                          final prev = i > 0 ? messages[i - 1] : null;
                          final next = i + 1 < messages.length
                              ? messages[i + 1]
                              : null;
                          final isFirstInGroup = prev == null ||
                              prev.senderId != m.senderId ||
                              showDate ||
                              m.sentAt.difference(prev.sentAt).inMinutes.abs() >
                                  2;
                          final isLastInGroup = next == null ||
                              next.senderId != m.senderId ||
                              !_sameDay(m.sentAt, next.sentAt) ||
                              next.sentAt
                                      .difference(m.sentAt)
                                      .inMinutes
                                      .abs() >
                                  2;
                          return Column(
                            children: [
                              if (showDate)
                                _DateSeparator(label: _formatDateHeading(m.sentAt)),
                              _Bubble(
                                message: m,
                                mine: mine,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Starter suggestions only show on a brand-new thread so they
          // don't keep nagging once the conversation is going. Tapping a
          // chip pre-fills the composer (instead of sending immediately)
          // so the user can edit before hitting send.
          if (messages.isEmpty && !_loading)
            _StarterSuggestions(
              isSelf: isSelf,
              onPick: (text) {
                _input.text = text;
                _input.selection = TextSelection.fromPosition(
                  TextPosition(offset: text.length),
                );
              },
            ),
          _Composer(
            controller: _input,
            onChanged: _onInputChanged,
            onSend: _send,
            onAttach: _pickAndSendAttachment,
            uploading: _uploading,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _emptyThread() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                  Icons.waving_hand_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Start the conversation',
                style: AppTextStyles.h4
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a starter below or just say hi 👋',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: context.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  const _Bubble({
    required this.message,
    required this.mine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    // Bubble corners: keep the "tail" only on the very last bubble of a
    // run from the same sender. Continuations get a small radius on the
    // joining side so visually they read as one block.
    const big = Radius.circular(18);
    const small = Radius.circular(6);
    final radius = mine
        ? BorderRadius.only(
            topLeft: big,
            topRight: isFirstInGroup ? big : small,
            bottomLeft: big,
            bottomRight: isLastInGroup ? small : small,
          )
        : BorderRadius.only(
            topLeft: isFirstInGroup ? big : small,
            topRight: big,
            bottomLeft: isLastInGroup ? small : small,
            bottomRight: big,
          );

    final readBlue = const Color(0xFF53BDEB); // WhatsApp-ish read tint
    final tickColor = mine
        ? (message.isRead ? readBlue : Colors.white.withValues(alpha: 0.8))
        : null;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 4 : 2,
      ),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : context.surface,
                borderRadius: radius,
                border: mine ? null : Border.all(color: context.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.file != null) ...[
                    _AttachmentPreview(file: message.file!, mine: mine),
                    if (message.content.isNotEmpty &&
                        message.content != message.file!.filename)
                      const SizedBox(height: 6),
                  ],
                  if (message.content.isNotEmpty &&
                      (message.file == null ||
                          message.content != message.file!.filename))
                    Text(
                      message.content,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: mine ? Colors.white : context.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  // Timestamp + tick only on the last bubble in a run, so
                  // a 5-message burst doesn't repeat the same time five
                  // times — feels much closer to a real chat thread.
                  if (isLastInGroup) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.sentAt.toLocal()),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 10,
                            color: mine
                                ? Colors.white.withValues(alpha: 0.8)
                                : context.textTertiary,
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 13,
                            color: tickColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-dot animated indicator shown at the end of the messages list
/// while the peer is typing. Mimics the "…" bubble in iMessage / WhatsApp
/// — a far more "real conversation" cue than a static AppBar label.
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
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: context.cardBorder),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_ctrl.value + i / 3) % 1.0;
                    // Each dot rises and dips on a phase-shifted curve so
                    // the row reads as a wave, not a flicker.
                    final scale = 0.6 + 0.6 * (0.5 + 0.5 * (t < 0.5 ? t : 1 - t));
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: i == 1 ? 4 : 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.55 + 0.45 * scale),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final ChatFileAttachment file;
  final bool mine;
  const _AttachmentPreview({required this.file, required this.mine});

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconForType(String type) {
    if (type == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (type.contains('word')) return Icons.description_rounded;
    if (type.contains('sheet') || type.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (type == 'text/plain') return Icons.notes_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (file.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => openChatAttachment(context, file),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 240,
              maxHeight: 280,
            ),
            child: Hero(
              tag: chatAttachmentHeroTag(file),
              child: Image.network(
                file.url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null
                        ? child
                        : const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 120,
                  color: context.surfaceVariant,
                  child: Icon(Icons.broken_image_rounded,
                      color: context.textTertiary, size: 32),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final fg = mine ? Colors.white : context.textPrimary;
    final fgMuted =
        mine ? Colors.white.withValues(alpha: 0.85) : context.textSecondary;
    return InkWell(
      onTap: () => openChatAttachment(context, file),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: mine
              ? Colors.white.withValues(alpha: 0.16)
              : context.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForType(file.type), size: 28, color: fg),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _humanSize(file.sizeBytes),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: fgMuted,
                      fontSize: 11,
                    ),
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

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cardBorder),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer is wrapped in an animated send button that fades in only
/// when there's text to send — same as iMessage / WhatsApp. Avoids the
/// dead "send" button on an empty input that confuses users about state.
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool uploading;
  const _Composer({
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          border: Border(top: BorderSide(color: context.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            // Attach button — opens the system file picker. Sized to match
            // the send button so the composer reads as a balanced row.
            // Disabled while an upload is in flight to prevent picking a
            // second file before the first finishes.
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : onAttach,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.attach_file_rounded,
                    color: uploading
                        ? context.textTertiary
                        : context.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: context.textTertiary,
                  ),
                  filled: true,
                  fillColor: context.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button enabled-state mirrors the input — when there's
            // no text, the button dims and disables. Listening directly
            // to the controller avoids requiring the parent to rebuild
            // on every keystroke. While an attachment upload is in
            // flight the icon is replaced with a spinner so the user
            // sees the message is actively being sent.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final hasText = value.text.trim().isNotEmpty;
                final active = uploading || hasText;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.40),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: (uploading || !hasText) ? null : onSend,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: uploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally-scrolling row of one-tap starter messages shown above
/// the composer when a thread has no messages yet. Tapping a chip
/// pre-fills the input so the user can edit before sending — keeps
/// human voice in the loop instead of firing canned text directly.
///
/// Self-chat ("Notes to self") gets a different starter set since the
/// user is talking to themselves, not a recruiter.
class _StarterSuggestions extends StatelessWidget {
  final bool isSelf;
  final ValueChanged<String> onPick;
  const _StarterSuggestions({required this.isSelf, required this.onPick});

  static const _peerStarters = [
    'Hi 👋',
    'Hello, I saw your job posting',
    'Is this role still open?',
    'Could you share more details?',
    'Thanks for connecting!',
  ];

  static const _selfStarters = [
    'Reminder:',
    'Follow up on:',
    'Idea:',
    'TODO:',
  ];

  @override
  Widget build(BuildContext context) {
    final items = isSelf ? _selfStarters : _peerStarters;
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final text = items[i];
            return InkWell(
              onTap: () => onPick(text),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.20)),
                ),
                child: Text(
                  text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

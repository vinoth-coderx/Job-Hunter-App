class ChatParticipant {
  final String id;
  final String email;
  final String fullName;
  final String? avatar;

  const ChatParticipant({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatar,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> j) {
    final profile = (j['profile'] as Map<String, dynamic>?) ?? const {};
    return ChatParticipant(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      fullName: (profile['fullName'] ?? j['fullName'] ?? '').toString(),
      avatar: profile['avatar'] as String?,
    );
  }
}

class ChatLastMessage {
  final String content;
  final DateTime sentAt;
  final String senderId;
  const ChatLastMessage({
    required this.content,
    required this.sentAt,
    required this.senderId,
  });
  factory ChatLastMessage.fromJson(Map<String, dynamic> j) => ChatLastMessage(
        content: (j['content'] ?? '').toString(),
        sentAt: DateTime.tryParse(j['sentAt']?.toString() ?? '') ??
            DateTime.now(),
        senderId: (j['sender'] ?? j['senderId'] ?? '').toString(),
      );
}

class Conversation {
  final String id;
  final List<ChatParticipant> participants;
  final String? applicationId;
  final String? jobId;
  final ChatLastMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  /// Branding lifted from the linked Job, supplied by the backend when
  /// the conversation has a `job` reference. Seeker-side UI prefers the
  /// company logo over the recruiter's personal avatar so the chat
  /// header shows who they're really talking to (the company).
  final String? companyName;
  final String? companyLogo;
  final String? jobTitle;
  /// True when the company linked to this conversation is verified.
  /// Surfaces a green check next to the company name in the chat header
  /// so the seeker can tell a Verified recruiter from a fresh signup.
  final bool companyVerified;

  /// Side of the thread the current user sits on — `'seeker'` when this
  /// is an outbound application chat, `'hirer'` when the user is the
  /// recruiter for the linked job. Drives the seeker-vs-hirer chat
  /// filter so an account that toggles roles doesn't see the other
  /// role's threads bleed into the inbox.
  final String viewerRole;

  const Conversation({
    required this.id,
    required this.participants,
    this.applicationId,
    this.jobId,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.companyName,
    this.companyLogo,
    this.jobTitle,
    this.companyVerified = false,
    this.viewerRole = 'seeker',
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final partsRaw = j['participants'] as List? ?? const [];
    final parts = partsRaw
        .map((p) => p is Map<String, dynamic>
            ? ChatParticipant.fromJson(p)
            : ChatParticipant(
                id: p.toString(), email: '', fullName: '', avatar: null))
        .toList();
    final rawCompanyLogo = j['companyLogo'] as String?;
    final rawCompanyName = j['companyName'] as String?;
    final rawJobTitle = j['jobTitle'] as String?;
    final rawViewerRole = (j['viewerRole'] ?? '').toString();
    return Conversation(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      participants: parts,
      applicationId: j['application']?.toString(),
      jobId: j['job']?.toString(),
      lastMessage: j['lastMessage'] is Map<String, dynamic>
          ? ChatLastMessage.fromJson(j['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      companyName: rawCompanyName?.trim().isEmpty == true ? null : rawCompanyName,
      companyLogo: rawCompanyLogo?.trim().isEmpty == true ? null : rawCompanyLogo,
      jobTitle: rawJobTitle?.trim().isEmpty == true ? null : rawJobTitle,
      companyVerified: j['companyVerified'] as bool? ?? false,
      viewerRole: rawViewerRole == 'hirer' ? 'hirer' : 'seeker',
    );
  }

  /// Returns the participant who is NOT the current user.
  /// Used to render "Chat with Alice" headers and avatars.
  /// For self-conversations (notes-to-self) this returns null — UI should
  /// fall back to a "Notes to self" label via [isSelfChat].
  ChatParticipant? otherThan(String myUserId) {
    for (final p in participants) {
      if (p.id != myUserId) return p;
    }
    return null;
  }

  /// True when this is a single-participant conversation (the user is
  /// chatting with themselves). Useful for notes-to-self / single-account
  /// testing flows.
  bool isSelfChat(String myUserId) =>
      participants.length == 1 && participants.first.id == myUserId;
}

class ChatFileAttachment {
  final String url;
  final String filename;
  final int sizeBytes;
  final String type;
  const ChatFileAttachment({
    required this.url,
    required this.filename,
    required this.sizeBytes,
    required this.type,
  });

  bool get isImage => type.startsWith('image/');

  factory ChatFileAttachment.fromJson(Map<String, dynamic> j) =>
      ChatFileAttachment(
        url: (j['url'] ?? '').toString(),
        filename: (j['filename'] ?? '').toString(),
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? '').toString(),
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type;
  final String content;
  final ChatFileAttachment? file;
  final bool isRead;
  final DateTime? readAt;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.content,
    this.file,
    this.isRead = false,
    this.readAt,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawFile = j['file'];
    return ChatMessage(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      conversationId: (j['conversation'] ?? '').toString(),
      senderId: (j['sender'] ?? '').toString(),
      receiverId: (j['receiver'] ?? '').toString(),
      type: (j['type'] ?? 'text').toString(),
      content: (j['content'] ?? '').toString(),
      file: rawFile is Map<String, dynamic> && (rawFile['url'] ?? '').toString().isNotEmpty
          ? ChatFileAttachment.fromJson(rawFile)
          : null,
      isRead: j['isRead'] as bool? ?? false,
      readAt: j['readAt'] == null
          ? null
          : DateTime.tryParse(j['readAt'].toString()),
      sentAt: DateTime.tryParse(j['sentAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
